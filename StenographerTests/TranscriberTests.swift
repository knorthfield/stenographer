import Testing
@testable import Stenographer

struct TranscriberTests {
    /// Loads the model from the cache (it downloads about 480 MB if the cache is empty).
    @Test func firstTranscriptionAfterLoadIsFast() async throws {
        let transcriber = Transcriber()
        try await transcriber.load { _ in }
        let silence = [Float](repeating: 0, count: 32_000)
        let clock = ContinuousClock()

        let first = try await clock.measure { _ = try await transcriber.transcribe(silence) }
        let later = try await clock.measure { _ = try await transcriber.transcribe(silence) }

        // Without the warm-up in `load`, the first transcription takes 1.5–3 s; later ones take about 0.2 s.
        #expect(first < .seconds(1), "first \(first), later \(later)")
    }
}
