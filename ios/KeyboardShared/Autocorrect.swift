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
    /// How common words are; empty in tests and until the keyboard read it.
    var frequency = WordFrequency()
    /// The word being typed: the letters right before the cursor.
    static func currentWord(before text: String?) -> String {
        String((text ?? "").reversed().prefix { $0.isLetter || $0 == "-" }.reversed())
    }

    /// The word before the one being typed, when only spaces lie between.
    static func previousWord(before text: String?) -> String? {
        var rest = Substring(text ?? "")
        rest = rest.dropLast(currentWord(before: text).count)
        guard rest.last == " " else { return nil }
        while rest.last == " " { rest = rest.dropLast() }
        let word = String(rest.reversed().prefix { $0.isLetter || $0 == "-" }.reversed())
        return word.isEmpty ? nil : word
    }

    /// `slips`: per typed letter, the keys its tap was near enough to have
    /// meant (Tippen lernen); empty without a learned model. `previous`: the
    /// word before, for the word list's pairs.
    func suggestions(for word: String, slips: [Set<Character>] = [], previous: String? = nil) -> Suggestions {
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
            // A short word iOS knows but that is not among the list's 50,000
            // ("isr", "sega") is likelier a slip: the common words near it are
            // offered, and space puts one in only when the word before backs it
            // ("das isr" → "ist"). A listed word ("helfe", "warst") stays.
            if own == nil, !frequency.isEmpty, word.count <= 5, frequency.count(word) == 0 {
                var near = ranked(word, slips: slips, previous: previous)
                if let best = near.best {
                    let backed = previous.map { frequency.count(best, after: $0) > 0 } ?? false
                    near.replacesOnSpace = near.replacesOnSpace && backed
                    return near
                }
            }
            // Otherwise completions only; a known word is never replaced.
            // A capital mostly comes from a sentence start, and iOS answers a
            // capitalised prefix ("Ab") with nouns only or nothing, so the
            // lower-case one asks first ("ab" → "aber" → "Aber").
            // Without word frequencies the shorter completions are the likelier
            // ones ("ich" does not offer "Icherzählerin"), within each list,
            // so short nouns for "Ab" ("Abo") do not push out "Aber".
            let shortest = { (list: [String]) in
                // A clipped form ("ich's") is no completion.
                let fitting = list.filter {
                    $0.count > word.count && $0.count <= word.count + 5 && !$0.contains("'") && !$0.contains("’")
                }
                // Stable: equal lengths keep the dictionary's order.
                return fitting.indices.sorted { (fitting[$0].count, $0) < (fitting[$1].count, $1) }.map { fitting[$0] }
            }
            let found = shortest(checker.completions(for: lowered, language: language))
                + shortest(checker.completions(for: word, language: language))
            let distinct = Self.oneCase(found.map { Self.matchingCase($0, typed: word) }, typed: word)
            // With the word list the commoner completion comes first ("nichts" before "Nichte").
            let completions =
                frequency.isEmpty
                ? distinct
                : distinct.indices.sorted {
                    (-frequency.count(distinct[$0]), $0) < (-frequency.count(distinct[$1]), $1)
                }.map { distinct[$0] }
            return Suggestions(typed: word, best: completions.first, second: completions.dropFirst().first)
        }
        return ranked(word, slips: slips, previous: previous)
    }

    /// The guesses for a word that may be a slip, nearest first; with the
    /// word list the commoner and the one that fits the word before win.
    private func ranked(_ word: String, slips: [Set<Character>], previous: String?) -> Suggestions {
        let lowered = word.lowercased()
        // Own words (Contacts, kept words) one slip away come first, then the dictionary's.
        // Only words whose first or second letter is the typed one, or a key
        // around it, are weighed.
        let initial = lowered.first ?? " "
        let initials = [initial] + Self.neighbours(of: initial) + (slips.first.map(Array.init) ?? [])
        let byInitial = ownIndex.byInitial(ownWords)
        // The index folds umlauts, so "Unal" still finds "Ünal".
        let nearOwn = Set(initials.flatMap { byInitial[Self.base($0)] ?? [] }).filter {
            abs($0.count - word.count) <= 1 && Self.cost(from: word, to: $0, slips: slips) <= 1
        }
        .sorted()
        // Matching the typed capital can make two guesses one ("leben", "Leben");
        // "nicht" and "Nicht" for "nciht" are one guess too, so neither blocks space.
        let found = nearOwn + checker.guesses(for: word, language: language) + frequency.nearby(word)
        let guessed = Self.oneCase(
            found.map { Self.matchingCase($0, typed: word) }, typed: word, keeping: Set(nearOwn)
        )
        .filter { $0 != word }
        // A guess many letters away is noise ("Aufbuk" for "Abfuck"): the strip keeps the typed word.
        let farthest = max(1.5, Double(word.count) / 3)
        var candidates = guessed.filter { Self.cost(from: word, to: $0, slips: slips) <= farthest }
        var costs: [Double] = candidates.map { Self.cost(from: word, to: $0, slips: slips) }
        if let spaced = spaced(word) {
            // A lost space ("undwas"), also when iOS guessed the split itself.
            // A capital may be a noun compound iOS does not know, so may a
            // long word ("rausgefunden"), and a two-letter part is often just a
            // slip ("dien" is not "di en"): those are offered, not put in.
            let index = candidates.firstIndex { $0.lowercased() == spaced.text.lowercased() }
            if let index {
                candidates.remove(at: index)
                costs.remove(at: index)
            }
            candidates.append(spaced.text)
            let short = word.count <= 9 && spaced.shortest >= 3
            costs.append(word.first?.isLowercase == true && short ? 0.5 : 1.25)
        }
        let own = Set(nearOwn)
        let scores = candidates.indices.map { score(candidates[$0], cost: costs[$0], own: own, previous: previous) }
        // Equal scores keep the dictionary's order.
        let order: [Int] = candidates.indices.sorted { scores[$0] != scores[$1] ? scores[$0] < scores[$1] : $0 < $1 }
        guard let top = order.first else { return Suggestions(typed: word) }
        let runnerUp = order.count > 1 ? order[1] : nil
        // Only a short distance replaces on its own; anything else waits for a tap.
        let clearlyBest = runnerUp.map { scores[$0] - scores[top] >= 0.25 } ?? true
        let confident = word.count >= 3 && costs[top] <= 1.0 && (clearlyBest || costs[top] <= 0.5)
        return Suggestions(
            typed: word, best: candidates[top], second: runnerUp.map { candidates[$0] }, replacesOnSpace: confident)
    }

    /// A guess's distance, less for a common word and for one that often
    /// follows the word before; a word outside the list's 50,000 counts as
    /// one more slip ("Sega" behind "mega"). Own words keep their distance.
    private func score(_ candidate: String, cost: Double, own: Set<String>, previous: String?) -> Double {
        guard !frequency.isEmpty, !own.contains(where: { $0.lowercased() == candidate.lowercased() }) else {
            return cost
        }
        let parts = candidate.split(separator: " ").map(String.init)
        if parts.count == 2 {
            // A split ("und was") the list holds as a pair counts as common as
            // its rarer word, and more so the more often the pair stands; one
            // it never holds ("die der" for "dieder") gets nothing.
            let pair = frequency.count(parts[1], after: parts[0])
            guard pair > 0 else { return cost }
            let rarer = min(frequency.count(parts[0]), frequency.count(parts[1]))
            return cost - 0.25 * log10(1 + Double(rarer)) - 0.25 * log10(1 + Double(pair))
        }
        let count = frequency.count(candidate)
        var score = cost - 0.25 * log10(1 + Double(count)) + (count == 0 ? 1 : 0)
        if let previous { score -= 0.25 * log10(1 + Double(frequency.count(candidate, after: previous))) }
        return score
    }

    /// Two known words a lost space glued together ("undwas" → "und was"),
    /// each at least two letters; of several splits the most even one.
    private func spaced(_ word: String) -> (text: String, shortest: Int)? {
        guard word.count >= 4, !word.contains("-") else { return nil }
        let letters = Array(word)
        let own = ownIndex.byLowercase(ownWords)
        // Each string is asked once: this runs at every key of an unknown word.
        let known = { (part: String) in
            let lowered = part.lowercased()
            return own[lowered] != nil || checker.isWord(part, language: language)
                || (part != lowered && checker.isWord(lowered, language: language))
        }
        let cuts = (2...(letters.count - 2)).sorted { abs(2 * $0 - letters.count) < abs(2 * $1 - letters.count) }
        for cut in cuts {
            let left = String(letters[..<cut])
            let right = String(letters[cut...])
            if known(left), known(right) { return (left + " " + right, min(left.count, right.count)) }
        }
        return nil
    }

    /// One entry per word whatever its case, in the place it first came;
    /// of "Nicht" and "nicht" the one cased like the typed word stays, but an
    /// own word in `keeping` keeps its case (the contact "Ernst" for "ernsr").
    static func oneCase(_ words: [String], typed: String, keeping: Set<String> = []) -> [String] {
        let typedLower = typed.first?.isLowercase == true
        var chosen: [String: String] = [:]
        var order: [String] = []
        for word in words {
            let key = word.lowercased()
            guard let current = chosen[key] else {
                chosen[key] = word
                order.append(key)
                continue
            }
            if !keeping.contains(current), current.first?.isLowercase != typedLower,
                word.first?.isLowercase == typedLower
            {
                chosen[key] = word
            }
        }
        return order.compactMap { chosen[$0] }
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
    fileprivate static func base(_ c: Character) -> Character {
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

/// `Autocorrect.ownWords` by lower case and by first and second letter (umlauts folded), so a key press
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
        // Under its first and its second letter, so a swapped or missing first
        // letter ("aMx", "asti") still finds the word ("Max", "Basti").
        var built: [Character: [String]] = [:]
        for word in words {
            let letters = Array(word.lowercased().prefix(2))
            for letter in Set(letters.map(Autocorrect.base)) { built[letter, default: []].append(word) }
        }
        initial = built
        return built
    }
}
