import UIKit
import XCTest

@testable import OpenDictateiOS

/// The keyboard's suggestions: a slip onto a neighbouring key is fixed on
/// space, own words and words people write are never replaced, and text
/// replacements apply.
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

    /// A contact's name with its first two letters swapped or its first one
    /// missing is still suggested ("aMx" → "Max", "asti" → "Basti").
    func testAnOwnWordWithASlipOnTheFirstLetterIsSuggested() {
        var autocorrect = engine(FakeChecker())
        autocorrect.ownWords = ["Max", "Basti"]
        XCTAssertEqual(autocorrect.suggestions(for: "aMx").best, "Max")
        XCTAssertEqual(autocorrect.suggestions(for: "asti").best, "Basti")
    }

    /// A name starting with an umlaut, typed without it, is still found.
    func testAnOwnWordWithAnUmlautTypedWithoutItIsSuggested() {
        var autocorrect = engine(FakeChecker())
        autocorrect.ownWords = ["Ünal"]
        XCTAssertEqual(autocorrect.suggestions(for: "Unal").best, "Ünal")
    }

    func testEqualGuessesKeepTheDictionarysOrder() {
        let checker = FakeChecker(guesses: ["Hsllo": ["Hello", "Hallo"]])
        XCTAssertEqual(engine(checker).suggestions(for: "Hsllo").best, "Hello")
    }

    /// Two slips in five letters: offered, but only a tap puts it in.
    func testAFarGuessWaitsForATap() {
        let checker = FakeChecker(guesses: ["Kxnnw": ["Kanne"]])
        let suggestions = engine(checker).suggestions(for: "Kxnnw")
        XCTAssertEqual(suggestions.best, "Kanne")
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// A guess many letters away is not offered at all (Basti, 25 November:
    /// "Aufbuk" for "Abfuck"); the strip keeps only the typed word.
    func testAGuessManyLettersAwayIsNotOffered() {
        let checker = FakeChecker(guesses: ["Abfuck": ["Aufbuk"]])
        let suggestions = engine(checker).suggestions(for: "Abfuck")
        XCTAssertNil(suggestions.best)
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// A lost space between two known words is put back on space (Basti,
    /// 25 November: "undwas").
    func testTwoGluedWordsAreSplitOnSpace() {
        let checker = FakeChecker(words: ["und", "was", "un", "dwas"])
        let suggestions = engine(checker).suggestions(for: "undwas")
        XCTAssertEqual(suggestions.best, "und was")
        XCTAssertTrue(suggestions.replacesOnSpace)
    }

    /// iOS may guess the split itself ("und was"); it still counts as a lost
    /// space, so a rival guess as near does not keep it from space.
    func testAGluedPairIOSAlsoGuessesIsStillSplitOnSpace() {
        let checker = FakeChecker(words: ["und", "was"], guesses: ["undwas": ["und was", "und-was"]])
        let suggestions = engine(checker).suggestions(for: "undwas")
        XCTAssertEqual(suggestions.best, "und was")
        XCTAssertTrue(suggestions.replacesOnSpace)
    }

    /// A capitalised glued word iOS splits too stays only offered, and the
    /// strip does not show the split twice ("Haus Boot", "Haus boot").
    func testACapitalisedGluedWordIOSAlsoSplitsIsOnlyOffered() {
        let checker = FakeChecker(words: ["haus", "boot"], guesses: ["Hausboot": ["Haus Boot"]])
        let suggestions = engine(checker).suggestions(for: "Hausboot")
        XCTAssertFalse(suggestions.replacesOnSpace)
        XCTAssertNotEqual(
            suggestions.best?.lowercased(), suggestions.second?.lowercased(), "The strip shows the same split twice")
    }

    /// A long lower-case word may be a compound iOS does not know
    /// ("rausgefunden"): offered, but space keeps it.
    func testALongGluedWordIsOnlyOffered() {
        let checker = FakeChecker(words: ["raus", "gefunden"])
        let suggestions = engine(checker).suggestions(for: "rausgefunden")
        XCTAssertEqual(suggestions.best, "raus gefunden")
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    private final class CountingChecker: SpellChecking {
        var asked: [String] = []
        func isWord(_ word: String, language: String) -> Bool {
            asked.append(word)
            return false
        }
        func guesses(for word: String, language: String) -> [String] { [] }
        func completions(for prefix: String, language: String) -> [String] { [] }
    }

    /// Work per key (plan U5): the dictionary is asked about each string once,
    /// also when looking for a lost space.
    func testTheDictionaryIsAskedAboutEachStringOnce() {
        let checker = CountingChecker()
        var autocorrect = Autocorrect()
        autocorrect.checker = checker
        _ = autocorrect.suggestions(for: "abcdefghijkl")
        XCTAssertEqual(checker.asked.count, Set(checker.asked).count, "Asked twice: \(checker.asked)")
    }

    /// "nicht" and "Nicht" are one guess for "nciht", so space fixes it
    /// (Basti, 25 November), in the typed word's case.
    func testBothCasesOfAGuessDoNotBlockSpace() {
        let checker = FakeChecker(guesses: ["nciht": ["Nicht", "nicht"]])
        let suggestions = engine(checker).suggestions(for: "nciht")
        XCTAssertEqual(suggestions.best, "nicht")
        XCTAssertNotEqual(suggestions.second?.lowercased(), "nicht", "The strip shows the same word twice")
        XCTAssertTrue(suggestions.replacesOnSpace)
    }

    /// Without word frequencies short completions come first and very long
    /// ones not at all ("ich" offered "Icherzählerin", Basti, 25 November).
    func testShortCompletionsComeFirst() {
        let checker = FakeChecker(words: ["ich"], completions: ["ich": ["Icherzählerin", "ichbezog", "ichs"]])
        let suggestions = engine(checker).suggestions(for: "ich")
        XCTAssertEqual(suggestions.best, "ichs")
        XCTAssertEqual(suggestions.second, "ichbezog")
    }

    /// Completions more than five letters longer are not offered at all.
    func testVeryLongCompletionsAreLeftOut() {
        let checker = FakeChecker(words: ["ich"], completions: ["ich": ["Icherzählerin", "ichs"]])
        let suggestions = engine(checker).suggestions(for: "ich")
        XCTAssertEqual(suggestions.best, "ichs")
        XCTAssertNil(suggestions.second)
    }

    /// Short nouns iOS offers for a capitalised prefix ("Abo", "Abt") do not
    /// push the lower-case completion out of the strip (Basti, 24 November).
    func testShortNounsDoNotPushOutTheLowerCaseCompletion() {
        let checker = FakeChecker(words: ["ab"], completions: ["ab": ["aber", "abend"], "Ab": ["Abo", "Abt"]])
        let suggestions = engine(checker).suggestions(for: "Ab")
        XCTAssertTrue(
            [suggestions.best, suggestions.second].contains("Aber"),
            "The strip shows \(suggestions.best ?? "-") and \(suggestions.second ?? "-")")
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// A contact's name that is also a lower-case word keeps its capital
    /// ("Ernst" for "ernsr", though iOS guesses "ernst" too).
    func testAnOwnWordKeepsItsCaseAgainstALowerCaseGuess() {
        var autocorrect = engine(FakeChecker(guesses: ["ernsr": ["ernst"]]))
        autocorrect.ownWords = ["Ernst"]
        XCTAssertEqual(autocorrect.suggestions(for: "ernsr").best, "Ernst")
    }

    // MARK: Word list (Wortschatz Leipzig)

    private let list = WordFrequency(
        words: "ist\t146015\nnicht\t72930\nihr\t19741\nsea\t42\nmega\t27\nnichts\t2421\n"
            + "Haus\t2745\nhaus\t3\nselten\t5\n",
        pairs: "das ist\t3566\nund was\t1111\n")

    func testTheWordListCountsAllSpellingsAndKeepsTheCommonOne() {
        XCTAssertEqual(list.count("haus"), 2748)
        XCTAssertEqual(list.count("Ist"), 146015)
        XCTAssertEqual(list.count("Sega"), 0)
        XCTAssertEqual(list.count("ist", after: "Das"), 3566)
        XCTAssertEqual(list.count("ist", after: "es"), 0)
        XCTAssertEqual(list.nearby("hsus"), ["Haus"])
    }

    /// Near words are one letter away (changed, missing, extra, swapped) and
    /// not too rare to offer.
    func testNearWordsAreOneLetterAwayAndCommonEnough() {
        XCTAssertEqual(Set(list.nearby("isr")), ["ist", "ihr"])
        XCTAssertEqual(list.nearby("its"), ["ist"])
        XCTAssertEqual(Set(list.nearby("nichs")), ["nicht", "nichts"])
        XCTAssertEqual(list.nearby("Mehga"), ["mega"])
        XCTAssertEqual(list.nearby("seltem"), [], "Below \(WordFrequency.nearbyMinimum) a word is not offered")
        XCTAssertEqual(list.nearby("ist"), [], "The typed word itself is no near word")
    }

    func testThePreviousWord() {
        XCTAssertEqual(Autocorrect.previousWord(before: "Ja, das isr"), "das")
        XCTAssertEqual(Autocorrect.previousWord(before: "das  isr"), "das")
        XCTAssertNil(Autocorrect.previousWord(before: "Ende. isr"))
        XCTAssertNil(Autocorrect.previousWord(before: "isr"))
        XCTAssertNil(Autocorrect.previousWord(before: nil))
    }

    /// "Sega" is a guess no distance away, but outside the list's common
    /// words: common near words come first and space keeps "sega" (Basti,
    /// 25 November; "mega" itself is rarer in the list than "sea").
    func testARareGuessDoesNotBeatCommonNearWords() {
        var autocorrect = engine(FakeChecker(guesses: ["sega": ["Sega"]]))
        autocorrect.frequency = list
        let suggestions = autocorrect.suggestions(for: "sega")
        XCTAssertNotEqual(suggestions.best, "Sega")
        XCTAssertTrue([suggestions.best, suggestions.second].contains("mega"))
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// iOS knows "isr", but the list does not: "ist" is offered, and
    /// space puts it in only after a word that backs it ("das isr").
    func testARareKnownWordIsCorrectedWhenTheWordBeforeBacksIt() {
        var autocorrect = engine(FakeChecker(words: ["isr"]))
        autocorrect.frequency = list
        let alone = autocorrect.suggestions(for: "isr")
        XCTAssertEqual(alone.best, "ist")
        XCTAssertFalse(alone.replacesOnSpace)
        let afterDas = autocorrect.suggestions(for: "isr", previous: "das")
        XCTAssertEqual(afterDas.best, "ist")
        XCTAssertTrue(afterDas.replacesOnSpace)
    }

    /// A common known word stays as typed, with completions.
    func testACommonKnownWordIsNotCorrected() {
        var autocorrect = engine(FakeChecker(words: ["ihr"]))
        autocorrect.frequency = list
        let suggestions = autocorrect.suggestions(for: "ihr", previous: "das")
        XCTAssertNotEqual(suggestions.best, "ist")
        XCTAssertFalse(suggestions.replacesOnSpace)
    }

    /// With the list the commoner completion comes first ("nichts", not "Nichte").
    func testTheCommonerCompletionComesFirst() {
        var autocorrect = engine(FakeChecker(words: ["nicht"], completions: ["nicht": ["Nichte", "nichts"]]))
        autocorrect.frequency = list
        let suggestions = autocorrect.suggestions(for: "nicht")
        XCTAssertEqual(suggestions.best, "nichts")
        XCTAssertEqual(suggestions.second, "Nichte")
    }

    /// The keyboard's lists as checked in: the format reads and holds the common words.
    func testTheCheckedInListsHoldCommonWordsAndPairs() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Keyboard")
        let read = { (name: String) in
            try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
        }
        let checkedIn = WordFrequency(
            words: try read("wortschatz-de.txt"), pairs: try read("wortschatz-de-pairs.txt"))
        XCTAssertGreaterThan(checkedIn.count("und"), 1000)
        XCTAssertGreaterThan(checkedIn.count("ist", after: "das"), 1000)
    }

    /// Words the list holds are words people write: space keeps a correct
    /// "ich helfe", "du warst", "der Bär", "es half" (counts as in the list).
    func testAListedKnownWordIsNotReplacedOnSpace() {
        var autocorrect = engine(FakeChecker(words: ["helfe", "warst", "Bär", "half"]))
        autocorrect.frequency = WordFrequency(
            words: "helfe\t49\nHilfe\t4425\nhelfen\t4107\nwarst\t36\nwirst\t372\n"
                + "Bär\t46\nBar\t229\nhalf\t49\nHalt\t377\n",
            pairs: "ich Hilfe\t20\ndu warst\t14\ndu wirst\t91\nder Bar\t13\nes halt\t12\n")
        for (previous, word) in [("ich", "helfe"), ("du", "warst"), ("der", "Bär"), ("es", "half")] {
            let suggestions = autocorrect.suggestions(for: word, previous: previous)
            XCTAssertFalse(
                suggestions.replacesOnSpace,
                "Space turns “\(previous) \(word)” into “\(previous) \(suggestions.best ?? "")”")
        }
    }

    /// Two glued words are still split with the list ("ihrein" → "ihr ein"),
    /// not beaten by a common word farther away ("ihren").
    func testAGluedPairIsStillSplitWithTheWordList() {
        var autocorrect = engine(FakeChecker(words: ["ihr", "ein"]))
        autocorrect.frequency = WordFrequency(
            words: "ihr\t19741\nein\t101858\nihren\t14394\n", pairs: "ihr ein\t69\n")
        let suggestions = autocorrect.suggestions(for: "ihrein")
        XCTAssertEqual(suggestions.best, "ihr ein")
        XCTAssertTrue(suggestions.replacesOnSpace)
    }

    /// An own word keeps its distance whatever the typed capital ("Mpin" → "Moin").
    func testAnOwnWordKeepsItsDistanceAtASentenceStart() {
        var autocorrect = engine(FakeChecker())
        autocorrect.ownWords = ["moin"]
        autocorrect.frequency = WordFrequency(words: "mein\t20\n", pairs: "")
        XCTAssertEqual(autocorrect.suggestions(for: "mpin").best, "moin")
        XCTAssertEqual(autocorrect.suggestions(for: "Mpin").best, "Moin")
    }

    /// A neighbour slip in one word is not split into two words the list
    /// never holds together ("dieder" → "dieser", not "die der").
    func testASlipIsNotSplitIntoTwoCommonWords() {
        var autocorrect = engine(FakeChecker(words: ["die", "der"], guesses: ["dieder": ["dieser"]]))
        autocorrect.frequency = WordFrequency(words: "die\t537584\nder\t484356\ndieser\t19480\n", pairs: "")
        XCTAssertEqual(autocorrect.suggestions(for: "dieder").best, "dieser")
    }

    func testThePreviousWordKeepsItsHyphen() {
        XCTAssertEqual(Autocorrect.previousWord(before: "per E-Mail sn"), "E-Mail")
    }

    /// A two-letter part is often a slip ("dien" for "dein", not "di en"):
    /// offered, but space does not split.
    func testASplitWithATwoLetterPartIsOnlyOffered() {
        let checker = FakeChecker(words: ["di", "en"], guesses: ["dien": ["dein"]])
        let suggestions = engine(checker).suggestions(for: "dien")
        XCTAssertEqual(suggestions.best, "dein")
        XCTAssertEqual(suggestions.second, "di en")
    }

    /// A capitalised word may be a noun compound iOS does not know: the split
    /// is offered, but space keeps the word.
    func testACapitalisedGluedWordIsOnlyOffered() {
        let checker = FakeChecker(words: ["haus", "boot"])
        let suggestions = engine(checker).suggestions(for: "Hausboot")
        XCTAssertEqual(suggestions.best, "Haus boot")
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

    /// README: names from Contacts one slip away are suggested; the slip can
    /// be on the first letter too ("v" sits next to "b": "Vasti" → "Basti").
    func testANearOwnWordWithASlipOnTheFirstLetterIsSuggested() {
        var autocorrect = engine(FakeChecker(guesses: ["Vasti": ["Vase"]]))
        autocorrect.ownWords = ["Basti"]
        XCTAssertEqual(autocorrect.suggestions(for: "Vasti").best, "Basti")
    }

    /// `TypingAssistant.load` adds Contacts' names one at a time, on the main
    /// thread at every showing; a big address book must not hold up the first
    /// key. 5000: about 2000 contacts plus kept words.
    func testAddingManyOwnWordsOneByOneIsQuick() {
        var autocorrect = engine(FakeChecker())
        let start = Date()
        for index in 0..<5000 { autocorrect.ownWords.insert("Name\(index)") }
        let seconds = Date().timeIntervalSince(start)
        XCTAssertLessThan(seconds, 0.25, "Adding 5000 own words one by one took \(seconds) s")
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
