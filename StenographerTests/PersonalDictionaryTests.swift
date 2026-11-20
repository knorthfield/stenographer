import Testing
@testable import Stenographer

struct PersonalDictionaryTests {
    private static let entries = [
        PersonalDictionary.Entry(word: "Kris", heardAs: "Chris, Cris"),
        PersonalDictionary.Entry(word: "Quarterdeck"),
        PersonalDictionary.Entry(word: "Ian"),
        PersonalDictionary.Entry(word: "Kris Northfield", heardAs: "Chris North Field"),
        PersonalDictionary.Entry(word: "  "),
    ]

    @Test(arguments: [
        ("Many thanks, Chris.", "Many thanks, Kris."),
        ("many thanks chris", "many thanks Kris"),
        ("That is Cris's desk.", "That is Kris's desk."),
        ("I work at quarter deck now.", "I work at Quarterdeck now."),
        ("The quarter-deck course.", "The Quarterdeck course."),
        ("QUARTERDECK and quarterdeck", "Quarterdeck and Quarterdeck"),
        ("From Chris north field today.", "From Kris Northfield today."),
        // Only whole words
        ("Happy Christmas.", "Happy Christmas."),
        ("The quarter decks are wet.", "The quarter decks are wet."),
        // A short word is not put together from two words
        ("Am I an expert?", "Am I an expert?"),
        ("Nothing to change here.", "Nothing to change here."),
    ])
    func replacesTheWrongForms(text: String, expected: String) {
        #expect(PersonalDictionary.applying(Self.entries, to: text) == expected)
    }

    @Test func anEmptyDictionaryChangesNothing() {
        #expect(PersonalDictionary.applying([], to: "Many thanks, Chris.") == "Many thanks, Chris.")
    }

    @Test func aWordWithSymbolsIsNotARegex() {
        let entries = [PersonalDictionary.Entry(word: "C++", heardAs: "C plus plus")]
        #expect(PersonalDictionary.applying(entries, to: "I write c plus plus.") == "I write C++.")
    }

    @Test func aReplacedWordIsNotReplacedAgain() {
        let entries = [
            PersonalDictionary.Entry(word: "Kris", heardAs: "Chris"),
            PersonalDictionary.Entry(word: "Chris Evans"),
            PersonalDictionary.Entry(word: "Christopher", heardAs: "Kris Topher"),
        ]
        #expect(PersonalDictionary.applying(entries, to: "chris evans met Chris and Kris Topher.")
            == "Chris Evans met Kris and Christopher.")
    }

    @Test func aWordWithAnAmpersandStays() {
        let entries = [PersonalDictionary.Entry(word: "AT&T", heardAs: "AT and T")]
        #expect(PersonalDictionary.applying(entries, to: "I called at and t, then at&t.") == "I called AT&T, then AT&T.")
    }

    @Test func termsAreTheWords() {
        #expect(PersonalDictionary.terms(Self.entries) == "Kris, Quarterdeck, Ian, Kris Northfield")
        #expect(PersonalDictionary.terms([]) == nil)
        #expect(PersonalDictionary.terms([PersonalDictionary.Entry(word: " ")]) == nil)
    }

    @Test func termsStopAtTheLimit() {
        let entries = (0..<200).map { PersonalDictionary.Entry(word: "Word\($0)") }
        let terms = PersonalDictionary.terms(entries)
        #expect(terms?.count ?? 0 <= 500)
        #expect(terms?.hasPrefix("Word0, Word1, ") == true)
    }
}
