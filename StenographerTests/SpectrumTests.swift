import Testing
@testable import Stenographer

struct SpectrumTests {
    @Test func edgesRunFromLowestToHighest() {
        let edges = Spectrum.edges()
        #expect(edges.count == Spectrum.bandCount + 1)
        #expect(abs(edges.first! - 80) < 0.001)
        #expect(abs(edges.last! - 8000) < 0.1)
    }

    @Test func binRangesAreNotEmptyAndInOrder() {
        let ranges = Spectrum.binRanges(sampleRate: 48_000, fftSize: 1024)
        #expect(ranges.count == Spectrum.bandCount)
        for range in ranges { #expect(!range.isEmpty) }
        for (a, b) in zip(ranges, ranges.dropFirst()) { #expect(a.upperBound <= b.upperBound) }
    }

    @Test func normalizeMapsTheDbRangeToZeroToOne() {
        #expect(Spectrum.normalize(magnitude: 0) == 0)
        #expect(Spectrum.normalize(magnitude: 1) == 1)
        #expect(Spectrum.normalize(magnitude: 10) == 1)
        #expect(Spectrum.normalize(magnitude: 1e-6) == 0)
        #expect(abs(Spectrum.normalize(magnitude: 0.001) - 10.0 / 70) < 0.001)
    }

    @Test func smoothRisesFasterThanItFalls() {
        let rise = Spectrum.smooth(previous: 0, next: 1)
        let fall = 1 - Spectrum.smooth(previous: 1, next: 0)
        #expect(rise > fall)
    }
}

struct PasteableTests {
    @Test func trimsAndAddsASpaceAfterPunctuation() {
        #expect(Dictation.ruleCleaned("  Hello there.\n") == "Hello there.")
        #expect(Dictation.ruleCleaned("   ") == nil)
        #expect(Dictation.withTrailingSpace("Hello there.") == "Hello there. ")
        #expect(Dictation.withTrailingSpace("hello") == "hello")
    }

    @Test func nothingIsPastedWhenOnlyFillersWereSaid() {
        #expect(Dictation.ruleCleaned("Um.") == nil)
        #expect(Dictation.ruleCleaned("Uh, um.") == nil)
    }
}

struct FillerTests {
    @Test(arguments: [
        ("Um, so we go.", "So we go."),
        ("I think, uh, we should.", "I think we should."),
        ("So um we go.", "So we go."),
        ("We should, um.", "We should."),
        ("Done. Uh, next one.", "Done. Next one."),
        ("Done. Um. Next one.", "Done. Next one."),
        ("Uh, um, so we go.", "So we go."),
        ("Ähm, wir gehen.", "Wir gehen."),
        ("Hummus and umbrellas.", "Hummus and umbrellas."),
        ("Er kommt morgen.", "Er kommt morgen."),
    ])
    func removesFillers(text: String, expected: String) {
        #expect(Dictation.ruleCleaned(text) == expected)
    }
}
