/// Serializes work before DictationFlow owns an active operation, and keeps
/// termination decisions independent of flow changes inside a modal event loop.
@MainActor
final class AppLifecycle {
    enum Phase: Equatable { case running, confirmingQuit, terminating }
    enum TerminationReply: Equatable { case now, later, cancel }
    struct Operation: Equatable { fileprivate let id: UInt64 }

    private(set) var phase = Phase.running
    private(set) var terminationTask: Task<Void, Never>?
    private var nextID: UInt64 = 0
    private var operation: Operation?
    private var deferredStop: (() -> Void)?
    private var cancellationInProgress = false

    var acceptsActions: Bool { phase == .running && !cancellationInProgress }
    var canBeginOperation: Bool { acceptsActions && operation == nil }
    var isTerminating: Bool { phase == .terminating }

    func beginOperation() -> Operation? {
        guard canBeginOperation else { return nil }
        nextID &+= 1
        let value = Operation(id: nextID)
        operation = value
        return value
    }

    func isCurrent(_ value: Operation) -> Bool {
        acceptsActions && operation == value
    }

    func finish(_ value: Operation) {
        if operation == value { operation = nil }
    }

    func cancelPreparation() { operation = nil }

    func cancelDictation(_ action: () -> Void) {
        guard acceptsActions else { return }
        cancelPreparation()
        cancellationInProgress = true
        defer { cancellationInProgress = false }
        action()
    }

    @discardableResult
    func commit(_ value: Operation, action: () throws -> Void) rethrows -> Bool {
        guard isCurrent(value) else { return false }
        try action()
        return true
    }

    func automaticStop(_ action: @escaping () -> Void) {
        guard !cancellationInProgress else { return }
        switch phase {
        case .running: action()
        case .confirmingQuit: deferredStop = action
        case .terminating: break
        }
    }

    func requestTermination(
        hasActiveDictation: Bool, confirm: () -> Bool,
        cancel: () -> Task<Void, Never>?, reply: @escaping () -> Void
    ) -> TerminationReply {
        // A normal cancellation can synchronously preserve audio through a
        // Keychain modal before DictationFlow has a task to await.
        guard !cancellationInProgress else { return .cancel }
        switch phase {
        case .confirmingQuit: return .cancel
        case .terminating: return .later
        case .running: break
        }
        cancelPreparation()
        guard hasActiveDictation else {
            finishTermination()
            return .now
        }
        phase = .confirmingQuit
        guard confirm() else {
            phase = .running
            let stop = deferredStop
            deferredStop = nil
            stop?()
            return .cancel
        }
        finishTermination()
        // cancel() can itself enter a Keychain event loop while preserving audio.
        // Mark termination before calling it, and own exactly one eventual reply.
        let activeTask = cancel()
        terminationTask = Task { [weak self] in
            await activeTask?.value
            guard let self else { return }
            terminationTask = nil
            reply()
        }
        return .later
    }

    func finishTermination() {
        phase = .terminating
        cancelPreparation()
        deferredStop = nil
    }
}
