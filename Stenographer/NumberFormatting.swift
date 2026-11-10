import FluidAudio
import Foundation

/// Writes spoken numbers, years and times with digits, in UK style: "twenty fifteen" → "2015",
/// "half one" → "1:30", "three pm" → "3pm". Numbers from zero to nine stay words, as in
/// "one question".
enum NumberFormatting {
    static func writtenNumbers(_ text: String) -> String {
        // FluidAudio's inverse text normalisation (NVIDIA NeMo rules) does most of the work, in
        // US style. Before it, add the UK "half one", which it does not know. After it, change
        // the US style.
        let normalized = TextNormalizer.shared.normalizeSentence(halfHours(separatedMeridiems(text)))
        return smallNumbersAsWords(ukTimes(normalized, inputEndsWithFullStop: text.hasSuffix(".")))
    }

    private static let hours = [
        "one", "two", "three", "four", "five", "six",
        "seven", "eight", "nine", "ten", "eleven", "twelve",
    ]

    /// Parakeet sometimes joins the hour and "am": "tenam" → "ten am".
    private static func separatedMeridiems(_ text: String) -> String {
        text.replacing(/\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)([ap]m)\b/
            .ignoresCase()) { "\($0.1) \($0.2)" }
    }

    /// "half one" → "1:30". "half past one" stays, because the normaliser knows it.
    private static func halfHours(_ text: String) -> String {
        text.replacing(/\bhalf (one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/
            .ignoresCase()) { match in
            "\(hours.firstIndex(of: match.1.lowercased())! + 1):30"
        }
    }

    /// "03:00 p.m." → "3pm", "03:30 P.M." → "3:30pm", "01:00" → "1:00".
    private static func ukTimes(_ text: String, inputEndsWithFullStop: Bool) -> String {
        let withoutLeadingZero = text.replacing(/\b0(\d):(\d\d)\b/) { "\($0.1):\($0.2)" }
        let meridiem = /\b(\d{1,2})(:\d\d)?\s?(?:([ap])\.m\.|([ap])m\b)/.ignoresCase()
        return withoutLeadingZero.replacing(meridiem) { match in
            let minutes = match.2 == ":00" ? "" : match.2 ?? ""
            let letter = (match.3 ?? match.4 ?? "").lowercased()
            // "p.m." at the end of the text was also the full stop of the sentence.
            let isEndOfText = inputEndsWithFullStop && match.3 != nil && match.range.upperBound == withoutLeadingZero.endIndex
            return "\(match.1)\(minutes)\(letter)m" + (isEndOfText ? "." : "")
        }
    }

    private static let smallNumbers = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
    private static let smallOrdinals = ["", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth"]

    /// The normaliser also changes "one question" to "1 question" and "first" to "1st". Put the
    /// words back for a number alone from zero to nine. Times, decimals and amounts stay.
    private static func smallNumbersAsWords(_ text: String) -> String {
        // Swift regexes have no lookbehind, so capture the character before the number.
        let alone = /(^|[^\w:.,£$€#\/-])(\d)(st|nd|rd|th)?\b(?![:.,]\d|%)/
        return text.replacing(alone) { match in
            let digit = Int(match.2)!
            var word = match.3 == nil ? smallNumbers[digit] : smallOrdinals[digit]
            guard !word.isEmpty else { return String(match.0) }
            let before = (text[..<match.range.lowerBound] + match.1).trimmingCharacters(in: .whitespaces)
            if before.isEmpty || before.last.map({ ".?!".contains($0) }) == true {
                word = word.prefix(1).uppercased() + word.dropFirst()
            }
            return match.1 + word
        }
    }
}
