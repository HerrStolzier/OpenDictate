import Foundation
import OpenDictateCore

/// Coordinates one operation at a time. Hardware, transport and delivery are
/// injected so races and recovery behavior can be tested without a microphone.
@MainActor
final class DictationFlow {
    struct Operations {
        var start: @MainActor () throws -> Void
        var stop: @MainActor () throws -> URL
        var prepare: @MainActor (URL) async throws -> PreparedAudio
        var transcribeFile: @MainActor (URL) async throws -> String
        var transcribeRetry: @MainActor (FailedRecordingStore.RetryPayload) async throws -> String
        var keep: @MainActor (URL) -> Bool
        var removeRetry: @MainActor (FailedRecordingStore.RetryPayload) -> Void
        var clean: @MainActor (URL) -> Void
        var copy: @MainActor (String) -> Bool
        var paste: @MainActor () async -> Bool
    }

    private let operations: Operations
    private(set) var state: DictationState = .idle {
        didSet { onState?(state) }
    }
    private(set) var lastTranscript: String?
    private(set) var task: Task<Void, Never>?
    var onState: ((DictationState) -> Void)?
    var onStatus: ((String) -> Void)?
    private var discardOnCancel = false

    init(operations: Operations) { self.operations = operations }

    @discardableResult
    func start() throws -> Bool {
        guard state.canStart else { return false }
        try operations.start()
        state = .recording
        onStatus?("Aufnahme")
        return true
    }

    @discardableResult
    func stop() -> Bool {
        guard state.canStop else { return false }
        state = .processing
        do {
            let original = try operations.stop()
            discardOnCancel = false
            task = Task { await process(original: original) }
        } catch {
            state = .idle
            onStatus?("Aufnahmefehler: \(error.localizedDescription)")
        }
        return true
    }

    @discardableResult
    func retry(_ payload: FailedRecordingStore.RetryPayload) -> Bool {
        guard state.canRetry else { return false }
        state = .processing
        discardOnCancel = false
        task = Task {
            defer {
                state = .idle
                task = nil
            }
            do {
                onStatus?("Wiederholen …")
                try Task.checkCancellation()
                let text = try await operations.transcribeRetry(payload)
                try Task.checkCancellation()
                let result = await deliver(text)
                if result.canRemoveRecoveryAudio { operations.removeRetry(payload) }
            } catch is CancellationError {
                onStatus?("Abgebrochen – Aufnahme bleibt erhalten")
            } catch {
                onStatus?(
                    Task.isCancelled
                        ? "Abgebrochen – Aufnahme bleibt erhalten"
                        : "Wiederholen fehlgeschlagen: \(error.localizedDescription)")
            }
        }
        return true
    }

    /// Cancellation keeps audio by default. Only an explicit discard action
    /// removes an active recording. A retry never silently deletes its source.
    func cancel(discardRecording: Bool = false) {
        if state == .recording {
            state = .processing
            do {
                let audio = try operations.stop()
                if discardRecording || operations.keep(audio) {
                    operations.clean(audio)
                } else {
                    onStatus?("Aufnahme konnte nicht gesichert werden: \(audio.path)")
                    state = .idle
                    return
                }
                onStatus?(discardRecording ? "Aufnahme verworfen" : "Aufnahme für Wiederholung gesichert")
            } catch { onStatus?(error.localizedDescription) }
            state = .idle
        } else if state.isBusy {
            discardOnCancel = discardRecording
            task?.cancel()
        }
    }

    func copyLastTranscript() -> Bool {
        guard let lastTranscript else { return false }
        let copied = operations.copy(lastTranscript)
        onStatus?(copied ? "Letzter Text kopiert" : "Zwischenablage nicht verfügbar – Text bleibt erhalten")
        return copied
    }

    func clearLastTranscript() { lastTranscript = nil }

    private func process(original: URL) async {
        let timing = PhaseTiming(phase: "stop-to-result")
        defer { timing.finish() }
        var preparedURL: URL?
        var mayCleanOriginal = false
        defer {
            if let preparedURL, preparedURL != original { operations.clean(preparedURL) }
            if mayCleanOriginal { operations.clean(original) }
            state = .idle
            task = nil
        }
        do {
            onStatus?("Audio vorbereiten …")
            try Task.checkCancellation()
            let prepared = try await operations.prepare(original)
            preparedURL = prepared.url
            try Task.checkCancellation()
            onStatus?("Transkribieren …")
            let text = try await operations.transcribeFile(prepared.url)
            try Task.checkCancellation()
            let result = await deliver(text)
            mayCleanOriginal = result.canRemoveRecoveryAudio
            if !mayCleanOriginal { mayCleanOriginal = preserve(original) }
        } catch {
            if Task.isCancelled && discardOnCancel {
                mayCleanOriginal = true
                onStatus?("Aufnahme verworfen")
            } else {
                mayCleanOriginal = preserve(original)
                if mayCleanOriginal {
                    onStatus?(
                        Task.isCancelled
                            ? "Abgebrochen – Aufnahme für Wiederholung gesichert"
                            : "\(error.localizedDescription) – Aufnahme für manuelle Wiederholung gesichert")
                }
            }
        }
    }

    private func preserve(_ url: URL) -> Bool {
        if operations.keep(url) { return true }
        // Do not destroy the only surviving audio when the recovery store fails.
        onStatus?("Sicherung fehlgeschlagen; Original bleibt unter \(url.path)")
        return false
    }

    private func deliver(_ text: String) async -> TranscriptDelivery {
        let timing = PhaseTiming(phase: "delivery")
        defer { timing.finish() }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            onStatus?("Kein Text – Aufnahme bleibt zur Wiederholung erhalten")
            return .empty
        }
        lastTranscript = text
        state = .delivering
        guard operations.copy(text) else {
            onStatus?("Zwischenablage nicht verfügbar – letzten Text erneut kopieren")
            return .clipboardFailed
        }
        guard !Task.isCancelled else {
            onStatus?("Text kopiert – automatisches Einfügen abgebrochen")
            return .copied
        }
        let pasted = await operations.paste()
        onStatus?(pasted ? "Einfügebefehl gesendet – Text auch kopiert" : "Text kopiert")
        return pasted ? .pasteSent : .copied
    }
}
