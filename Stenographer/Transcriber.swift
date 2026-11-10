import FluidAudio
import Foundation

/// Speech to text with Parakeet TDT 0.6B v3 (25 European languages, detected automatically).
actor Transcriber {
    private var manager: AsrManager?

    /// Downloads the model on first use (about 480 MB), then loads it from the cache.
    func load(progress: @escaping @Sendable (Double) -> Void) async throws {
        let models = try await AsrModels.downloadAndLoad(version: .v3) { progress($0.fractionCompleted) }
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        // Core ML prepares the model on its first prediction, which takes some seconds.
        // Do it now, not at the first dictation.
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        _ = try await manager.transcribe([Float](repeating: 0, count: 16_000), decoderState: &state)
        self.manager = manager
    }

    /// `samples` are 16 kHz mono.
    func transcribe(_ samples: [Float]) async throws -> String {
        guard let manager else { throw TranscriberError.notLoaded }
        // FluidAudio refuses less than 0.3 s of audio. A press of 0.3 s can give fewer samples,
        // because the audio engine starts late, so pad to one second.
        let padded = samples + [Float](repeating: 0, count: max(0, 16_000 - samples.count))
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(padded, decoderState: &state).text
    }
}

enum TranscriberError: LocalizedError {
    case notLoaded

    var errorDescription: String? { "The speech model is not loaded." }
}
