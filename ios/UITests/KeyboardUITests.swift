import XCTest

/// The OpenDictate keyboard in other apps: added once in iOS Settings with
/// Full Access, then typing and, on the iPhone, a dictation through the warm
/// microphone into a new note. The dictation test speaks through the Mac and is
/// skipped unless the run passes `TEST_RUNNER_OD_KEYWORDS`, like the other
/// live tests; it needs the Parakeet model loaded in the app.
@MainActor
final class KeyboardUITests: XCTestCase {
    private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    }

    /// The keyboard in the light Settings app and in the dark app, and the
    /// app's keyboard card. Leaves the keyboard added.
    func testKeyboardScreens() throws {
        try addKeyboard()
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            XCUIDevice.shared.appearance = appearance
            settings.terminate()
            settings.launch()
            let search = settings.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 10))
            search.tap()
            try switchToOpenDictate(in: settings)
            snapshot("Tastatur \(appearance == .light ? "hell" : "dunkel")", of: settings)
        }
        XCUIDevice.shared.appearance = .light
        app.launch()
        app.swipeUp()
        snapshot("App, Karte Tastatur", of: app)
    }

    /// Warm microphone in the app, then a dictation from the keyboard into a
    /// new note. Reports the stop-to-text time and the keyboard's memory.
    func testKeyboardDictatesIntoNotes() throws {
        let keywords = try liveKeywords()
        try addKeyboard()
        app.launch()
        app.swipeUp()
        let warm = app.buttons["startWarm"]
        if warm.waitForExistence(timeout: 5) { warm.tap() }
        XCTAssertTrue(app.buttons["endWarm"].waitForExistence(timeout: 60), "The microphone did not get warm")
        snapshot("App, Mikro warm", of: app)

        let notes = XCUIApplication(bundleIdentifier: "com.apple.mobilenotes")
        notes.launch()
        let compose = notes.buttons["Neue Notiz"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 10), "Notes has no “Neue Notiz” button")
        compose.tap()
        let body = notes.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        try switchToOpenDictate(in: notes)
        let dictate = notes.buttons["openDictate.dictate"]
        XCTAssertTrue(dictate.waitForExistence(timeout: 5))
        let status = notes.staticTexts["openDictate.status"]
        snapshot("Notiz, Tastatur bereit", of: notes)
        dictate.tap()
        XCTAssertTrue(
            notes.buttons.matching(NSPredicate(format: "label CONTAINS 'Fertig'")).firstMatch.waitForExistence(
                timeout: 5), "The key does not show “Fertig”")
        snapshot("Notiz, Tastatur hört zu", of: notes)
        // The Mac speaks the sentence meanwhile.
        sleep(6)
        dictate.tap()
        let arrived = NSPredicate { object, _ in
            let text = ((object as? XCUIElement)?.value as? String ?? "").lowercased()
            return keywords.allSatisfy { text.contains($0) }
        }
        let wait = XCTNSPredicateExpectation(predicate: arrived, object: body)
        let result = XCTWaiter().wait(for: [wait], timeout: 90)
        snapshot("Notiz mit diktiertem Text", of: notes)
        let measured = status.value as? String ?? ""
        let note = XCTAttachment(string: measured)
        note.name = "Tastatur-Messung"
        note.lifetime = .keepAlways
        add(note)
        let dictated = body.value as? String ?? ""
        cleanUp(note: body, text: dictated, in: notes)
        app.launch()
        app.swipeUp()
        if app.buttons["endWarm"].waitForExistence(timeout: 5) { app.buttons["endWarm"].tap() }
        XCTAssertEqual(result, .completed, "Text did not arrive; keyboard said “\(measured)”")
    }

    // MARK: Helpers

    /// Settings → General → Keyboard → Keyboards: adds OpenDictate with Full
    /// Access unless it is there already.
    private func addKeyboard() throws {
        settings.launch()
        // Settings reopens where the last run left it.
        for _ in 0..<5 where !row("Allgemein").waitForExistence(timeout: 2) {
            let back = settings.navigationBars.buttons.firstMatch
            guard back.exists else { break }
            back.tap()
        }
        tap(row("Allgemein"), scrollingIn: settings)
        tap(row("Tastatur"), scrollingIn: settings)
        tap(row("Tastaturen"), scrollingIn: settings)
        if !row("OpenDictate").waitForExistence(timeout: 2) {
            tap(settings.cells["AddNewKeyboard"], scrollingIn: settings)
            tap(row("OpenDictate"), scrollingIn: settings)
        }
        snapshot("Einstellungen, Tastaturen", of: settings)
        tap(row("OpenDictate"), scrollingIn: settings)
        let fullAccess = settings.switches.firstMatch
        XCTAssertTrue(fullAccess.waitForExistence(timeout: 5), "No Full Access switch")
        if (fullAccess.value as? String) != "1" {
            // The switch's frame is the whole row; its knob sits at the right end.
            fullAccess.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let allow = settings.alerts.buttons["Erlauben"]
            if allow.waitForExistence(timeout: 5) { allow.tap() }
            _ = fullAccess.waitForExistence(timeout: 2)
        }
        snapshot("Einstellungen, Voller Zugriff", of: settings)
        XCTAssertEqual(fullAccess.value as? String, "1", "Full Access is off")
    }

    /// A Settings row by its title; the title is the label of the row or of a text in it.
    private func row(_ title: String) -> XCUIElement {
        settings.cells.containing(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Taps the system's keyboard switch until the OpenDictate keyboard shows.
    private func switchToOpenDictate(in host: XCUIApplication) throws {
        let dictate = host.buttons["openDictate.dictate"]
        for _ in 0..<6 where !dictate.waitForExistence(timeout: 3) {
            let next = host.buttons["Nächste Tastatur"].firstMatch
            guard next.waitForExistence(timeout: 5) else { break }
            next.tap()
        }
        if !dictate.waitForExistence(timeout: 5) { snapshot("Tastatur fehlt", of: host) }
        XCTAssertTrue(dictate.exists, "The OpenDictate keyboard did not show")
    }

    private func tap(_ element: XCUIElement, scrollingIn host: XCUIApplication) {
        for _ in 0..<5 where !(element.waitForExistence(timeout: 2) && element.isHittable) {
            host.swipeUp()
        }
        XCTAssertTrue(element.exists, "Not found: \(element)")
        element.tap()
    }

    private func cleanUp(note body: XCUIElement, text: String, in notes: XCUIApplication) {
        // Replace the text with a marker only this run writes, then delete the
        // note that carries it, as the shortcut test does.
        let marker = String(Int.random(in: 100_000_000_000...999_999_999_999))
        body.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count) + marker)
        let back = notes.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }
        let created = notes.cells.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        if created.waitForExistence(timeout: 3) {
            created.swipeLeft()
            let delete = notes.buttons["Löschen"].firstMatch
            if delete.waitForExistence(timeout: 3) { delete.tap() }
        }
    }

    private func liveKeywords() throws -> [String] {
        let words = ProcessInfo.processInfo.environment["OD_KEYWORDS"] ?? ""
        let keywords = words.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !keywords.isEmpty else { throw XCTSkip("Live test: set TEST_RUNNER_OD_KEYWORDS and speak on the Mac.") }
        return keywords
    }

    private func snapshot(_ name: String, of target: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: target.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIElementQuery {
    fileprivate func matching(label prefix: String) -> XCUIElement {
        matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }
}
