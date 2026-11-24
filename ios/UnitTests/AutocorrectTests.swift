import UIKit
import XCTest

@testable import OpenDictateiOS

/// The keyboard's suggestions: a slip onto a neighbouring key is fixed on
/// space, known and own words are never replaced, and text replacements apply.
@MainActor
final class AutocorrectTests: XCTestCase {
    private struct FakeChecker: SpellChecking {
        var words: Set<String> = []
        var guesses: [String: [String]] = [:]
        var completions: [String: [String]] = [:]

        func isWord(_ word: String, language: String) -> Bool { words.contains(word) }
        func guesses(for word: String, language: String) -> [String] { guesses[word] ?? [] }
        func completions(for prefix: String, language: String) -> [String] { completions[prefix] ?? [] }
    }

    private func engine(_ checker: FakeChecker) -> Autocorrect {
        var engine = Autocorrect()
        engine.checker = checker
        return engine
    }

    func testASlipOntoANeighbouringKeyIsFixedOnSpace() {
        // "p" sits next to "o", not to "e".
        let checker = FakeChecker(guesses: ["Hallp": ["Halle", "Hallo"]])
        let suggestions = engine(checker).suggestions(for: "Hallp")
        XCTAssertEqual(suggestions.best, "Hallo")
        XCTAssertEqual(suggestions.second, "Halle")
        XCTAssertTrue(suggestions.replacesOnSpace)
    }

    func testAKnownWordIsNeverReplaced() {
        let checker = FakeChecker(words: ["Haus"], completions: ["Haus": ["Hause", "Haustür"]])
        let suggestions = engine(checker).suggestions(for: "Haus")
        XCTAssertFalse(suggestions.replacesOnSpace)
        XCTAssertEqual(suggestions.best, "Hause")
    }

    /// At a sentence start "Ab" offers "Aber" (Basti, 24 November), though
    /// iOS completes only the lower-case "ab".
    func testACapitalisedPrefixIsCompleted() {
        let checker = FakeChecker(words: ["Ab"], completions: ["ab": ["aber", "abend"]])
        let suggestions = engine(checker).suggestions(for: "Ab")
        XCTAssertEqual(suggestions.best, "Aber")
        XCTAssertEqual(suggestions.second, "Abend")
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// A word both lists hold ("Abend" for "Ab", "abend" for "ab") shows
    /// once, and "Aber" still gets a slot (Basti, 24 November).
    func testACompletionInBothListsShowsOnce() {
        let checker = FakeChecker(words: ["Ab"], completions: ["Ab": ["Abend"], "ab": ["abend", "aber"]])
        let suggestions = engine(checker).suggestions(for: "Ab")
        XCTAssertNotEqual(suggestions.best, suggestions.second, "The strip shows the same word twice")
        XCTAssertTrue([suggestions.best, suggestions.second].contains("Aber"))
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// "ab" is a word, so "Ab" at a sentence start is one too: completed,
    /// never "corrected".
    func testASentenceStartCapitalKeepsAWordKnown() {
        let checker = FakeChecker(words: ["ab"], guesses: ["Ab": ["An"]], completions: ["ab": ["aber"]])
        let suggestions = engine(checker).suggestions(for: "Ab")
        XCTAssertEqual(suggestions.best, "Aber")
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    func testOwnWordsStayAsTyped() {
        var autocorrect = engine(FakeChecker(guesses: ["Basti": ["Bast"]]))
        autocorrect.ownWords = ["Basti"]
        XCTAssertFalse(autocorrect.suggestions(for: "Basti").replacesOnSpace)
    }

    func testEqualGuessesKeepTheDictionarysOrder() {
        let checker = FakeChecker(guesses: ["Hsllo": ["Hello", "Hallo"]])
        XCTAssertEqual(engine(checker).suggestions(for: "Hsllo").best, "Hello")
    }

    func testAFarGuessWaitsForATap() {
        let checker = FakeChecker(guesses: ["xyz": ["Zoo"]])
        let suggestions = engine(checker).suggestions(for: "xyz")
        XCTAssertEqual(suggestions.best, "Zoo")
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    func testATextReplacementApplies() {
        var autocorrect = engine(FakeChecker())
        autocorrect.shortcuts = ["mfg": "Mit freundlichen Grüßen"]
        let suggestions = autocorrect.suggestions(for: "mfg")
        XCTAssertEqual(suggestions.best, "Mit freundlichen Grüßen")
        XCTAssertTrue(suggestions.replacesOnSpace)
    }

    func testATypedCapitalStays() {
        XCTAssertEqual(Autocorrect.matchingCase("morgen", typed: "Mprgen"), "Morgen")
        XCTAssertEqual(Autocorrect.matchingCase("Haus", typed: "hsus"), "Haus")
    }

    func testNeighboursCostLessThanOtherLetters() {
        XCTAssertLessThan(Autocorrect.cost(from: "hsllo", to: "hallo"), Autocorrect.cost(from: "hpllo", to: "hallo"))
        XCTAssertLessThan(Autocorrect.cost(from: "Madchen", to: "Mädchen"), 0.5)
        XCTAssertLessThan(Autocorrect.cost(from: "nihct", to: "nicht"), 1)
    }

    func testTheWordBeforeTheCursor() {
        XCTAssertEqual(Autocorrect.currentWord(before: "Ich bin mü"), "mü")
        XCTAssertEqual(Autocorrect.currentWord(before: "Ende. "), "")
        XCTAssertEqual(Autocorrect.currentWord(before: nil), "")
    }

    /// German keeps many words in both cases ("leben", "Leben"); at a
    /// sentence start both read "Leben" and must count as one guess.
    func testBothCasesOfOneGuessCountOnce() {
        let checker = FakeChecker(guesses: ["Lebne": ["leben", "Leben"]])
        let suggestions = engine(checker).suggestions(for: "Lebne")
        XCTAssertEqual(suggestions.best, "Leben")
        XCTAssertNotEqual(suggestions.second, "Leben", "The strip shows the same word twice")
        XCTAssertTrue(suggestions.replacesOnSpace, "A single swap with no rival is a safe fix")
    }

    /// README: suggestions include names from Contacts. "u" sits next to "i".
    func testANearOwnWordIsSuggested() {
        var autocorrect = engine(FakeChecker(guesses: ["Bastu": ["Bast"]]))
        autocorrect.ownWords = ["Basti"]
        let suggestions = autocorrect.suggestions(for: "Bastu")
        XCTAssertEqual(suggestions.best, "Basti")
    }

    /// A name from Contacts or a word kept at a sentence start ("Sebas"),
    /// typed later in lower case, is still the person's own word.
    func testAnOwnWordTypedInLowerCaseIsNotReplaced() {
        var autocorrect = engine(FakeChecker(guesses: ["sebas": ["Seba"]]))
        autocorrect.ownWords = ["Sebas"]
        let suggestions = autocorrect.suggestions(for: "sebas")
        XCTAssertFalse(
            suggestions.replacesOnSpace && suggestions.best != "Sebas",
            "Space would put in “\(suggestions.best ?? "")”")
    }

    /// The first two rows both have eleven equal keys, so "h" sits right
    /// under "z" and touches "t" just as it touches "u".
    func testNeighboursFollowTheKeyboardsAlignedRows() {
        XCTAssertEqual(Autocorrect.areNeighbours("h", "t"), Autocorrect.areNeighbours("h", "u"))
    }

    /// Tippen lernen: a tap on "o" that landed near "ö" makes "ö" likelier,
    /// never less likely than without the model ("konnen" → "können").
    func testALearnedSlipNeverRaisesTheCost() {
        let plain = Autocorrect.cost(from: "konnen", to: "können")
        let learned = Autocorrect.cost(from: "konnen", to: "können", slips: [[], ["ö"], [], [], [], []])
        XCTAssertLessThanOrEqual(learned, plain)
    }

    /// Tippen lernen: of two guesses one neighbour key away, the one the tap
    /// landed near wins ("s" tapped near "a": "Hallo", not "Hello").
    func testALearnedSlipPicksTheGuessTheTapPointsTo() {
        let checker = FakeChecker(guesses: ["Hsllo": ["Hello", "Hallo"]])
        let suggestions = engine(checker).suggestions(for: "Hsllo", slips: [[], ["a"], [], [], []])
        XCTAssertEqual(suggestions.best, "Hallo")
    }

    /// iOS's own German dictionary: "Ab" at a sentence start offers "Aber"
    /// (Basti, 24 November) and is never replaced. The keyboard asks once
    /// before the first key (`TypingAssistant`), so the test does too.
    func testGermanDictionaryCompletesACapitalisedPrefix() throws {
        guard let german = UITextChecker.availableLanguages.first(where: { $0.hasPrefix("de") }) else {
            throw XCTSkip("No German spelling dictionary here")
        }
        var autocorrect = Autocorrect()
        autocorrect.language = german
        _ = autocorrect.checker.completions(for: "ab", language: german)
        let suggestions = autocorrect.suggestions(for: "Ab")
        XCTAssertTrue(
            [suggestions.best, suggestions.second].contains("Aber"),
            "The strip shows \(suggestions.best ?? "-") and \(suggestions.second ?? "-")")
        XCTAssertNotEqual(suggestions.best, suggestions.second)
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// iOS's own German dictionary, where the simulator has one.
    func testGermanDictionaryFixesACommonSlip() throws {
        guard let german = UITextChecker.availableLanguages.first(where: { $0.hasPrefix("de") }) else {
            throw XCTSkip("No German spelling dictionary here")
        }
        var autocorrect = Autocorrect()
        autocorrect.language = german
        let suggestions = autocorrect.suggestions(for: "hsus")
        XCTAssertEqual(suggestions.best?.lowercased(), "haus")
        XCTAssertTrue(suggestions.replacesOnSpace)
        XCTAssertFalse(autocorrect.suggestions(for: "Haus").replacesOnSpace)
    }
}
