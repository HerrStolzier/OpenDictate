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

    /// "Keep microphone warm" from Spotlight while OpenDictate is not
    /// running, then a dictation from the keyboard: OpenDictate never comes to
    /// the front.
    func testWarmShortcutThenKeyboardDictates() throws {
        let keywords = try liveKeywords()
        try addKeyboard()
        app.terminate()
        // The Shortcuts app's search lists only the person's own shortcuts;
        // Spotlight lists the app's, as the Action button offers them.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        sleep(1)
        // The home screen's search button, else a swipe down from its middle.
        let searchButton = springboard.buttons["Suchen"].firstMatch
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        } else {
            let middle = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 250)))
        }
        // Spotlight runs as its own process.
        let spotlight = XCUIApplication(bundleIdentifier: "com.apple.Spotlight")
        let search = spotlight.textFields["SpotlightSearchField"]
        _ = search.waitForExistence(timeout: 5)
        XCTAssertTrue(search.exists, "No Spotlight search")
        search.typeText("Mikro warm")
        // The top hit sits right under its heading; the search field completes
        // to the same words, so a search by label finds the field first.
        let heading = spotlight.staticTexts["Toptreffer"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10), "No top hit in Spotlight")
        snapshot("Spotlight, Mikro warm halten", of: spotlight)
        let action = heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 100, dy: heading.frame.height / 2 + 48))
        action.tap()
        sleep(5)
        snapshot("Nach dem Start", of: springboard)
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

    /// The key left of the space bar: a tap types a period, holding it a comma, never both,
    /// and its bubble is gone once the key is let go.
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
        // The bubble over the key shows the period while down and the comma when held; it goes on release.
        let periodBubbleLeft = settings.staticTexts["."].exists
        period.press(forDuration: 0.8)
        let commaBubbleLeft = settings.staticTexts[","].exists
        snapshot("Punkt und Komma", of: settings)
        let typed = search.value as? String ?? ""
        settings.terminate()
        XCTAssertEqual(typed.filter { $0 == "." || $0 == "," }, ".,", "Tap and hold typed “\(typed)”")
        XCTAssertFalse(periodBubbleLeft, "The period bubble stayed after the tap")
        XCTAssertFalse(commaBubbleLeft, "The comma bubble stayed after the hold")
    }

    /// Typing "hsus" offers "Haus"; a tap on it puts it in. The emoji key
    /// opens the panel and a tap there types the emoji. (The Settings search
    /// field turns autocorrection off, so space keeps the word there;
    /// `testSpaceFixesAndDeleteRestoresInNotes` checks space and delete.)
    func testAutocorrectAndEmoji() throws {
        try addKeyboard()
        settings.terminate()
        settings.launch()
        let search = settings.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        try switchToOpenDictate(in: settings)
        for letter in "hsus" { settings.buttons["openDictate.key.\(letter)"].tap() }
        let best = settings.buttons["openDictate.suggestion.1"]
        XCTAssertTrue(best.waitForExistence(timeout: 3), "No suggestions")
        snapshot("Vorschlagsleiste", of: settings)
        XCTAssertEqual(best.label.lowercased(), "haus")
        // This field turns autocorrection off, so space keeps the word and it shows without quotes.
        XCTAssertEqual(
            settings.buttons["openDictate.suggestion.0"].label.lowercased(), "hsus",
            "Without autocorrection the typed word shows without quotes")
        best.tap()
        let picked = (search.value as? String ?? "").lowercased()
        XCTAssertEqual(picked, "haus ", "The suggestion put in “\(picked)”")

        settings.buttons["openDictate.emojiKey"].tap()
        let panel = settings.collectionViews["openDictate.emoji"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3), "No emoji panel")
        snapshot("Emoji", of: settings)
        panel.cells.firstMatch.tap()
        let typed = search.value as? String ?? ""
        settings.terminate()
        XCTAssertTrue(typed.unicodeScalars.contains { $0.properties.isEmojiPresentation }, "No emoji in “\(typed)”")
    }

    /// In a field with autocorrection (Notes, so only on the iPhone): "hsus"
    /// and space become "Haus ", and delete right after brings back "hsus".
    func testSpaceFixesAndDeleteRestoresInNotes() throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("The simulator has no Notes")
        #endif
        try addKeyboard()
        let notes = XCUIApplication(bundleIdentifier: "com.apple.mobilenotes")
        notes.launch()
        let compose = notes.buttons["Neue Notiz"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 10), "Notes has no “Neue Notiz” button")
        compose.tap()
        let body = notes.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        try switchToOpenDictate(in: notes)
        for letter in "hsus" { notes.buttons["openDictate.key.\(letter)"].tap() }
        notes.buttons["openDictate.space"].tap()
        let fixed = body.value as? String ?? ""
        snapshot("Notiz, korrigiert", of: notes)
        notes.buttons["openDictate.delete"].tap()
        let restored = body.value as? String ?? ""
        cleanUp(note: body, text: restored, in: notes)
        XCTAssertEqual(fixed.lowercased(), "haus ", "Space put in “\(fixed)”")
        XCTAssertEqual(restored.lowercased(), "hsus", "Delete after the fix gave “\(restored)”")
    }

    /// Holding the space bar and sliding left moves the cursor a character.
    func testSpaceBarSlideMovesTheCursor() throws {
        try addKeyboard()
        settings.terminate()
        settings.launch()
        let search = settings.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        try switchToOpenDictate(in: settings)
        for letter in "ab" { settings.buttons["openDictate.key.\(letter)"].tap() }
        let space = settings.buttons["openDictate.space"]
        let start = space.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.6, thenDragTo: start.withOffset(CGVector(dx: -13, dy: 0)))
        settings.buttons["openDictate.key.x"].tap()
        let typed = (search.value as? String ?? "").lowercased()
        settings.terminate()
        XCTAssertEqual(typed, "axb", "Sliding then typing gave “\(typed)”")
    }

    /// Holding delete deletes on while held, stops on release, and the
    /// keyboard stays.
    func testHoldingDeleteDeletesOn() throws {
        try addKeyboard()
        settings.terminate()
        settings.launch()
        let search = settings.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        try switchToOpenDictate(in: settings)
        for letter in "qwertzuiop" { settings.buttons["openDictate.key.\(letter)"].tap() }
        settings.buttons["openDictate.delete"].press(forDuration: 0.75)
        let left = (search.value as? String ?? "").lowercased()
        // Long enough for several more steps, had the repeat not stopped.
        sleep(1)
        let later = (search.value as? String ?? "").lowercased()
        let keyboardStayed = settings.buttons["openDictate.dictate"].exists
        settings.terminate()
        XCTAssertTrue(left.hasPrefix("qwe") && left.count < 9, "Holding delete left “\(left)”")
        XCTAssertEqual(later, left, "Delete went on after release")
        XCTAssertTrue(keyboardStayed, "The OpenDictate keyboard was gone after holding delete")
    }

    /// Leaving the note while the keyboard records and coming back: the
    /// keyboard shown anew takes the dictation over, and its text arrives in
    /// that same note.
    func testKeyboardDictationArrivesAfterLeavingAndReturningToTheNote() throws {
        let keywords = try liveKeywords()
        try addKeyboard()
        let (notes, body) = try startKeyboardDictationInNewNote()
        let dictate = notes.buttons["openDictate.dictate"]
        // Away while the app records, then back into the same note.
        XCUIDevice.shared.press(.home)
        sleep(2)
        notes.activate()
        if !dictate.waitForExistence(timeout: 5) { body.tap() }
        try switchToOpenDictate(in: notes)
        XCTAssertTrue(waitUntil(dictate, labelContains: "Fertig"), "The keyboard shown anew does not show “Fertig”")
        sleep(4)
        dictate.tap()
        // iOS may name the note anew after the return: then the text waits
        // for one tap on "Diktat einsetzen" instead of going in by itself.
        let offer = notes.buttons["openDictate.offer"]
        var result = XCTWaiter().wait(for: [arrival(of: keywords, in: body)], timeout: 30)
        if result != .completed, offer.waitForExistence(timeout: 60) {
            snapshot("Notiz, Diktat angeboten", of: notes)
            offer.tap()
            result = XCTWaiter().wait(for: [arrival(of: keywords, in: body)], timeout: 10)
        }
        snapshot("Notiz nach der Rückkehr", of: notes)
        cleanUp(note: body, text: body.value as? String ?? "", in: notes)
        endWarmSession()
        XCTAssertTrue(result == .completed, "Text did not arrive in the same note after the keyboard came back")
    }

    /// The review case: a dictation started in a note and stopped from the
    /// keyboard in another app's field never puts its text there.
    func testKeyboardDictationStoppedInAnotherAppStaysOutOfIt() throws {
        let keywords = try liveKeywords()
        try addKeyboard()
        let (notes, body) = try startKeyboardDictationInNewNote()
        settings.terminate()
        settings.launch()
        let search = settings.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        try switchToOpenDictate(in: settings)
        let other = settings.buttons["openDictate.dictate"]
        XCTAssertTrue(
            waitUntil(other, labelContains: "Fertig"), "The keyboard in Settings did not take the dictation over")
        sleep(4)
        other.tap()
        // Parakeet takes well under a second; a wrong insert would be in by then.
        sleep(15)
        let typed = (search.value as? String ?? "").lowercased()
        let offered = settings.buttons["openDictate.offer"].exists
        snapshot("Einstellungen nach dem Diktat", of: settings)
        settings.terminate()
        notes.activate()
        body.tap()
        cleanUp(note: body, text: body.value as? String ?? "", in: notes)
        endWarmSession()
        XCTAssertFalse(keywords.contains { typed.contains($0) }, "The text went into another app's field: “\(typed)”")
        XCTAssertTrue(offered, "The text was not offered for a deliberate tap")
    }

    /// Opens the Settings search with the OpenDictate keyboard, for typing tests.
    private func searchWithKeyboard() throws -> XCUIElement {
        try addKeyboard()
        settings.terminate()
        settings.launch()
        let search = settings.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        try switchToOpenDictate(in: settings)
        return search
    }

    /// Every point of the key area types a key: a tap in the gap under the top
    /// row just above "q", one between the screen's edge and "q", one right of
    /// "a" and one left of "s" type "q", "q", "a", "s".
    func testTapsInGapsAndAtTheEdgeTypeTheNearestKey() throws {
        let search = try searchWithKeyboard()
        let a = settings.buttons["openDictate.key.a"]
        let s = settings.buttons["openDictate.key.s"]
        let q = settings.buttons["openDictate.key.q"]
        XCTAssertTrue(a.waitForExistence(timeout: 5), "No letter keys")
        XCTAssertGreaterThan(s.frame.minX - a.frame.maxX, 2, "No gap between a and s")
        let origin = settings.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        for point in [
            CGPoint(x: q.frame.midX, y: q.frame.minY - 6),
            CGPoint(x: max(1, q.frame.minX / 2), y: q.frame.midY),
            CGPoint(x: a.frame.maxX + 1, y: a.frame.midY),
            CGPoint(x: s.frame.minX - 1, y: s.frame.midY)
        ] {
            origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        }
        snapshot("Lücken und Rand", of: settings)
        let typed = (search.value as? String ?? "").lowercased()
        settings.terminate()
        XCTAssertEqual(typed, "qqas", "Taps in gaps and at the edge typed “\(typed)”")
    }

    /// Holding the space bar without sliding still types a space.
    func testHoldingSpaceWithoutSlidingTypesASpace() throws {
        let search = try searchWithKeyboard()
        settings.buttons["openDictate.key.a"].tap()
        settings.buttons["openDictate.space"].press(forDuration: 0.6)
        settings.buttons["openDictate.key.b"].tap()
        let typed = (search.value as? String ?? "").lowercased()
        settings.terminate()
        XCTAssertEqual(typed, "a b", "Holding space typed “\(typed)”")
    }

    /// Shift twice quickly locks capitals until shift is tapped again.
    func testShiftTwiceLocksCapitals() throws {
        let search = try searchWithKeyboard()
        let shift = settings.buttons["openDictate.shift"]
        // The search field may start a sentence: start from lower case.
        settings.buttons["openDictate.key.x"].tap()
        shift.doubleTap()
        for letter in "ab" { settings.buttons["openDictate.key.\(letter)"].tap() }
        shift.tap()
        settings.buttons["openDictate.key.c"].tap()
        let typed = search.value as? String ?? ""
        settings.terminate()
        XCTAssertTrue(typed.hasSuffix("ABc"), "Caps lock typed “\(typed)”")
    }

    /// Shift twice quickly locks capitals also where the keyboard starts with a
    /// capital (an empty field, a sentence start), as on Apple's keyboard.
    func testShiftTwiceLocksCapitalsAtTheStart() throws {
        let search = try searchWithKeyboard()
        let shift = settings.buttons["openDictate.shift"]
        XCTAssertTrue(shift.waitForExistence(timeout: 5), "No shift key")
        shift.doubleTap()
        for letter in "ab" { settings.buttons["openDictate.key.\(letter)"].tap() }
        shift.tap()
        settings.buttons["openDictate.key.c"].tap()
        let typed = search.value as? String ?? ""
        settings.terminate()
        XCTAssertEqual(typed, "ABc", "Caps lock at the start typed “\(typed)”")
    }

    /// Emoji page: a tap just above or below the category bar is nearer to the
    /// bar than to the bottom row, so it never types a space, deletes or starts
    /// a new line.
    func testTapsBesideTheEmojiCategoryBarTypeNothing() throws {
        let search = try searchWithKeyboard()
        for letter in "ab" { settings.buttons["openDictate.key.\(letter)"].tap() }
        settings.buttons["openDictate.emojiKey"].tap()
        let grid = settings.collectionViews["openDictate.emoji"]
        XCTAssertTrue(grid.waitForExistence(timeout: 3), "No emoji panel")
        let space = settings.buttons["openDictate.space"]
        // The category bar sits between the grid and the bottom row; take a button above the space bar.
        let category = settings.buttons.allElementsBoundByIndex.first {
            $0.frame.minY >= grid.frame.maxY && $0.frame.maxY <= space.frame.minY
                && $0.frame.midX > space.frame.minX && $0.frame.midX < space.frame.maxX
        }
        let bar = try XCTUnwrap(category, "No category button above the space bar")
        let before = search.value as? String ?? ""
        let origin = settings.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        for y in [bar.frame.minY - 1, bar.frame.maxY + 1] {
            origin.withOffset(CGVector(dx: bar.frame.midX, dy: y)).tap()
        }
        snapshot("Emoji, neben der Leiste", of: settings)
        let after = search.value as? String ?? ""
        settings.terminate()
        XCTAssertEqual(after, before, "Taps beside the category bar changed “\(before)” to “\(after)”")
    }

    // MARK: Helpers

    /// Warms the microphone in the app, then starts a keyboard dictation in a new note.
    private func startKeyboardDictationInNewNote() throws -> (notes: XCUIApplication, body: XCUIElement) {
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
        let dictate = notes.buttons["openDictate.dictate"]
        dictate.tap()
        XCTAssertTrue(waitUntil(dictate, labelContains: "Fertig"), "The key does not show “Fertig”")
        return (notes, body)
    }

    /// Waits on the key itself: Notes has a “Fertig” button of its own.
    private func waitUntil(_ element: XCUIElement, labelContains text: String) -> Bool {
        let shown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        return XCTWaiter().wait(for: [shown], timeout: 5) == .completed
    }

    private func arrival(of keywords: [String], in body: XCUIElement) -> XCTNSPredicateExpectation {
        let arrived = NSPredicate { object, _ in
            let text = ((object as? XCUIElement)?.value as? String ?? "").lowercased()
            return keywords.allSatisfy { text.contains($0) }
        }
        return XCTNSPredicateExpectation(predicate: arrived, object: body)
    }

    private func endWarmSession() {
        app.launch()
        app.swipeUp()
        if app.buttons["endWarm"].waitForExistence(timeout: 5) { app.buttons["endWarm"].tap() }
    }

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
        // iOS lists a freshly installed keyboard only after its app ran once.
        app.launch()
        // A search left open by an earlier test would hide the rows.
        settings.terminate()
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
        if !openDictateRow.waitForExistence(timeout: 2) {
            tap(addKeyboardRow, scrollingIn: settings)
            tap(openDictateRow, scrollingIn: settings)
        }
        snapshot("Einstellungen, Tastaturen", of: settings)
        tap(openDictateRow, scrollingIn: settings)
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

    /// By the extension's bundle ID: a search by name can match a cell iOS cannot tap.
    private var openDictateRow: XCUIElement {
        let cell = settings.cells["app.opendictate.ios.keyboard"]
        return cell.exists ? cell : row("OpenDictate")
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
        for attempt in 0..<8 where !(element.waitForExistence(timeout: 1) && onScreen(element, in: host)) {
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

    /// Like `isHittable`, which fails the test outright for a cell iOS is still moving.
    private func onScreen(_ element: XCUIElement, in host: XCUIApplication) -> Bool {
        let frame = element.frame
        return !frame.isEmpty && host.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
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
