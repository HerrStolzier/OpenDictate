import Testing

@testable import OpenDictateCore

@Suite("API key dialog")
struct APIKeyEntryTests {
    @Test("The hint shows the prefix and the last four characters, never the key")
    func hintIsMasked() {
        let key = "sk-proj-" + String(repeating: "0", count: 16) + "WXYZ"
        let hint = APIKeyEntry.maskedHint(for: key)
        #expect(hint == "sk-…WXYZ")
        #expect(!hint.contains("proj"))
        #expect(APIKeyEntry.maskedHint(for: "custom-server-token") == "…oken")
    }

    @Test("A short key shows no characters of its own")
    func shortKeyShowsNothing() {
        #expect(APIKeyEntry.maskedHint(for: "sk-abc") == "sk-…")
        #expect(APIKeyEntry.maskedHint(for: "abcdefghijk") == "…")
    }

    @Test("An empty field keeps a stored key and never deletes it")
    func emptyFieldKeepsStoredKey() {
        #expect(APIKeyEntry.decision(for: "", hasStoredKey: true) == .keep)
        #expect(APIKeyEntry.decision(for: " \n\t", hasStoredKey: true) == .keep)
        #expect(APIKeyEntry.decision(for: "", hasStoredKey: false) == .empty)
    }

    @Test("Only a readable key has a hint; an unreadable one still counts as stored")
    func storedStates() {
        #expect(APIKeyEntry.Stored.readable(hint: "sk-…WXYZ").hint == "sk-…WXYZ")
        #expect(APIKeyEntry.Stored.unreadable.hint == nil)
        #expect(APIKeyEntry.Stored.missing.hint == nil)
        let unreadable = APIKeyEntry.Stored.unreadable
        #expect(APIKeyEntry.decision(for: "", hasStoredKey: unreadable != .missing) == .keep)
    }

    @Test("Entered text is trimmed and saved")
    func enteredKeyIsSaved() {
        #expect(APIKeyEntry.decision(for: "  sk-new\n", hasStoredKey: true) == .save("sk-new"))
        #expect(APIKeyEntry.decision(for: "sk-new", hasStoredKey: false) == .save("sk-new"))
    }
}
