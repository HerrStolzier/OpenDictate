import XCTest

/// Drives the app like a person, in the simulator and on the iPhone, and
/// attaches screenshots to the result bundle. The live tests speak through the
/// Mac and are skipped unless the run passes `TEST_RUNNER_OD_KEYWORDS` (words
/// the spoken sentence must produce, comma-separated). They only show that a
/// dictation arrives, never how well speech is recognized.
@MainActor
final class OpenDictateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    }

    /// Every screen once, for a look before a build goes to the iPhone. Puts
    /// each setting it changes back afterwards.
    func testScreens() {
        app.launch()
        snapshot("Start")
        app.swipeUp()
        snapshot("Start, Einrichten")
        openSettings()
        snapshot("Einstellungen")
        let recognition = pickerValue("recognition")
        choose("Auf dem iPhone", in: "recognition")
        snapshot("Einstellungen, Erkennung auf dem iPhone")
        app.swipeUp()
        snapshot("Einstellungen, unten")
        let target = pickerValue("translationTarget")
        choose("Englisch", in: "translationTarget")
        snapshot("Einstellungen, Übersetzung")
        let engine = pickerValue("translationEngine")
        choose("Auf dem iPhone", in: "translationEngine")
        snapshot("Einstellungen, Übersetzung auf dem iPhone")

        choose(engine, in: "translationEngine")
        choose(target, in: "translationTarget")
        scrollBack(to: "recognition")
        choose(recognition, in: "recognition")
        app.buttons["Fertig"].tap()
        snapshot("Start nach den Einstellungen")
    }

    /// A dictation from the app's button with the current settings.
    func testDictationInApp() throws {
        let keywords = try liveKeywords()
        app.launch()
        app.buttons["Diktat starten"].tap()
        snapshot("Aufnahme")
        // The Mac speaks the sentence while the app records.
        sleep(8)
        app.buttons["Stopp"].tap()
        let text = app.staticTexts["lastText"]
        let state = app.descendants(matching: .any)["state"]
        XCTAssertTrue(text.waitForExistence(timeout: 30), "No text arrived, the app shows “\(state.label)”")
        snapshot("Ergebnis")
        assertContains(text.label, keywords)
    }

    /// The person's own shortcut "Diktieren" from the Shortcuts app, as Back Tap
    /// starts it, then pasting into a new note.
    func testShortcutPastesIntoNotes() throws {
        let keywords = try liveKeywords()
        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        // By name: a tile query also matches the search field's dictation button.
        let run = try XCTUnwrap(URL(string: "shortcuts://run-shortcut?name=Diktieren"))
        XCUIDevice.shared.system.open(run)
        sleep(8)
        snapshot("Kurzbefehl nimmt auf", of: shortcuts)
        XCUIDevice.shared.system.open(run)
        // Started by URL, Shortcuts may ask before it hands the text on; allow it
        // for this run only, so no lasting setting changes.
        let allowOnce = shortcuts.buttons["Einmal erlauben"]
        if allowOnce.waitForExistence(timeout: 30) {
            snapshot("Kurzbefehl fragt", of: shortcuts)
            allowOnce.tap()
        }
        // Translation, if set, and the copy step.
        sleep(5)
        snapshot("Kurzbefehl fertig", of: shortcuts)

        let notes = XCUIApplication(bundleIdentifier: "com.apple.mobilenotes")
        notes.launch()
        let compose = notes.buttons["Neue Notiz"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 10), "Notes has no “Neue Notiz” button")
        compose.tap()
        let body = notes.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        body.press(forDuration: 1.2)
        let paste = notes.menuItems["Einsetzen"].firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 5), "No “Einsetzen” in the edit menu")
        paste.tap()
        allowPasteIfAsked()
        snapshot("Notiz mit eingefügtem Text", of: notes)
        let pasted = body.value as? String ?? ""
        // Empty the note and leave it, so Notes drops it instead of keeping it.
        body.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: pasted.count))
        let back = notes.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }
        snapshot("Notizen nach dem Aufräumen", of: notes)
        assertContains(pasted, keywords)
    }

    // MARK: Helpers

    private func liveKeywords() throws -> [String] {
        let words = ProcessInfo.processInfo.environment["OD_KEYWORDS"] ?? ""
        let keywords = words.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !keywords.isEmpty else { throw XCTSkip("Live test: set TEST_RUNNER_OD_KEYWORDS and speak on the Mac.") }
        return keywords
    }

    private func assertContains(_ text: String, _ keywords: [String]) {
        let text = text.lowercased()
        for keyword in keywords {
            XCTAssertTrue(text.contains(keyword), "“\(keyword)” missing in the dictated text")
        }
    }

    private func openSettings() {
        let gear = app.buttons["Einstellungen"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
    }

    /// Scrolls the form up until the element is on screen. Never swipes down
    /// at the top, where the swipe would close the settings sheet.
    private func scrollBack(to identifier: String) {
        for _ in 0..<3 where !app.buttons[identifier].isHittable {
            app.collectionViews.firstMatch.swipeDown()
        }
    }

    /// The option a Form picker shows right now.
    private func pickerValue(_ picker: String) -> String {
        let button = app.buttons[picker]
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("No picker “\(picker)”")
            return ""
        }
        if let value = button.value as? String, !value.isEmpty { return value }
        // SwiftUI reports a Form picker as "Title, Option" in its label.
        return button.label.components(separatedBy: ", ").dropFirst().joined(separator: ", ")
    }

    /// A Form picker opens a menu; its options are buttons.
    private func choose(_ option: String, in picker: String) {
        let button = app.buttons[picker]
        guard button.waitForExistence(timeout: 5) else { return XCTFail("No picker “\(picker)”") }
        button.tap()
        let choice = app.buttons[option].firstMatch
        guard choice.waitForExistence(timeout: 5) else { return XCTFail("No option “\(option)”") }
        choice.tap()
    }

    /// iOS asks once per app before another app's text is pasted.
    private func allowPasteIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Einsetzen erlauben"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
    }

    private func snapshot(_ name: String, of target: XCUIApplication? = nil) {
        let attachment = XCTAttachment(screenshot: (target ?? app).screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
