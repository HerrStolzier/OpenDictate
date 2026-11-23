import AVFoundation
// `Activity` is not Sendable in the SDK; it is used only from the main actor.
@preconcurrency import ActivityKit
import Foundation
import Observation
import OpenDictateCore
import UIKit
import os

/// Dictation from the OpenDictate keyboard: while "Keep microphone warm" runs,
/// the keyboard sends start and stop, the app records from the warm
/// microphone, Parakeet writes the text on this iPhone, and the keyboard
/// inserts it. Nothing goes to a service: this path always uses Parakeet,
/// and translates only with Apple's translation on this iPhone.
/// Like `DictationRunner`, a failed dictation keeps its audio for "Send again",
/// and a written one keeps it until the keyboard confirmed the text.
@MainActor
@Observable
final class KeyboardDictation {
    static let shared = KeyboardDictation()

    enum Phase: Equatable {
        case off
        case ready
        case recording
        case writing
    }

    private(set) var phase: Phase = .off
    private(set) var warmUntil: Date?
    /// Why the session or the last dictation failed, for the app's screen.
    private(set) var problem: String?

    var isBusy: Bool { phase == .recording || phase == .writing }

    @ObservationIgnored private let microphone = WarmMicrophone()
    @ObservationIgnored private let bridge = KeyboardBridge()
    @ObservationIgnored private let store = PendingRecordings()
    @ObservationIgnored private var snapshot = KeyboardSnapshot.off
    @ObservationIgnored private var heartbeat: Timer?
    @ObservationIgnored private var limitTimer: Timer?
    @ObservationIgnored private var handledCommand: String?
    /// The recording behind the text the keyboard has not confirmed yet.
    @ObservationIgnored private var unconfirmed: (resultID: String, url: URL)?
    @ObservationIgnored private var duration = WarmDuration.standard
    private static let log = Logger(subsystem: "app.opendictate.ios", category: "keyboard")

    private init() {
        KeyboardBridge.observe(KeyboardBridge.commandNotification) { KeyboardDictation.shared.readCommand() }
        KeyboardBridge.observe(KeyboardBridge.insertedNotification) { KeyboardDictation.shared.readInserted() }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard type == AVAudioSession.InterruptionType.began.rawValue else { return }
            MainActor.assumeIsolated { KeyboardDictation.shared.interrupted() }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { KeyboardDictation.shared.interrupted() }
        }
        // A session of an earlier process cannot be running any more.
        bridge.publish(.off)
    }

    /// Opens the microphone for the chosen time, from the app or from the
    /// shortcut "Keep microphone warm" in the background. A Live Activity
    /// shows it; iOS ends a background recording without one.
    func startSession() async throws {
        problem = nil
        if phase == .ready, !microphone.isRunning {
            // The engine stopped without notice (a route change): start over.
            endSession()
        }
        guard phase == .off else {
            extendSession()
            return
        }
        // The app's own dictation holds the microphone and the phase.
        guard !DictationRunner.shared.isBusy else { return }
        duration = bridge.warmDuration
        do {
            if AVAudioApplication.shared.recordPermission == .undetermined {
                _ = await Recorder.requestPermission()
            }
            guard ParakeetTranscriber.isInstalled else { throw DictationFailure.localModelMissing }
            guard phase == .off, !DictationRunner.shared.isBusy else { return }
            // In front the app can record without one; only the background needs it.
            if UIApplication.shared.applicationState == .active {
                try? startActivity()
            } else {
                try startActivity()
            }
            do {
                try microphone.start()
            } catch {
                await endActivity()
                throw error
            }
        } catch {
            problem = DictationFailure(error).message
            throw DictationFailure(error)
        }
        ParakeetTranscriber.prepare()
        // Nothing of an earlier session, a text included, carries over.
        snapshot = .off
        phase = .ready
        extendSession()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { KeyboardDictation.shared.tick() }
        }
        Self.log.info("warm session started for \(Int(self.duration.seconds)) s")
    }

    /// Ends the session; a running recording is written first.
    func endSession() {
        guard phase != .off else { return }
        if phase == .recording {
            Task { await finish(endingSession: true) }
            return
        }
        // A text being written finishes and is delivered while the app runs.
        microphone.stop()
        heartbeat?.invalidate()
        heartbeat = nil
        limitTimer?.invalidate()
        limitTimer = nil
        warmUntil = nil
        if phase == .ready { phase = .off }
        snapshot.warmUntil = 0
        publish()
        // Taken now, so a session started right after keeps its own activity.
        if let ending = activity {
            activity = nil
            Task { await ending.end(nil, dismissalPolicy: .immediate) }
        }
        Self.log.info("warm session ended")
    }

    private func extendSession() {
        let until = Date() + duration.seconds
        warmUntil = until
        snapshot.warmUntil = until.timeIntervalSince1970
        publish()
        let state = Self.activityState(until: until)
        Task { await activity?.update(ActivityContent(state: state, staleDate: until)) }
    }

    // MARK: Live Activity

    @ObservationIgnored private var activity: Activity<DictationAttributes>?

    private static func activityState(until: Date) -> DictationAttributes.ContentState {
        .init(phase: .warm, startedAt: Date(), endsAt: until, detail: nil)
    }

    private func startActivity() throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw DictationFailure.liveActivitiesOff }
        // A "Copied" or "Oops" of the last dictation may still show.
        let earlier = Activity<DictationAttributes>.activities
        Task { for activity in earlier { await activity.end(nil, dismissalPolicy: .immediate) } }
        let until = Date() + duration.seconds
        do {
            activity = try Activity.request(
                attributes: DictationAttributes(),
                content: ActivityContent(state: Self.activityState(until: until), staleDate: until))
        } catch {
            throw DictationFailure.liveActivityFailed
        }
    }

    private func endActivity() async {
        guard let activity else { return }
        self.activity = nil
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private func tick() {
        if phase == .ready, !microphone.isRunning || (warmUntil.map { $0 <= Date() } ?? true) {
            endSession()
            return
        }
        publish()
        // The notifications can be missed while iOS suspends the observer.
        readCommand()
        readInserted()
    }

    private func publish() {
        snapshot.state =
            switch phase {
            case .off: .off
            case .ready: .ready
            case .recording: .recording
            case .writing: .writing
            }
        snapshot.heartbeat = phase == .off ? 0 : Date().timeIntervalSince1970
        bridge.publish(snapshot)
    }

    // MARK: Commands

    private func readCommand() {
        guard let command = bridge.command(), command.id != handledCommand else { return }
        handledCommand = command.id
        guard command.isFresh(at: Date().timeIntervalSince1970) else { return }
        switch command.kind {
        case .start: startRecording(job: command.jobID)
        case .stop:
            guard snapshot.jobID == command.jobID else { return }
            Task { await finish(endingSession: false) }
        }
    }

    private func startRecording(job: String) {
        guard phase == .ready, !DictationRunner.shared.isBusy else { return }
        snapshot.jobID = job
        snapshot.message = nil
        snapshot.text = nil
        snapshot.resultID = nil
        do {
            try microphone.beginCapture(into: store.newRecordingURL())
        } catch {
            report(DictationFailure(error))
            return
        }
        phase = .recording
        snapshot.recordingSince = Date().timeIntervalSince1970
        publish()
        limitTimer = Timer.scheduledTimer(withTimeInterval: DictationRunner.limit, repeats: false) { _ in
            Task { @MainActor in await KeyboardDictation.shared.finish(endingSession: false) }
        }
    }

    private func finish(endingSession: Bool) async {
        guard phase == .recording else { return }
        limitTimer?.invalidate()
        limitTimer = nil
        guard let capture = microphone.endCapture() else {
            phase = .ready
            publish()
            return
        }
        phase = .writing
        snapshot.recordingSince = nil
        publish()
        let stoppedAt = Date()
        // The app may go to the background while Parakeet writes.
        var background = UIBackgroundTaskIdentifier.invalid
        background = UIApplication.shared.beginBackgroundTask(withName: "Keyboard dictation") {
            // The recording is kept already; only the text is lost.
            UIApplication.shared.endBackgroundTask(background)
            background = .invalid
        }
        defer { if background != .invalid { UIApplication.shared.endBackgroundTask(background) } }
        // Even a too short recording is the only copy of what was said.
        let tooShort = capture.duration < DictationRunner.minimumDuration
        let kept = store.keep(capture.url, retryable: !tooShort)
        do {
            guard !tooShort else { throw DictationFailure.tooShort }
            let heardSpeech = await Task.detached { SpeechCheck.heardSpeech(at: kept) }.value
            guard heardSpeech else { throw DictationFailure.tooQuiet }
            guard let audio = try? Data(contentsOf: kept) else { throw DictationFailure.recordingUnreadable }
            let text = try await Self.write(audio)
            let resultID = UUID().uuidString
            unconfirmed = (resultID, kept)
            snapshot.resultID = resultID
            snapshot.text = text
            snapshot.resultAt = Date().timeIntervalSince1970
            let elapsed = Int(Date().timeIntervalSince(stoppedAt) * 1000)
            Self.log.info("keyboard text ready \(elapsed) ms after stop, \(Int(capture.duration)) s audio")
        } catch {
            report(DictationFailure(error))
        }
        DictationRunner.shared.refreshRetryable()
        let sessionEnded = warmUntil == nil
        phase = .ready
        if endingSession || sessionEnded || duration.endsAfterOneDictation || !microphone.isRunning {
            endSession()
        } else {
            extendSession()
        }
    }

    /// The same text handling as the app's own dictation, but always on this iPhone.
    private static func write(_ audio: Data) async throws -> String {
        var text = try await ParakeetTranscriber.transcribe(audio)
        guard !text.isEmpty else { throw DictationFailure.nothingRecognized }
        text = SpokenNumbers.written(text)
        let target = AppSettings.string(AppSettings.translationTargetKey)
        if !target.isEmpty, AppSettings.translationEngine == .onDevice {
            text = try await OnDeviceTranslator.translate(text, into: target)
            guard !text.isEmpty else { throw DictationFailure.emptyTranslation }
        }
        return text
    }

    private func report(_ failure: DictationFailure) {
        snapshot.message = failure.message
        snapshot.messageAt = Date().timeIntervalSince1970
        problem = failure.message
        publish()
    }

    /// The keyboard inserted the text: its recording need not be sent again.
    private func readInserted() {
        guard let unconfirmed, bridge.insertedResultID == unconfirmed.resultID else { return }
        store.remove(unconfirmed.url)
        self.unconfirmed = nil
        snapshot.text = nil
        publish()
        DictationRunner.shared.refreshRetryable()
    }

    /// A call or Siri takes the microphone: what was said so far is written,
    /// then the session ends, because the engine stopped.
    private func interrupted() {
        guard phase != .off else { return }
        if phase == .recording {
            Task { await finish(endingSession: true) }
        } else {
            endSession()
        }
    }
}
