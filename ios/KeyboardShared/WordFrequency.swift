import Foundation

/// How common German words are, alone and after the word before, from
/// Wortschatz Leipzig (`ios/Keyboard/THIRD_PARTY_NOTICES.md`): iOS's
/// dictionary knows neither, so without it a rare word like "Sega" can beat
/// "mega". Empty until the keyboard has read its lists, and in the app.
struct WordFrequency: Sendable {
    /// By lower case, the counts of all spellings together.
    private var words: [String: Int] = [:]
    /// The most common spelling of each word ("Haus", "nicht").
    private var spellings: [String: String] = [:]
    /// "first second" in lower case.
    private var pairs: [String: Int] = [:]
    /// Words the list writes only with a capital ("Stunde"), by lower case.
    private var capitalOnly: Set<String> = []

    /// Words below this count are not offered as near words.
    static let nearbyMinimum = 20
    /// From this count a word the list writes only with a capital is a noun
    /// whatever is typed ("stunde" → "Stunde").
    static let nounMinimum = 100
    private static let letters = Array("abcdefghijklmnopqrstuvwxyzäöüß")

    init() {}

    /// `words`: one "word<TAB>count" per line; `pairs`: "first second<TAB>count".
    init(words: String, pairs: String) {
        var best: [String: Int] = [:]
        var writtenLower: Set<String> = []
        for (text, count) in Self.lines(words) {
            let key = text.lowercased()
            self.words[key, default: 0] += count
            if text.first?.isLowercase == true { writtenLower.insert(key) }
            // A word in capitals only wins when no other spelling is listed:
            // "gründet" (86) over "GRÜNDET" (93), but "SEA" stays "SEA".
            let replaces: Bool
            if let current = spellings[key], Self.isShouted(current) == Self.isShouted(text) {
                replaces = count > best[key, default: 0]
            } else {
                replaces = spellings[key].map(Self.isShouted) ?? true
            }
            if replaces {
                best[key] = count
                spellings[key] = text
            }
        }
        for (text, count) in Self.lines(pairs) { self.pairs[text.lowercased(), default: 0] += count }
        capitalOnly = Set(
            spellings.filter { key, spelling in
                spelling.first?.isUppercase == true && !Self.isShouted(spelling) && !writtenLower.contains(key)
            }.keys)
    }

    /// The lists bundled with the keyboard; empty where they are missing.
    /// Read once per process: iOS makes a new keyboard each time it shows.
    static let shared = bundled()

    static func bundled() -> WordFrequency {
        func read(_ name: String) -> String {
            guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return "" }
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        return WordFrequency(words: read("wortschatz-de"), pairs: read("wortschatz-de-pairs"))
    }

    var isEmpty: Bool { words.isEmpty }

    /// A word typed in lower case that the list writes only with a capital,
    /// and often: its spelling ("stunde" → "Stunde"); otherwise nil.
    func capitalised(_ word: String) -> String? {
        let key = word.lowercased()
        guard word == key, capitalOnly.contains(key), count(word) >= Self.nounMinimum else { return nil }
        return spellings[key]
    }

    func count(_ word: String) -> Int { words[word.lowercased()] ?? 0 }

    func count(_ word: String, after previous: String) -> Int {
        pairs[previous.lowercased() + " " + word.lowercased()] ?? 0
    }

    /// Common words one letter away from `word`: changed, missing, extra, or
    /// swapped with the next, in their usual spelling; abbreviations written
    /// in capitals ("SEA" for "sega") are left out.
    func nearby(_ word: String) -> [String] {
        let typed = Array(word.lowercased())
        var edits = Set<String>()
        for index in 0...typed.count {
            for letter in Self.letters {
                edits.insert(String(typed[..<index] + [letter] + typed[index...]))
            }
            guard index < typed.count else { continue }
            edits.insert(String(typed[..<index] + typed[(index + 1)...]))
            for letter in Self.letters where letter != typed[index] {
                edits.insert(String(typed[..<index] + [letter] + typed[(index + 1)...]))
            }
            if index + 1 < typed.count {
                edits.insert(String(typed[..<index] + [typed[index + 1], typed[index]] + typed[(index + 2)...]))
            }
        }
        edits.remove(String(typed))
        return edits.filter { (words[$0] ?? 0) >= Self.nearbyMinimum }.sorted().compactMap { spellings[$0] }
            .filter { !Self.isShouted($0) }
    }

    /// Written in capitals only, as abbreviations are ("SEA", "PDF").
    static func isShouted(_ text: String) -> Bool { text.count >= 2 && text == text.uppercased() }

    private static func lines(_ text: String) -> [(String, Int)] {
        text.split(separator: "\n").compactMap { line in
            guard let tab = line.lastIndex(of: "\t"), let count = Int(line[line.index(after: tab)...]) else {
                return nil
            }
            return (String(line[..<tab]), count)
        }
    }
}
