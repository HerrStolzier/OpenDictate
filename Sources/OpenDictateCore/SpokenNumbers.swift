import Foundation

/// Writes German times and larger numbers that a recognition spelled out as
/// digits: "zehn Uhr dreißig" becomes "10:30 Uhr", "fünfundzwanzig" becomes
/// "25". As in usual German writing, the numbers up to twelve stay words
/// ("zwei Katzen") unless a time, "Prozent", "Euro" or "Cent" follows. Text in
/// other languages passes unchanged, because only German number words match.
public enum SpokenNumbers {
    public static func written(_ text: String) -> String {
        let tokens = text.components(separatedBy: " ")
        var result: [String] = []
        var index = 0
        while index < tokens.count {
            if let found = time(in: tokens, at: index) {
                result.append(found.text)
                index += found.used
                continue
            }
            let token = tokens[index]
            if let word = Word(token), !["hundert", "tausend"].contains(word.lowered),
                let number = value(word.lowered)
            {
                let next = index + 1 < tokens.count ? Word(tokens[index + 1]) : nil
                let unitFollows = next.map { $0.leading.isEmpty && units.contains($0.lowered) } ?? false
                // "von neun bis zehn Uhr": the start of a time span.
                let spanFollows =
                    number <= 24 && word.trailing.isEmpty && next?.isBare == true && next?.text == "bis"
                    && time(in: tokens, at: index + 2) != nil
                if number >= 13 || unitFollows || spanFollows {
                    result.append(word.leading + grouped(number) + word.trailing)
                    index += 1
                    continue
                }
            }
            result.append(token)
            index += 1
        }
        return result.joined(separator: " ")
    }

    /// "<hour> Uhr <minutes>" or "<hour> Uhr" at `index`, with the number of
    /// tokens it covers. A doubled "Uhr" after the minutes is taken along.
    private static func time(in tokens: [String], at index: Int) -> (text: String, used: Int)? {
        guard index + 1 < tokens.count, let hourWord = Word(tokens[index]), hourWord.trailing.isEmpty,
            let hour = number(hourWord.lowered), hour <= 24,
            let clock = Word(tokens[index + 1]), clock.leading.isEmpty, clock.text == "Uhr"
        else { return nil }
        if clock.trailing.isEmpty, index + 2 < tokens.count, let minuteWord = Word(tokens[index + 2]),
            minuteWord.leading.isEmpty, minuteWord.text.count <= 2 || minuteWord.text.contains(where: \.isLetter),
            let minutes = number(minuteWord.lowered), minutes <= 59
        {
            var trailing = minuteWord.trailing
            var used = 3
            if trailing.isEmpty, index + 3 < tokens.count, let again = Word(tokens[index + 3]),
                again.leading.isEmpty, again.text == "Uhr"
            {
                trailing = again.trailing
                used = 4
            }
            return ("\(hourWord.leading)\(hour):\(minutes < 10 ? "0" : "")\(minutes) Uhr\(trailing)", used)
        }
        return ("\(hourWord.leading)\(hour) Uhr\(clock.trailing)", 2)
    }

    /// German groups thousands from five digits on: 50.000, but 2026.
    private static func grouped(_ number: Int) -> String {
        guard number >= 10_000 else { return String(number) }
        return "\(grouped(number / 1000)).\(String(format: "%03d", number % 1000))"
    }

    /// Digits or a number word.
    private static func number(_ word: String) -> Int? {
        if word.allSatisfy(\.isASCII), word.allSatisfy(\.isNumber) { return Int(word) }
        return value(word)
    }

    private static let units: Set<String> = ["prozent", "euro", "cent"]

    private static let small: [String: Int] = [
        "null": 0, "ein": 1, "eins": 1, "zwei": 2, "drei": 3, "vier": 4, "fünf": 5, "sechs": 6, "sieben": 7,
        "acht": 8, "neun": 9, "zehn": 10, "elf": 11, "zwölf": 12, "dreizehn": 13, "vierzehn": 14,
        "fünfzehn": 15, "sechzehn": 16, "siebzehn": 17, "achtzehn": 18, "neunzehn": 19
    ]
    private static let tens: [String: Int] = [
        "zwanzig": 20, "dreißig": 30, "vierzig": 40, "fünfzig": 50, "sechzig": 60, "siebzig": 70,
        "achtzig": 80, "neunzig": 90, "dreissig": 30
    ]
    private static let digits: [String: Int] = [
        "ein": 1, "zwei": 2, "drei": 3, "vier": 4, "fünf": 5, "sechs": 6, "sieben": 7, "acht": 8, "neun": 9
    ]

    /// The value of a German number word below a million, such as
    /// "zweitausendsechsundzwanzig"; nil for any other word.
    static func value(_ word: String) -> Int? {
        if case (let left, let right)? = split(word, at: "tausend") {
            guard let thousands = left.isEmpty || left == "ein" ? 1 : belowThousand(left), thousands > 0 else {
                return nil
            }
            return rest(right, below: belowThousand).map { thousands * 1000 + $0 }
        }
        return belowThousand(word)
    }

    private static func belowThousand(_ word: String) -> Int? {
        if case (let left, let right)? = split(word, at: "hundert") {
            guard let hundreds = left.isEmpty ? 1 : digits[left] else { return nil }
            return rest(right, below: belowHundred).map { hundreds * 100 + $0 }
        }
        return belowHundred(word)
    }

    private static func belowHundred(_ word: String) -> Int? {
        if let number = small[word] ?? tens[word] { return number }
        guard case (let unit, let ten)? = split(word, at: "und"), let one = digits[unit],
            let tenValue = tens[ten]
        else { return nil }
        return one + tenValue
    }

    /// What follows "hundert" or "tausend": nothing, or a number above zero.
    private static func rest(_ word: String, below parse: (String) -> Int?) -> Int? {
        if word.isEmpty { return 0 }
        guard let number = parse(word), number > 0 else { return nil }
        return number
    }

    private static func split(_ word: String, at marker: String) -> (String, String)? {
        guard let range = word.range(of: marker) else { return nil }
        return (String(word[..<range.lowerBound]), String(word[range.upperBound...]))
    }

    /// A token split into punctuation before, the word, and punctuation after.
    private struct Word {
        let leading: String
        let text: String
        let trailing: String
        var lowered: String { text.lowercased() }
        var isBare: Bool { leading.isEmpty && trailing.isEmpty }

        init?(_ token: String) {
            guard let first = token.firstIndex(where: \.isWordCharacter),
                let last = token.lastIndex(where: \.isWordCharacter)
            else { return nil }
            let text = token[first...last]
            guard text.allSatisfy(\.isWordCharacter) else { return nil }
            leading = String(token[..<first])
            self.text = String(text)
            trailing = String(token[token.index(after: last)...])
        }
    }
}

extension Character {
    fileprivate var isWordCharacter: Bool { isLetter || isNumber }
}
