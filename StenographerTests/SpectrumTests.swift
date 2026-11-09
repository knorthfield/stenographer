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
        #expect(Dictation.pasteable("  Hello there.\n") == "Hello there. ")
        #expect(Dictation.pasteable("hello") == "hello")
        #expect(Dictation.pasteable("   ") == nil)
    }
}
