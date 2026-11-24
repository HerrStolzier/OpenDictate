import UIKit

// The keyboard's suggestions and replace-on-space autocorrection, German first.
// After Hex's AutocorrectEngine (github.com/anomalyco/hex, MIT, see
// ios/Keyboard/THIRD_PARTY_NOTICES.md): iOS's spelling dictionary
// (`UITextChecker`) and the person's own words (`UILexicon`), with the
// dictionary's guesses ranked by how near their letters sit on the keys, so a
// slip onto a neighbouring key counts less than a different letter, the idea of
// Gboard's spatial model in its simplest form.

/// The part of `UITextChecker` the keyboard uses, so tests can pass their own.
@MainActor
protocol SpellChecking {
    func isWord(_ word: String, language: String) -> Bool
    func guesses(for word: String, language: String) -> [String]
    func completions(for prefix: String, language: String) -> [String]
}

@MainActor
struct SystemSpellChecker: SpellChecking {
    private let checker = UITextChecker()

    func isWord(_ word: String, language: String) -> Bool {
        let range = NSRange(word.startIndex..., in: word)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: language)
            .location == NSNotFound
    }

    func guesses(for word: String, language: String) -> [String] {
        let range = NSRange(word.startIndex..., in: word)
        return checker.guesses(forWordRange: range, in: word, language: language) ?? []
    }

    func completions(for prefix: String, language: String) -> [String] {
        let range = NSRange(prefix.startIndex..., in: prefix)
        return checker.completions(forPartialWordRange: range, in: prefix, language: language) ?? []
    }
}

/// What the strip above the keys shows for the word being typed.
struct Suggestions: Equatable {
    /// The word as typed; tapping it keeps it and teaches the keyboard the word.
    var typed: String
    /// The middle slot; space puts it in when `replacesOnSpace`.
    var best: String?
    var second: String?
    var replacesOnSpace = false

    static let none = Suggestions(typed: "")
}

@MainActor
struct Autocorrect {
    var checker: any SpellChecking = SystemSpellChecker()
    var language = "de_DE"
    /// Text replacements from Settings › General › Keyboard, by what is typed.
    var shortcuts: [String: String] = [:]
    /// Contacts' names and words the person kept: never corrected.
    var ownWords: Set<String> = [] {
        // Contacts arrive one name at a time: only the next lookup rebuilds.
        didSet { ownIndex = OwnWordIndex() }
    }
    private var ownIndex = OwnWordIndex()

    /// The word being typed: the letters right before the cursor.
    static func currentWord(before text: String?) -> String {
        String((text ?? "").reversed().prefix { $0.isLetter || $0 == "-" }.reversed())
    }

    /// `slips`: per typed letter, the keys its tap was near enough to have
    /// meant (Tippen lernen); empty without a learned model.
    func suggestions(for word: String, slips: [Set<Character>] = []) -> Suggestions {
        guard word.count >= 1, word.contains(where: \.isLetter) else { return .none }
        if let expansion = shortcuts[word] ?? shortcuts[word.lowercased()] {
            return Suggestions(typed: word, best: expansion, replacesOnSpace: true)
        }
        let lowered = word.lowercased()
        let own = ownIndex.byLowercase(ownWords)[lowered]
        // A capital at a sentence start keeps a word known ("Ab" for "ab").
        let known =
            own != nil || checker.isWord(word, language: language)
            || (word != lowered && checker.isWord(lowered, language: language))
        if known {
            // Completions only; a known word is never replaced.
            // A capital mostly comes from a sentence start, and iOS answers a
            // capitalised prefix ("Ab") with nouns only or nothing, so the
            // lower-case one asks first ("ab" → "aber" → "Aber").
            var seen = Set<String>()
            let completions =
                (checker.completions(for: lowered, language: language)
                + checker.completions(for: word, language: language))
                .filter { $0.count > word.count }
                .map { Self.matchingCase($0, typed: word) }
                .filter { seen.insert($0).inserted }
            return Suggestions(typed: word, best: completions.first, second: completions.dropFirst().first)
        }
        // Own words (Contacts, kept words) one slip away come first, then the dictionary's.
        // Only words starting with the typed letter or a key around it are weighed.
        let initial = lowered.first ?? " "
        let initials = [initial] + Self.neighbours(of: initial) + (slips.first.map(Array.init) ?? [])
        let byInitial = ownIndex.byInitial(ownWords)
        let nearOwn = Set(initials.flatMap { byInitial[$0] ?? [] }).filter {
            abs($0.count - word.count) <= 1 && Self.cost(from: word, to: $0, slips: slips) <= 1
        }
        .sorted()
        var seen = Set<String>()
        // Matching the typed capital can make two guesses one ("leben", "Leben").
        let candidates = (nearOwn + checker.guesses(for: word, language: language))
            .map { Self.matchingCase($0, typed: word) }
            .filter { $0 != word && seen.insert($0).inserted }
        let costs: [Double] = candidates.map { Self.cost(from: word, to: $0, slips: slips) }
        // Equal costs keep the dictionary's order.
        let order: [Int] = candidates.indices.sorted { costs[$0] != costs[$1] ? costs[$0] < costs[$1] : $0 < $1 }
        guard let top = order.first else { return Suggestions(typed: word) }
        let first: (String, Double) = (candidates[top], costs[top])
        let runnerUp: (String, Double)? = order.count > 1 ? (candidates[order[1]], costs[order[1]]) : nil
        // Only a short distance replaces on its own; anything else waits for a tap.
        let clearlyBest = runnerUp.map { $0.1 - first.1 >= 0.25 } ?? true
        let confident = word.count >= 3 && first.1 <= 1.0 && (clearlyBest || first.1 <= 0.5)
        return Suggestions(
            typed: word, best: first.0, second: runnerUp?.0, replacesOnSpace: confident)
    }

    /// The dictionary's spelling, but a capital the person typed stays.
    static func matchingCase(_ candidate: String, typed: String) -> String {
        guard let first = typed.first, first.isUppercase, let head = candidate.first, head.isLowercase else {
            return candidate
        }
        return head.uppercased() + candidate.dropFirst()
    }

    // MARK: Distance

    /// Edit distance with swapped neighbours, where a letter typed on an
    /// adjacent key costs half and case and umlaut dots cost little.
    static func cost(from typed: String, to candidate: String, slips: [Set<Character>] = []) -> Double {
        let a = Array(typed.lowercased())
        let b = Array(candidate.lowercased())
        if a.isEmpty || b.isEmpty { return Double(max(a.count, b.count)) }
        var d = Array(repeating: Array(repeating: 0.0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = Double(i) }
        for j in 0...b.count { d[0][j] = Double(j) }
        for i in 1...a.count {
            for j in 1...b.count {
                // A letter whose tap landed near the candidate's key is an even likelier slip.
                let slip = i - 1 < slips.count && slips[i - 1].contains(b[j - 1])
                let plain = substitutionCost(a[i - 1], b[j - 1])
                let substitution = d[i - 1][j - 1] + (slip ? min(0.3, plain) : plain)
                var best = min(d[i - 1][j] + 1, d[i][j - 1] + 1, substitution)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    best = min(best, d[i - 2][j - 2] + 0.75)
                }
                d[i][j] = best
            }
        }
        return d[a.count][b.count]
    }

    static func substitutionCost(_ x: Character, _ y: Character) -> Double {
        if x == y { return 0 }
        if base(x) == base(y) { return 0.25 }
        return areNeighbours(x, y) ? 0.5 : 1
    }

    /// "ä" without its dots, so "Mädchen" typed as "Madchen" is a small slip.
    private static func base(_ c: Character) -> Character {
        switch c {
        case "ä": "a"
        case "ö": "o"
        case "ü": "u"
        case "ß": "s"
        default: c
        }
    }

    private static let rows: [[Character]] = [
        Array("qwertzuiopü"), Array("asdfghjklöä"), Array("yxcvbnmß")
    ]

    /// Where each row's first key sits, in keys, on this keyboard: the two
    /// top rows have eleven equal keys under each other; the third starts
    /// after the shift key.
    private static let rowStart: [Double] = [0, 0, 1.5]

    /// Keys next to each other on the keyboard's QWERTZ layout.
    static func areNeighbours(_ x: Character, _ y: Character) -> Bool {
        guard let (rx, cx) = position(x), let (ry, cy) = position(y) else { return false }
        let column = { (row: Int, index: Int) in Double(index) + rowStart[row] }
        return abs(rx - ry) <= 1 && abs(column(rx, cx) - column(ry, cy)) <= 1.0
    }

    /// Where `other`'s key centre sits from `key`'s, in key sizes.
    static func keyOffset(from key: Character, to other: Character) -> (x: Double, y: Double)? {
        guard let (r1, c1) = position(key), let (r2, c2) = position(other) else { return nil }
        return (Double(c2) + rowStart[r2] - Double(c1) - rowStart[r1], Double(r2 - r1))
    }

    /// The keys around `key`.
    static func neighbours(of key: Character) -> [Character] {
        rows.flatMap { $0 }.filter { $0 != key && areNeighbours(key, $0) }
    }

    private static func position(_ c: Character) -> (Int, Int)? {
        for (row, keys) in rows.enumerated() {
            if let index = keys.firstIndex(of: c) { return (row, index) }
        }
        return nil
    }
}

/// `Autocorrect.ownWords` by lower case and by first letter, so a key press
/// never walks the whole list (up to a thousand kept words plus Contacts).
/// Built on the first lookup after a change.
@MainActor
private final class OwnWordIndex {
    private var lowercase: [String: String]?
    private var initial: [Character: [String]]?

    func byLowercase(_ words: Set<String>) -> [String: String] {
        if let lowercase { return lowercase }
        let built = Dictionary(words.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        lowercase = built
        return built
    }

    func byInitial(_ words: Set<String>) -> [Character: [String]] {
        if let initial { return initial }
        let built = Dictionary(grouping: words) { $0.lowercased().first ?? " " }
        initial = built
        return built
    }
}
