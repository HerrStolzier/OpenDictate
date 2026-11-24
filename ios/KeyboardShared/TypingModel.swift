import Foundation

/// "Tippen lernen": where this person hits each key, kept only on this
/// iPhone. Each kept tap adds its offset from the key's centre, in key widths
/// and heights; no text is stored. After the Gaussian spatial model Gboard
/// described in 2017, each key gets a learned centre, which (a) moves the
/// key's touch area a little towards where the person really taps and (b) let
/// autocorrection treat a tap near a neighbouring key as a likely slip.
struct TypingModel: Codable, Equatable, Sendable {
    struct KeyStats: Codable, Equatable, Sendable {
        var count = 0
        var meanX = 0.0
        var meanY = 0.0

        /// A running mean.
        mutating func add(x: Double, y: Double) {
            count += 1
            meanX += (x - meanX) / Double(count)
            meanY += (y - meanY) / Double(count)
        }

    }

    private(set) var keys: [String: KeyStats] = [:]

    /// Taps a key needs before its learned centre counts.
    static let minimumTaps = 20
    /// How far a key's centre may move, in key sizes.
    static let maximumShift = 0.3

    /// Offsets beyond the key's own area are not taps on it.
    mutating func record(key: String, x: Double, y: Double) {
        guard abs(x) <= 0.75, abs(y) <= 0.75 else { return }
        keys[key.lowercased(), default: KeyStats()].add(x: x, y: y)
    }

    /// Where the key is really hit, relative to its centre, once it has
    /// enough taps; never more than `maximumShift`.
    func shift(for key: String) -> (x: Double, y: Double)? {
        guard let stats = keys[key.lowercased()], stats.count >= Self.minimumTaps else { return nil }
        let clamp = { (value: Double) in min(Self.maximumShift, max(-Self.maximumShift, value)) }
        return (clamp(stats.meanX), clamp(stats.meanY))
    }

    /// How far a point is from the key's learned centre, in key sizes;
    /// `x`/`y` are relative to the key's drawn centre. Only the centres
    /// move: a key's own spread never widens or narrows its area, or a key hit
    /// unevenly would take taps from a key hit evenly.
    func distance(fromKey key: String, x: Double, y: Double) -> Double {
        let centre = shift(for: key) ?? (0, 0)
        let dx = x - centre.x
        let dy = y - centre.y
        return (dx * dx + dy * dy).squareRoot()
    }

    var tapCount: Int { keys.values.reduce(0) { $0 + $1.count } }
}

extension KeyboardBridge {
    private static let learnKey = "typing.learn"
    private static let modelKey = "typing.model"
    private static let resetKey = "typing.resets"
    private static let backupKey = "typing.backup"

    /// The switch in the app; off unless the person turns it on.
    var learnsTyping: Bool {
        get { defaults?.bool(forKey: Self.learnKey) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Self.learnKey) }
    }

    /// Kept in a file of its own, out of backups unless the person turns
    /// `backsUpTyping` on (Basti, 24 November): it fits only this iPhone's
    /// keyboard and relearns in a few days. A model an earlier build kept in
    /// the App Group's settings, which are backed up, moves there on first read.
    var typingModel: TypingModel {
        get {
            if let old = defaults?.data(forKey: Self.modelKey) {
                guard let model = try? JSONDecoder().decode(TypingModel.self, from: old) else {
                    defaults?.removeObject(forKey: Self.modelKey)
                    return TypingModel()
                }
                // Leaves the settings only once the file holds it.
                if save(model) { defaults?.removeObject(forKey: Self.modelKey) }
                return model
            }
            guard let file = modelFile, let data = try? Data(contentsOf: file),
                let model = try? JSONDecoder().decode(TypingModel.self, from: data)
            else { return TypingModel() }
            return model
        }
        nonmutating set { save(newValue) }
    }

    @discardableResult
    private func save(_ model: TypingModel) -> Bool {
        guard let file = modelFile, let data = try? JSONEncoder().encode(model),
            (try? data.write(to: file, options: .atomic)) != nil
        else { return false }
        applyTypingBackup()
        return true
    }

    /// "Gelerntes im Backup sichern" in the app; off unless turned on.
    var backsUpTyping: Bool {
        get { defaults?.bool(forKey: Self.backupKey) ?? false }
        nonmutating set {
            defaults?.set(newValue, forKey: Self.backupKey)
            applyTypingBackup()
        }
    }

    private func applyTypingBackup() {
        guard var file = modelFile, FileManager.default.fileExists(atPath: file.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = !backsUpTyping
        try? file.setResourceValues(values)
    }

    private var modelFile: URL? { directory?.appendingPathComponent("TypingModel.json") }

    /// "Delete what was learned" in the app. The keyboard compares the
    /// count before it saves, so a model it still holds is not written back.
    func forgetTyping() {
        defaults?.removeObject(forKey: Self.modelKey)
        if let modelFile { try? FileManager.default.removeItem(at: modelFile) }
        defaults?.set(typingResets + 1, forKey: Self.resetKey)
    }

    var typingResets: Int { defaults?.integer(forKey: Self.resetKey) ?? 0 }
}
