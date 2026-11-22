import Foundation

// The app and the keyboard extension talk through the App Group: the keyboard
// writes a command, the app writes a snapshot, and each posts a Darwin
// notification so the other side reads at once instead of waiting for its
// next poll. The shape follows Hex (github.com/anomalyco/hex, MIT, see
// ios/Keyboard/THIRD_PARTY_NOTICES.md). Neither side ever puts audio here,
// only the finished text for the keyboard to insert.

/// How long the app keeps the microphone open after the last dictation, so
/// the keyboard can dictate without bringing the app to the front.
enum WarmDuration: String, CaseIterable, Codable, Sendable {
    /// One dictation, then the session ends.
    case off
    case fiveMinutes = "5"
    case fifteenMinutes = "15"
    case oneHour = "60"

    static let standard = WarmDuration.fifteenMinutes
    /// How long an "off" session waits for its one dictation.
    static let oneShotWait: TimeInterval = 2 * 60

    var seconds: TimeInterval {
        switch self {
        case .off: Self.oneShotWait
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .oneHour: 60 * 60
        }
    }

    var endsAfterOneDictation: Bool { self == .off }
}

enum KeyboardCommandKind: String, Codable, Sendable {
    case start
    case stop
}

struct KeyboardCommand: Codable, Equatable, Sendable {
    let id: String
    let kind: KeyboardCommandKind
    /// One dictation from start to inserted text.
    let jobID: String
    let sentAt: TimeInterval

    init(
        kind: KeyboardCommandKind, jobID: String, id: String = UUID().uuidString,
        sentAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.kind = kind
        self.jobID = jobID
        self.sentAt = sentAt
    }

    /// A command the app saw only much later (it was suspended or ended)
    /// must not start a recording nobody expects any more.
    static let maximumAge: TimeInterval = 10

    func isFresh(at now: TimeInterval) -> Bool { now - sentAt < Self.maximumAge }
}

enum KeyboardSessionState: String, Codable, Sendable {
    case off
    case ready
    case recording
    case writing
}

/// What the app tells the keyboard. Written about once a second while a
/// session runs; a snapshot that stopped updating means the app is gone.
struct KeyboardSnapshot: Codable, Equatable, Sendable {
    var state: KeyboardSessionState
    var heartbeat: TimeInterval
    /// When the warm session ends unless another dictation extends it.
    var warmUntil: TimeInterval
    var recordingSince: TimeInterval?
    /// The job of the recording or text below.
    var jobID: String?
    var resultID: String?
    /// The finished text, only until the keyboard confirmed it.
    var text: String?
    var resultAt: TimeInterval?
    /// Why the last dictation failed, in the app's language.
    var message: String?
    var messageAt: TimeInterval?

    static let off = KeyboardSnapshot(state: .off, heartbeat: 0, warmUntil: 0)

    /// The app writes at least every second while it holds the microphone.
    static let heartbeatTimeout: TimeInterval = 3
    /// A text not inserted by then belongs to a field the person left.
    static let resultLifetime: TimeInterval = 60
    static let messageLifetime: TimeInterval = 8

    func isAlive(at now: TimeInterval) -> Bool {
        heartbeat > 0 && now - heartbeat < Self.heartbeatTimeout
    }

    /// The state the keyboard acts on: a session whose app stopped writing
    /// or whose time ran out is off.
    func effectiveState(at now: TimeInterval) -> KeyboardSessionState {
        guard isAlive(at: now) else { return .off }
        if state == .ready, warmUntil <= now { return .off }
        return state
    }

    /// A text for `jobID` that the keyboard has not inserted yet.
    func deliverableText(forJob jobID: String?, insertedResultID: String?, at now: TimeInterval) -> String? {
        guard let jobID, self.jobID == jobID, let resultID, resultID != insertedResultID,
            let text, !text.isEmpty, let resultAt, now - resultAt < Self.resultLifetime
        else { return nil }
        return text
    }

    func currentMessage(forJob jobID: String?, at now: TimeInterval) -> String? {
        guard let jobID, self.jobID == jobID, let message, let messageAt,
            now - messageAt < Self.messageLifetime
        else { return nil }
        return message
    }
}

/// The address the keyboard opens when no session runs.
enum KeyboardLink {
    static let scheme = "opendictate"
    static let startSession = URL(string: "\(scheme)://keyboard/start")!

    static func isStartSession(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "keyboard" && url.path == "/start"
    }
}

/// Without Full Access the keyboard cannot write here; typing still works.
struct KeyboardBridge: @unchecked Sendable {
    static let appGroup = "group.app.opendictate.ios"
    static let commandNotification = "app.opendictate.ios.keyboard.command"
    static let snapshotNotification = "app.opendictate.ios.keyboard.snapshot"
    static let insertedNotification = "app.opendictate.ios.keyboard.inserted"

    private enum Key {
        static let command = "keyboard.command"
        static let snapshot = "keyboard.snapshot"
        static let insertedResultID = "keyboard.insertedResultID"
        static let warmDuration = "keyboard.warmDuration"
    }

    // `UserDefaults` is thread-safe; the type is not marked Sendable.
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyboardBridge.appGroup)) {
        self.defaults = defaults
    }

    var isAvailable: Bool { defaults != nil }

    func send(_ command: KeyboardCommand) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        defaults?.set(data, forKey: Key.command)
        Self.post(Self.commandNotification)
    }

    func command() -> KeyboardCommand? {
        guard let data = defaults?.data(forKey: Key.command) else { return nil }
        return try? JSONDecoder().decode(KeyboardCommand.self, from: data)
    }

    func publish(_ snapshot: KeyboardSnapshot, notify: Bool = true) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: Key.snapshot)
        if notify { Self.post(Self.snapshotNotification) }
    }

    func snapshot() -> KeyboardSnapshot {
        guard let data = defaults?.data(forKey: Key.snapshot),
            let snapshot = try? JSONDecoder().decode(KeyboardSnapshot.self, from: data)
        else { return .off }
        return snapshot
    }

    /// Set by the keyboard once a text is in the field, so the app can drop
    /// the recording behind it.
    var insertedResultID: String? {
        get { defaults?.string(forKey: Key.insertedResultID) }
        nonmutating set {
            defaults?.set(newValue, forKey: Key.insertedResultID)
            Self.post(Self.insertedNotification)
        }
    }

    var warmDuration: WarmDuration {
        get { defaults?.string(forKey: Key.warmDuration).flatMap(WarmDuration.init(rawValue:)) ?? .standard }
        nonmutating set { defaults?.set(newValue.rawValue, forKey: Key.warmDuration) }
    }

    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }

    /// Calls `handler` on the main queue for every post of `name`, for the
    /// life of the process.
    static func observe(_ name: String, handler: @escaping @MainActor () -> Void) {
        let box = Unmanaged.passRetained(DarwinHandler(handler)).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), box,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let handler = Unmanaged<DarwinHandler>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { MainActor.assumeIsolated { handler.handler() } }
            }, name as CFString, nil, .deliverImmediately)
    }
}

private final class DarwinHandler: @unchecked Sendable {
    let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) { self.handler = handler }
}
