import Testing

@testable import OpenDictateCore

@Suite("Spoken numbers")
struct SpokenNumbersTests {
    @Test(arguments: [
        ("von zehn Uhr dreißig bis elf Uhr vierzig ein.", "von 10:30 Uhr bis 11:40 Uhr ein."),
        ("bis elf Uhr vierzig Uhr ein.", "bis 11:40 Uhr ein."),
        ("Treffen um acht Uhr.", "Treffen um 8 Uhr."),
        ("um ein Uhr", "um 1 Uhr"),
        ("um 10 Uhr fünfzehn", "um 10:15 Uhr"),
        ("um zwölf Uhr fünf", "um 12:05 Uhr"),
        ("von neun bis zehn Uhr", "von 9 bis 10 Uhr"),
        ("(zehn Uhr dreissig)", "(10:30 Uhr)"),
        ("zehn Uhr dreißig.", "10:30 Uhr."),
        ("um acht Uhr ein Meeting", "um 8 Uhr ein Meeting"),
        ("um zehn Uhr eins", "um 10:01 Uhr")
    ])
    func timesBecomeDigits(spoken: String, written: String) {
        #expect(SpokenNumbers.written(spoken) == written)
    }

    @Test(arguments: [
        ("zweihundertfünfzig Leute kamen", "250 Leute kamen"),
        ("Im Jahr zweitausendsechsundzwanzig", "Im Jahr 2026"),
        ("Zwanzig Minuten später", "20 Minuten später"),
        ("Das kostet fünfundzwanzig Euro.", "Das kostet 25 Euro."),
        ("Das kostet fünf Euro.", "Das kostet 5 Euro."),
        ("dreiundzwanzig Prozent", "23 Prozent"),
        ("fünfzigtausend Euro", "50.000 Euro"),
        ("zehn Uhr, dreißig Leute", "10 Uhr, 30 Leute")
    ])
    func largerNumbersAndAmountsBecomeDigits(spoken: String, written: String) {
        #expect(SpokenNumbers.written(spoken) == written)
    }

    @Test(arguments: [
        "Ich habe zwei Katzen und ein Haus.",
        "Tausend Dank, hundert Leute",
        "eine Uhr",
        "the elf said eleven",
        "um 10.30 Uhr",
        "Im Jahrhundert und Jahrtausend",
        "von neun bis zehn",
        ""
    ])
    func everythingElseStays(text: String) {
        #expect(SpokenNumbers.written(text) == text)
    }

    @Test func numberWords() {
        #expect(SpokenNumbers.value("neunundneunzig") == 99)
        #expect(SpokenNumbers.value("hunderteins") == 101)
        #expect(SpokenNumbers.value("eintausend") == 1000)
        #expect(SpokenNumbers.value("dreihundertzwölftausendvierhundert") == 312_400)
        #expect(SpokenNumbers.value("einhundertnull") == nil)
        #expect(SpokenNumbers.value("Hund") == nil)
        #expect(SpokenNumbers.value("undzwanzig") == nil)
    }
}
