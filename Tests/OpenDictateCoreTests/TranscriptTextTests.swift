import Testing

@testable import OpenDictateCore

@Suite("Transcript text")
struct TranscriptTextTests {
    @Test func controlCharactersAndDirectionMarksAreDropped() {
        #expect(TranscriptText.sanitize(" a\u{1B}b\u{07}c\u{00}\u{85}d\u{202E}e\u{200F}\u{2066} ") == "abcde")
        #expect(TranscriptText.sanitize("\u{1B}[31mrot\u{1B}[0m") == "[31mrot[0m")
    }

    @Test func lineBreaksTabsAndEmojiStay() {
        #expect(TranscriptText.sanitize("eins\r\nzwei\rdrei\tvier\n") == "eins\nzwei\ndrei\tvier")
        #expect(TranscriptText.sanitize("Grüße 🧪 👨‍👩‍👧") == "Grüße 🧪 👨‍👩‍👧")
        #expect(TranscriptText.isMultiline("a\nb"))
        #expect(TranscriptText.isMultiline("a\u{2028}b"))
        #expect(TranscriptText.isMultiline(TranscriptText.sanitize("a\r\nb")))
        #expect(!TranscriptText.isMultiline("a b"))
    }

    @Test("Unicode line and paragraph separators become line breaks and stay on the clipboard")
    func unicodeSeparatorsBecomeLineBreaks() {
        #expect(TranscriptText.sanitize("ls\u{2028}rm -rf x\u{2029}ende") == "ls\nrm -rf x\nende")
        #expect(TranscriptText.sanitize("\u{2029}eins\u{2028}") == "eins")
        let pasted = TranscriptText.sanitize("ls\u{2028}rm -rf x")
        #expect(TranscriptText.isMultiline(pasted))
        #expect(!AutoPastePolicy.allowsPaste(of: pasted))
    }

    @Test("Segment line breaks from a local server become spaces; tabs and emoji stay")
    func segmentBreaksBecomeSpaces() {
        let whisper = " Das habe ich alles mit dem lokalen Modell?\n Diktiert.\n Das ist ja der Oberhammer.\n"
        #expect(
            TranscriptText.joiningSegments(TranscriptText.sanitize(whisper))
                == "Das habe ich alles mit dem lokalen Modell? Diktiert. Das ist ja der Oberhammer.")
        #expect(TranscriptText.joiningSegments("eins\r\n\n  zwei") == "eins zwei")
        #expect(TranscriptText.joiningSegments("a\tb  c 🧪") == "a\tb  c 🧪")
    }

    @Test func multilineTextStaysInTheClipboardForEveryTarget() {
        #expect(!AutoPastePolicy.allowsPaste(of: "ls\nrm -rf x"))
        #expect(!AutoPastePolicy.allowsPaste(of: "a\nb"))
        #expect(AutoPastePolicy.allowsPaste(of: "one line"))
    }
}
