import UIKit

/// Suggestions and autocorrection for the word being typed (`Autocorrect`),
/// applied through the text document proxy. Space puts in a confident fix,
/// and deleting right after it puts back what was typed, as Apple's keyboard
/// does. Words the person keeps are learned in the keyboard's own settings;
/// they never leave the iPhone and need no Full Access.
@MainActor
final class TypingAssistant {
    private(set) var engine = Autocorrect()
    private(set) var current = Suggestions.none
    private var lastCorrection: (original: String, replacement: String)?
    /// Put back by a delete in this showing: not corrected again.
    private var keptInSession: Set<String> = []

    private static let learnedKey = "autocorrect.learned"
    private static let learnedLimit = 1000

    init() {
        engine.ownWords = Set(UserDefaults.standard.stringArray(forKey: Self.learnedKey) ?? [])
        if !UITextChecker.availableLanguages.contains(engine.language),
            let german = UITextChecker.availableLanguages.first(where: { $0.hasPrefix("de") })
        {
            engine.language = german
        }
    }

    /// Contacts' names and the text replacements from iOS Settings.
    func load(_ lexicon: UILexicon) {
        for entry in lexicon.entries {
            if entry.userInput == entry.documentText {
                engine.ownWords.insert(entry.documentText)
            } else {
                engine.shortcuts[entry.userInput] = entry.documentText
            }
        }
    }

    @discardableResult
    func refresh(_ proxy: UITextDocumentProxy) -> Suggestions {
        let word = Autocorrect.currentWord(before: proxy.documentContextBeforeInput)
        var suggestions = engine.suggestions(for: word)
        if keptInSession.contains(word) || !Self.correctsIn(proxy) { suggestions.replacesOnSpace = false }
        current = suggestions
        return suggestions
    }

    /// Space: a confident fix first, then the space.
    func space(_ proxy: UITextDocumentProxy) {
        let suggestions = refresh(proxy)
        lastCorrection = nil
        if suggestions.replacesOnSpace, let best = suggestions.best {
            replaceWord(suggestions.typed, with: best, in: proxy)
            lastCorrection = (suggestions.typed, best)
        }
        proxy.insertText(" ")
    }

    /// Delete: right after a fix, puts back what was typed instead.
    func deleteBackward(_ proxy: UITextDocumentProxy) {
        // Not over a selection: delete then removes the selection, as anywhere.
        if let correction = lastCorrection, proxy.selectedText?.isEmpty ?? true,
            proxy.documentContextBeforeInput?.hasSuffix(correction.replacement + " ") == true
        {
            for _ in 0..<(correction.replacement.count + 1) { proxy.deleteBackward() }
            proxy.insertText(correction.original)
            keptInSession.insert(correction.original)
        } else {
            proxy.deleteBackward()
        }
        lastCorrection = nil
    }

    /// A tap on a suggestion: that word and a space.
    func pick(_ word: String, in proxy: UITextDocumentProxy) {
        let typed = current.typed
        lastCorrection = nil
        if word != typed { replaceWord(typed, with: word, in: proxy) } else { learn(word) }
        proxy.insertText(" ")
    }

    /// Any other key: a fix can no longer be taken back with delete.
    func typedOther() { lastCorrection = nil }

    private func replaceWord(_ typed: String, with replacement: String, in proxy: UITextDocumentProxy) {
        for _ in 0..<typed.count { proxy.deleteBackward() }
        proxy.insertText(replacement)
    }

    private func learn(_ word: String) {
        keptInSession.insert(word)
        guard !engine.ownWords.contains(word) else { return }
        engine.ownWords.insert(word)
        var list = UserDefaults.standard.stringArray(forKey: Self.learnedKey) ?? []
        list.append(word)
        UserDefaults.standard.set(Array(list.suffix(Self.learnedLimit)), forKey: Self.learnedKey)
    }

    /// Fields that ask for no autocorrection, and addresses, get none.
    private static func correctsIn(_ proxy: UITextDocumentProxy) -> Bool {
        if proxy.autocorrectionType == .no { return false }
        switch proxy.keyboardType {
        case .URL, .emailAddress, .numberPad, .phonePad, .decimalPad: return false
        default: return true
        }
    }
}
