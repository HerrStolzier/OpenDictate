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

        try dictateIntoNewNote(keywords)
    }

    /// "Keep microphone warm" from the Shortcuts app while OpenDictate is not
    /// running, then a dictation from the keyboard: OpenDictate never comes to
    /// the front.
    func testWarmShortcutThenKeyboardDictates() throws {
        let keywords = try liveKeywords()
        try addKeyboard()
        app.terminate()
        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        shortcuts.launch()
        let search = shortcuts.searchFields.firstMatch
        if !search.waitForExistence(timeout: 5) { shortcuts.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Shortcuts shows no search field")
        search.tap()
        search.typeText("Mikro warm")
        let action = shortcuts.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Mikro warm halten'")).element(boundBy: 0)
        XCTAssertTrue(action.waitForExistence(timeout: 10), "No “Mikro warm halten” in Shortcuts")
        snapshot("Kurzbefehle, Mikro warm halten", of: shortcuts)
        action.tap()
        sleep(5)
        snapshot("Kurzbefehle nach dem Start", of: shortcuts)
        XCTAssertNotEqual(app.state, .runningForeground, "OpenDictate came to the front")
        XCTAssertEqual(app.state, .runningBackground, "OpenDictate does not run in the background")
        try dictateIntoNewNote(keywords)
    }

    /// The Live Activity's stop button while the keyboard records: the warm
    /// microphone goes off once that dictation is written, instead of staying
    /// warm for the chosen time.
    func testLiveActivityStopEndsWarmMicrophoneWhileKeyboardRecords() throws {
        _ = try liveKeywords()
        try addKeyboard()
        app.launch()
        app.swipeUp()
        let warm = app.buttons["startWarm"]
        if warm.waitForExistence(timeout: 5) { warm.tap() }
        XCTAssertTrue(app.buttons["endWarm"].waitForExistence(timeout: 60), "The microphone did not get warm")

        let notes = XCUIApplication(bundleIdentifier: "com.apple.mobilenotes")
        notes.launch()
        let compose = notes.buttons["Neue Notiz"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 10), "Notes has no “Neue Notiz” button")
        compose.tap()
        let body = notes.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        try switchToOpenDictate(in: notes)
        notes.buttons["openDictate.dictate"].tap()
        XCTAssertTrue(
            notes.buttons.matching(NSPredicate(format: "label CONTAINS 'Fertig'")).firstMatch.waitForExistence(
                timeout: 5), "The key does not show “Fertig”")

        // Notification Center shows the Live Activity "Mikro warm" with its stop button.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.005))
        top.press(
            forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7)))
        let stop = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Stopp", "Stop"])).firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 10), "No stop button on the Live Activity")
        snapshot("Mitteilungszentrale, Mikro warm", of: springboard)
        stop.tap()
        XCUIDevice.shared.press(.home)

        app.activate()
        app.swipeUp()
        let wentOff = app.buttons["startWarm"].waitForExistence(timeout: 30)
        snapshot("App nach Stopp der Live-Aktivität", of: app)
        if app.buttons["endWarm"].exists { app.buttons["endWarm"].tap() }
        notes.activate()
        body.tap()
        cleanUp(note: body, text: body.value as? String ?? "", in: notes)
        XCTAssertTrue(wentOff, "The microphone stayed warm after the Live Activity's stop button")
    }

    /// The key left of the space bar: a tap types a period, holding it a comma, never both.
    func testPeriodKeyTapTypesPeriodAndHoldTypesComma() throws {
        try addKeyboard()
        // The Settings search field: there in the simulator too, unlike Notes.
        settings.terminate()
        settings.launch()
        let search = settings.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        try switchToOpenDictate(in: settings)
        let period = settings.buttons["openDictate.key.period"]
        XCTAssertTrue(period.waitForExistence(timeout: 5), "No period key")
        period.tap()
        period.press(forDuration: 0.8)
        snapshot("Punkt und Komma", of: settings)
        let typed = search.value as? String ?? ""
        settings.terminate()
        XCTAssertEqual(typed.filter { $0 == "." || $0 == "," }, ".,", "Tap and hold typed “\(typed)”")
    }

    // MARK: Helpers

    /// A dictation from the keyboard into a new note, then the note is
    /// deleted and the warm microphone turned off. Reports the stop-to-text
    /// time and the keyboard's memory.
    private func dictateIntoNewNote(_ keywords: [String]) throws {
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
        // On the iPhone a tap right after launch can go nowhere: tap until the next page shows.
        let keyboards = settings.cells["KEYBOARDS"]
        let steps = [(row("Allgemein"), row("Tastatur")), (row("Tastatur"), keyboards), (keyboards, addKeyboardRow)]
        for (element, next) in steps {
            for _ in 0..<3 where !next.waitForExistence(timeout: 2) { tap(element, scrollingIn: settings) }
        }
        if !row("OpenDictate").waitForExistence(timeout: 2) {
            tap(addKeyboardRow, scrollingIn: settings)
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

    private var addKeyboardRow: XCUIElement { settings.cells["AddNewKeyboard"] }

    /// A Settings row by its title: the cell holding that text, or the text
    /// itself where the cell does not report it (some root rows).
    private func row(_ title: String) -> XCUIElement {
        let label = NSPredicate(format: "label == %@", title)
        let cell = settings.cells.containing(label).firstMatch
        return cell.exists ? cell : settings.staticTexts.matching(label).firstMatch
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
        // The list may be scrolled either way: down to the top first, then up.
        for attempt in 0..<8 where !(element.waitForExistence(timeout: 1) && element.isHittable) {
            attempt < 3 ? host.swipeDown() : host.swipeUp()
        }
        XCTAssertTrue(element.exists, "Not found: \(element)")
        // On the iPhone the search bar floats over the lowest rows; a tap there opens the search.
        for _ in 0..<3 where element.frame.maxY > host.frame.height * 0.8 {
            let from = host.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            from.press(forDuration: 0.05, thenDragTo: host.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
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
