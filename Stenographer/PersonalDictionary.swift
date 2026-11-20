import Foundation

/// The user's own words ("Kris", "Quarterdeck"), with the wrong forms that the speech model
/// writes for them ("Chris").
enum PersonalDictionary {
    struct Entry: Codable, Identifiable, Equatable {
        var id = UUID()
        var word = ""
        /// The wrong forms, with commas between them, as the user types them.
        var heardAs = ""
    }

    private static let defaultsKey = "personalDictionary"
    /// The clean-up model has a small context, so it gets only the first words.
    private static let maximumTermsLength = 500

    static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    static func save(_ entries: [Entry]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: defaultsKey)
    }

    /// Replaces each "heard as" form with its word. Also corrects the word itself when it is
    /// split, hyphenated or has wrong capitals: "quarter deck" → "Quarterdeck".
    /// Only whole words match, so "Christmas" stays when "Chris" is a wrong form.
    nonisolated static func applying(_ entries: [Entry], to text: String) -> String {
        var replacements: [(pattern: String, word: String)] = []
        for entry in entries {
            let word = trimmed(entry.word)
            guard !word.isEmpty else { continue }
            replacements.append((splitPattern(word), word))
            for form in entry.heardAs.split(separator: ",").map({ trimmed(String($0)) }) where !form.isEmpty {
                replacements.append((phrasePattern(form), word))
            }
        }
        // The longest first, so "Chris Smith" is found before "Chris".
        replacements.sort { $0.pattern.count > $1.pattern.count }

        guard !replacements.isEmpty else { return text }

        // One regex with a group for each form, and one pass through the text. Thus a replaced
        // word is not replaced again: "Chris Evans" in the dictionary stays, although "Chris" is
        // a wrong form of "Kris".
        // NSRegularExpression, because a Swift Regex made from a string has no lookbehind.
        let alternatives = replacements.map { "(\($0.pattern))" }.joined(separator: "|")
        let wordCharacter = "[\\p{L}\\p{M}\\p{N}]"
        guard let regex = try? NSRegularExpression(
            pattern: "(?<!\(wordCharacter))(?:\(alternatives))(?!\(wordCharacter))",
            options: .caseInsensitive
        ) else { return text }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        // From the end, so that the ranges of the earlier matches stay correct.
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let index = replacements.indices.first(where: { match.range(at: $0 + 1).location != NSNotFound })
            else { continue }
            result.replaceSubrange(range, with: replacements[index].word)
        }
        return result
    }

    /// The words for the clean-up model: "Kris, Quarterdeck". Nil if there are none.
    nonisolated static func terms(_ entries: [Entry]) -> String? {
        var terms = ""
        for word in entries.map({ trimmed($0.word) }) where !word.isEmpty {
            let longer = terms.isEmpty ? word : "\(terms), \(word)"
            guard longer.count <= maximumTermsLength else { break }
            terms = longer
        }
        return terms.isEmpty ? nil : terms
    }

    private nonisolated static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The words of the phrase, with any white space between them.
    private nonisolated static func phrasePattern(_ phrase: String) -> String {
        phrase.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+")
    }

    /// The characters of the word, with an optional space or hyphen between them. The space must
    /// have two or more characters on each side: "Ian" must not match "I an".
    private nonisolated static func splitPattern(_ word: String) -> String {
        let characters = word.filter { $0 != " " && $0 != "-" }.map { NSRegularExpression.escapedPattern(for: String($0)) }
        var pattern = ""
        for (index, character) in characters.enumerated() {
            if index >= 2, characters.count - index >= 2 { pattern += "[ -]?" }
            pattern += character
        }
        return pattern
    }
}
