import Testing
@testable import Stenographer

struct NumberFormattingTests {
    @Test(arguments: [
        // Years
        ("It was twenty fifteen.", "It was 2015."),
        ("In two thousand and three we moved.", "In 2003 we moved."),
        ("Since two thousand fifteen.", "Since 2015."),
        // Times with am or pm
        ("Meet at three pm.", "Meet at 3pm."),
        ("Meet at three PM.", "Meet at 3pm."),
        ("Meet at half past three pm.", "Meet at 3:30pm."),
        ("Meet at three thirty am tomorrow.", "Meet at 3:30am tomorrow."),
        ("Meet at half three pm.", "Meet at 3:30pm."),
        ("Call me at 3 p.m.", "Call me at 3pm."),
        ("Call me at 3 p.m. tomorrow.", "Call me at 3pm tomorrow."),
        // Times without am or pm
        ("See you at half one.", "See you at 1:30."),
        ("See you at one o'clock.", "See you at 1:00."),
        ("See you at quarter past two.", "See you at 2:15."),
        // Numbers in normal sentences
        ("I have one question.", "I have one question."),
        ("One of them is here.", "One of them is here."),
        ("Take the first left.", "Take the first left."),
        ("It costs five pounds.", "It costs five pounds."),
        ("There were two hundred and fifty people.", "There were 250 people."),
        ("I am here.", "I am here."),
        // Other languages
        ("Je suis arrivé en deux mille quinze.", "Je suis arrivé en deux mille quinze."),
    ])
    func writesNumbers(spoken: String, written: String) {
        #expect(NumberFormatting.writtenNumbers(spoken) == written)
    }

    @Test func isFast() {
        let clock = ContinuousClock()
        _ = NumberFormatting.writtenNumbers("Warm up.")
        let time = clock.measure {
            _ = NumberFormatting.writtenNumbers(
                "We met in twenty fifteen at half one, and again at three pm with two hundred people.")
        }
        #expect(time < .milliseconds(50), "\(time)")
    }
}
