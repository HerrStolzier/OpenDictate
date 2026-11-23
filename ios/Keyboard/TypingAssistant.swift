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

    /// Tippen lernen: on only when the person turned it on in the app, and
    /// only with Full Access, which the App Group needs.
    private(set) var model: TypingModel?
    private let bridge = KeyboardBridge()
    /// The last tap, kept only once the next key is not delete.
    private var pendingTap: (key: String, x: Double, y: Double)?
    /// The taps behind the letters of the word being typed.
    private var wordTaps: [(key: Character, x: Double, y: Double)] = []
    private var unsaved = 0
    /// "Gelerntes löschen" in the app since the model was read.
    private var resetsAtLoad = 0

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

    /// Reads the switch and the learned model each time the keyboard shows.
    func loadModel(hasFullAccess: Bool) {
        model = hasFullAccess && bridge.learnsTyping ? bridge.typingModel : nil
        resetsAtLoad = bridge.typingResets
        pendingTap = nil
        unsaved = 0
    }

    /// Saves what was learned; also when the keyboard hides.
    func saveModel() {
        guard model != nil else { return }
        // Turned off or deleted in the app while the keyboard was open:
        // what it holds is dropped, never written back.
        guard bridge.learnsTyping, bridge.typingResets == resetsAtLoad else {
            model = nil
            pendingTap = nil
            return
        }
        guard unsaved > 0, let model else { return }
        bridge.typingModel = model
        unsaved = 0
    }

    /// A tap on a letter key at `x`/`y` from its centre, in key sizes.
    func tapped(key: String, x: Double, y: Double) {
        guard model != nil else { return }
        commitPendingTap()
        pendingTap = (key, x, y)
        if let letter = key.lowercased().first, key.count == 1, letter.isLetter {
            wordTaps.append((letter, x, y))
        }
    }

    private func commitPendingTap() {
        guard let tap = pendingTap else { return }
        pendingTap = nil
        model?.record(key: tap.key, x: tap.x, y: tap.y)
        unsaved += 1
        if unsaved >= 20 { saveModel() }
    }

    /// A key that is neither a letter nor delete keeps the last letter's tap.
    func keptLastTap() {
        guard model != nil else { return }
        commitPendingTap()
    }

    /// The keys each letter's tap was near enough to have meant.
    private func slips(for word: String) -> [Set<Character>] {
        guard let model, wordTaps.count == word.count else { return [] }
        return wordTaps.map { tap in
            Set(
                Autocorrect.neighbours(of: tap.key).filter { other in
                    guard model.shift(for: String(other)) != nil,
                        let offset = Autocorrect.keyOffset(from: tap.key, to: other)
                    else { return false }
                    let towardsOther = model.distance(fromKey: String(other), x: tap.x - offset.x, y: tap.y - offset.y)
                    return towardsOther < model.distance(fromKey: String(tap.key), x: tap.x, y: tap.y) + 0.5
                })
        }
    }

    @discardableResult
    func refresh(_ proxy: UITextDocumentProxy) -> Suggestions {
        let word = Autocorrect.currentWord(before: proxy.documentContextBeforeInput)
        if word.isEmpty { wordTaps = [] }
        var suggestions = engine.suggestions(for: word, slips: slips(for: word))
        if keptInSession.contains(word) || !Self.correctsIn(proxy) { suggestions.replacesOnSpace = false }
        current = suggestions
        return suggestions
    }

    /// Space: a confident fix first, then the space.
    func space(_ proxy: UITextDocumentProxy) {
        keptLastTap()
        let suggestions = refresh(proxy)
        lastCorrection = nil
        if suggestions.replacesOnSpace, let best = suggestions.best {
            replaceWord(suggestions.typed, with: best, in: proxy)
            lastCorrection = (suggestions.typed, best)
        }
        proxy.insertText(" ")
    }

    /// Delete: right after a fix, puts back what was typed instead. The tap
    /// it takes back is not learned.
    func deleteBackward(_ proxy: UITextDocumentProxy) {
        pendingTap = nil
        if !wordTaps.isEmpty { wordTaps.removeLast() }
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
