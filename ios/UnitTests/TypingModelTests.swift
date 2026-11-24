import XCTest

@testable import OpenDictateiOS

/// Tippen lernen: where a key is really hit moves its centre a little, only
/// after enough taps; the switch is off until turned on, and deleting forgets.
@MainActor
final class TypingModelTests: XCTestCase {
    func testAKeyHitRightOfItsCentreMovesRight() {
        var model = TypingModel()
        for _ in 0..<TypingModel.minimumTaps { model.record(key: "a", x: 0.2, y: 0) }
        let shift = model.shift(for: "a")
        XCTAssertEqual(shift?.x ?? 0, 0.2, accuracy: 0.001)
        XCTAssertEqual(shift?.y ?? 1, 0, accuracy: 0.001)
    }

    func testFewTapsMoveNothing() {
        var model = TypingModel()
        for _ in 0..<(TypingModel.minimumTaps - 1) { model.record(key: "a", x: 0.2, y: 0) }
        XCTAssertNil(model.shift(for: "a"))
    }

    func testAKeyMovesAtMostAThird() {
        var model = TypingModel()
        for _ in 0..<TypingModel.minimumTaps { model.record(key: "a", x: 0.7, y: -0.7) }
        XCTAssertEqual(model.shift(for: "a")?.x ?? 0, TypingModel.maximumShift, accuracy: 0.001)
        XCTAssertEqual(model.shift(for: "a")?.y ?? 0, -TypingModel.maximumShift, accuracy: 0.001)
    }

    func testATapFarOutsideTheKeyIsNotLearned() {
        var model = TypingModel()
        model.record(key: "a", x: 2, y: 0)
        XCTAssertEqual(model.tapCount, 0)
    }

    func testATapNearerTheLearnedCentreIsCloser() {
        var model = TypingModel()
        for _ in 0..<TypingModel.minimumTaps { model.record(key: "s", x: -0.25, y: 0.1) }
        XCTAssertLessThan(model.distance(fromKey: "s", x: -0.25, y: 0.1), model.distance(fromKey: "s", x: 0.25, y: 0))
    }

    private func bridge(_ name: String, in folder: URL) throws -> (KeyboardBridge, UserDefaults) {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (KeyboardBridge(defaults: defaults, directory: folder), defaults)
    }

    /// What was learned stays out of the iPhone's backups unless the person
    /// turns the backup on (Basti, 24 November).
    func testTheLearnedModelIsKeptOutOfBackups() throws {
        let name = "TypingModelTests.\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let (bridge, defaults) = try bridge(name, in: folder)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: folder)
        }
        var model = TypingModel()
        model.record(key: "a", x: 0.1, y: 0)
        bridge.typingModel = model
        XCTAssertEqual(bridge.typingModel, model)
        XCTAssertNil(defaults.data(forKey: "typing.model"), "The model is in the backed-up settings")
        XCTAssertFalse(bridge.backsUpTyping)
        var file = folder.appendingPathComponent("TypingModel.json")
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        // Turned on in the settings, the same file goes into backups.
        bridge.backsUpTyping = true
        file.removeAllCachedResourceValues()
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, false)
        bridge.backsUpTyping = false
        file.removeAllCachedResourceValues()
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    /// A model an earlier build kept in the settings moves out of them.
    func testAModelInTheOldPlaceMovesOutOfTheSettings() throws {
        let name = "TypingModelTests.\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let (bridge, defaults) = try bridge(name, in: folder)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: folder)
        }
        var model = TypingModel()
        model.record(key: "s", x: -0.1, y: 0.1)
        defaults.set(try JSONEncoder().encode(model), forKey: "typing.model")
        XCTAssertEqual(bridge.typingModel, model)
        XCTAssertNil(defaults.data(forKey: "typing.model"))
        XCTAssertEqual(bridge.typingModel, model)
        let file = folder.appendingPathComponent("TypingModel.json")
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    /// The old model leaves the settings only once the file holds it: when
    /// the file cannot be written, nothing learned is lost.
    func testAModelInTheOldPlaceIsKeptWhenTheFileCannotBeWritten() throws {
        let name = "TypingModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        // Never created, so the file cannot be written into it.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let bridge = KeyboardBridge(defaults: defaults, directory: folder)
        var model = TypingModel()
        model.record(key: "s", x: -0.1, y: 0.1)
        defaults.set(try JSONEncoder().encode(model), forKey: "typing.model")
        XCTAssertEqual(bridge.typingModel, model)
        XCTAssertEqual(bridge.typingModel, model, "The learned model was dropped before it was saved anywhere")
    }

    func testLearningIsOffUntilTurnedOnAndDeletingForgets() throws {
        let name = "TypingModelTests.\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let (bridge, defaults) = try bridge(name, in: folder)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: folder)
        }
        XCTAssertFalse(bridge.learnsTyping)
        var model = TypingModel()
        model.record(key: "a", x: 0.1, y: 0)
        bridge.typingModel = model
        XCTAssertEqual(bridge.typingModel, model)
        bridge.forgetTyping()
        XCTAssertEqual(bridge.typingModel.tapCount, 0)
    }

    /// Both keys are hit at their centres on average, so neither touch area
    /// moves: a tap inside "a", 0.4 right of its centre, still goes to "a",
    /// however unevenly "s" is hit. `KeyArea.hitTest` picks the key with the
    /// smaller `distance`.
    func testAKeyNobodyHitsOffCentreKeepsItsArea() {
        var model = TypingModel()
        for index in 0..<TypingModel.minimumTaps {
            model.record(key: "a", x: 0, y: 0)
            model.record(key: "s", x: index.isMultiple(of: 2) ? 0.4 : -0.4, y: 0)
        }
        XCTAssertEqual(model.shift(for: "a")?.x ?? 1, 0, accuracy: 0.001)
        XCTAssertEqual(model.shift(for: "s")?.x ?? 1, 0, accuracy: 0.001)
        XCTAssertLessThan(
            model.distance(fromKey: "a", x: 0.4, y: 0), model.distance(fromKey: "s", x: 0.4 - 1, y: 0),
            "A tap inside “a” goes to “s” although neither key moved")
    }

    /// A learned slip lowers the cost of that substitution.
    func testALearnedSlipLowersTheCost() {
        let plain = Autocorrect.cost(from: "dss", to: "das")
        let learned = Autocorrect.cost(from: "dss", to: "das", slips: [[], ["a"], []])
        XCTAssertLessThan(learned, plain)
    }
}
