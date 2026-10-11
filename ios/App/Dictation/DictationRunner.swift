import AVFoundation
// `Activity` is not Sendable in the SDK; this runner calls it only from the main actor.
@preconcurrency import ActivityKit
import Foundation
import Observation
import OpenDictateCore
import UIKit

/// One dictation at a time, whether it comes from the shortcut, the Live
/// Activity or the app. `phase` is the single source of truth: no second
/// request starts while one is written, and a failed dictation keeps its audio
/// in `PendingRecordings` for "Send again".
@MainActor
@Observable
final class DictationRunner {
    static let shared = DictationRunner()

    /// Same limits as the Mac app.
    static let limit: TimeInterval = 90
    static let minimumDuration: TimeInterval = 1

    enum Phase: Equatable {
        case ready
        case listening(since: Date)
        case writing
        case copied
        case oops(String)
    }

    private(set) var phase: Phase = .ready
    /// The last result, in memory only, so "Copy again" works while the app runs.
    private(set) var lastText: String?
    /// The recording behind `lastText` while that text missed the clipboard.
    @ObservationIgnored private var uncopiedRecording: URL?
    /// Newest kept recording, for "Send again".
    private(set) var retryable: RecordingRetention.Entry?

    var isBusy: Bool {
        switch phase {
        case .listening, .writing: true
        case .ready, .copied, .oops: false
        }
    }

    @ObservationIgnored private let recorder = Recorder()
    @ObservationIgnored private let store = PendingRecordings()
    @ObservationIgnored private let client = ServiceClient()
    @ObservationIgnored private var configuration: DictationConfiguration?
    @ObservationIgnored private var activity: Activity<DictationAttributes>?
    @ObservationIgnored private var startedAt = Date()
    /// The custom server already contacted from the foreground in this process.
    @ObservationIgnored private var reachedServer: ServiceEndpoint?

    private init() {
        store.prepare()
        retryable = store.newest()
        recorder.onUnexpectedStop = { Task { try? await DictationRunner.shared.finish() } }
        // A phone call or Siri takes the microphone: send what was said so far.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in try? await DictationRunner.shared.finish() }
        }
        // Activities of an earlier process can only show a stale state.
        let leftovers = Activity<DictationAttributes>.activities
        Task {
            for leftover in leftovers { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// The shortcut's action: starts a dictation and returns an empty text, or
    /// stops it and returns the text, which is then on the clipboard unless iOS
    /// refused it. While a dictation is written, another press changes nothing.
    func toggle() async throws -> String {
        switch phase {
        case .listening: return try await finish()
        case .writing: return ""
        case .ready, .copied, .oops:
            try start()
            return ""
        }
    }

    func start() throws {
        guard !isBusy else { return }
        do {
            let configuration = try DictationConfiguration.current()
            let startedAt = Date()
            try startActivity(at: startedAt)
            do {
                try recorder.start(into: store.newRecordingURL(), limit: Self.limit)
            } catch {
                endActivityNow()
                throw error
            }
            self.configuration = configuration
            self.startedAt = startedAt
            phase = .listening(since: startedAt)
        } catch {
            phase = .oops(DictationFailure(error).message)
            throw DictationFailure(error)
        }
    }

    /// Stops the recording, sends it, copies the result and returns it. Returns
    /// an empty text when nothing was recording.
    @discardableResult
    func finish() async throws -> String {
        guard case .listening = phase, let configuration else { return "" }
        // Before the microphone stops: releasing the audio session ends the
        // background mode that kept the app running.
        let background = BackgroundActivity(name: "Dictation")
        defer { background.end() }
        guard let recording = recorder.stop() else { return "" }
        self.configuration = nil
        phase = .writing
        // Even a too short recording is the only copy of what was said.
        let kept = store.keep(recording.url)
        guard recording.duration >= Self.minimumDuration else { throw await fail(.tooShort) }
        await updateActivity(.writing)
        guard let audio = try? Data(contentsOf: kept) else { throw await fail(.recordingUnreadable) }
        return try await deliver(audio, keptAt: kept, configuration: configuration)
    }

    /// The Live Activity's stop button: returns once the recording stopped,
    /// so the button does not wait for the upload.
    func stopFromLiveActivity() {
        guard case .listening = phase else { return }
        Task { try? await finish() }
    }

    /// Sends the newest kept recording again with the current settings.
    func retry() async {
        guard !isBusy else { return }
        guard let entry = store.newest() else {
            retryable = nil
            return
        }
        let background = BackgroundActivity(name: "Send again")
        defer { background.end() }
        do {
            let configuration = try DictationConfiguration.current()
            guard let audio = store.authenticatedAudio(at: entry.url) else {
                throw DictationFailure.recordingUnreadable
            }
            phase = .writing
            try await deliver(audio, keptAt: entry.url, configuration: configuration)
        } catch {
            phase = .oops(DictationFailure(error).message)
        }
    }

    /// A server in the local network needs iOS's permission, which can only be
    /// asked while the app is open: once per launch and address.
    func reachServer() async {
        guard let endpoint = AppSettings.endpoint, endpoint != reachedServer else { return }
        reachedServer = endpoint
        await client.reach(endpoint)
    }

    /// Syncs "Send again" with the kept recordings, e.g. after one expired
    /// while the app stayed open.
    func refreshRetryable() {
        guard !isBusy else { return }
        retryable = store.newest()
    }

    /// Only between dictations: a phase change while recording or writing
    /// would orphan the running dictation.
    func copyAgain() {
        guard !isBusy, let lastText else { return }
        do {
            try Self.copy(lastText)
            phase = .copied
            // The text is delivered now; its recording need not be sent again.
            if let uncopiedRecording {
                store.remove(uncopiedRecording)
                self.uncopiedRecording = nil
                retryable = store.newest()
            }
        } catch {
            phase = .oops(DictationFailure(error).message)
        }
    }

    /// Transcribes, translates if a target is set, and copies. A failed or
    /// empty translation keeps the audio instead of copying the original.
    /// The caller holds a `BackgroundActivity`, so the requests finish even
    /// when the app is in the background.
    @discardableResult
    private func deliver(_ audio: Data, keptAt url: URL, configuration: DictationConfiguration) async throws
        -> String
    {
        do {
            var text = try await client.transcribe(audio, configuration: configuration)
            guard !text.isEmpty else { throw DictationFailure.nothingRecognized }
            if let target = configuration.translationTarget {
                text = try await client.translate(text, into: target, configuration: configuration)
                guard !text.isEmpty else { throw DictationFailure.emptyTranslation }
            }
            lastText = text
            uncopiedRecording = nil
            do {
                try Self.copy(text)
            } catch {
                // The recording stays for "Send again" until "Copy again" works;
                // the shortcut still gets the text to copy it itself.
                uncopiedRecording = url
                _ = await fail(.clipboardFailed)
                return text
            }
            store.remove(url)
            retryable = store.newest()
            phase = .copied
            await endActivity(.copied, detail: L10n.copiedDetail, after: 4)
            return text
        } catch {
            throw await fail(DictationFailure(error))
        }
    }

    private func fail(_ failure: DictationFailure) async -> DictationFailure {
        retryable = store.newest()
        phase = .oops(failure.message)
        // A text that missed the clipboard is waiting in the app; no need to send it again.
        let pointsToRetry = retryable != nil && failure != .clipboardFailed
        let detail = pointsToRetry ? failure.message + " " + L10n.keptDetail : failure.message
        await endActivity(.oops, detail: detail, after: 10)
        return failure
    }

    /// The setter reports nothing; an unchanged count means iOS refused the
    /// write. Reading the count, unlike the contents, shows no paste prompt.
    private static func copy(_ text: String) throws {
        let before = UIPasteboard.general.changeCount
        UIPasteboard.general.string = text
        guard UIPasteboard.general.changeCount != before else { throw DictationFailure.clipboardFailed }
    }

    // MARK: Live Activity

    private func state(_ phase: DictationAttributes.ContentState.Phase, detail: String? = nil)
        -> DictationAttributes.ContentState
    {
        .init(phase: phase, startedAt: startedAt, endsAt: startedAt + Self.limit, detail: detail)
    }

    private func startActivity(at date: Date) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw DictationFailure.liveActivitiesOff }
        // A "Copied" or "Oops" of the last dictation may still show.
        activity = nil
        let earlier = Activity<DictationAttributes>.activities
        Task {
            for activity in earlier { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        startedAt = date
        do {
            activity = try Activity.request(
                attributes: DictationAttributes(), content: ActivityContent(state: state(.listening), staleDate: nil))
        } catch {
            throw DictationFailure.liveActivityFailed
        }
    }

    /// "Writing" turns stale after the longest possible request, in case iOS
    /// suspends the app before it could end the activity.
    private func updateActivity(_ phase: DictationAttributes.ContentState.Phase) async {
        await activity?.update(ActivityContent(state: state(phase), staleDate: Date() + 150))
    }

    private func endActivity(
        _ phase: DictationAttributes.ContentState.Phase, detail: String, after seconds: TimeInterval
    ) async {
        guard let activity else { return }
        self.activity = nil
        await activity.end(
            ActivityContent(state: state(phase, detail: detail), staleDate: nil),
            dismissalPolicy: .after(Date() + seconds))
    }

    private func endActivityNow() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}

/// Extra time to finish the requests after the app went to the background.
@MainActor
private final class BackgroundActivity {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
