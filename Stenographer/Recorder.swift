import AVFoundation

/// Records the microphone as 16 kHz mono samples, the format Parakeet needs.
final class Recorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
    private let lock = NSLock()
    private var samples: [Float] = []

    /// `onBuffer` gets each raw microphone buffer on the audio thread, for the waveform.
    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        lock.withLock { samples = [] }
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else {
            throw RecorderError.unsupportedMicrophone
        }
        converter.downmix = true
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            onBuffer(buffer)
            self?.append(buffer, using: converter)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    /// Stops recording and returns everything recorded since `start`.
    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // Give the samples to the caller, and keep no copy while the app is idle.
        return lock.withLock {
            defer { samples = [] }
            return samples
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
        var isConsumed = false
        converter.convert(to: output, error: nil) { _, status in
            if isConsumed {
                // Keep the converter open for the next buffer.
                status.pointee = .noDataNow
                return nil
            }
            isConsumed = true
            status.pointee = .haveData
            return buffer
        }
        guard let channel = output.floatChannelData?[0] else { return }
        let converted = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))
        lock.withLock { samples.append(contentsOf: converted) }
    }
}

enum RecorderError: LocalizedError {
    case unsupportedMicrophone

    var errorDescription: String? { "The microphone's audio format is not supported." }
}
