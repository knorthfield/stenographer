import Accelerate
import Observation

/// Seven log-spaced frequency bands of the microphone, 0…1, for the bubble's waveform.
///
/// Copied from OpenSuperWhisper (`SpectrumAnalyzer` and `SpectrumBands`, MIT): a 1024-point
/// Hann-windowed FFT, the peak bin of each band in dB above a −70 dB floor, smoothed so the
/// bars rise fast and fall slowly.
@MainActor @Observable
final class Spectrum {
    nonisolated static let bandCount = 7
    nonisolated static let lowestHz: Float = 80
    nonisolated static let highestHz: Float = 8000
    nonisolated static let floorDb: Float = -70

    private(set) var bands = [Float](repeating: 0, count: bandCount)

    @ObservationIgnored private let fftSize = 1024
    @ObservationIgnored private let log2n = vDSP_Length(10)
    /// Never destroyed: there is one Spectrum for the life of the app.
    @ObservationIgnored private let fftSetup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2))!
    @ObservationIgnored private let window: [Float]
    @ObservationIgnored private var sampleBuffer: [Float] = []

    init() {
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = window
    }

    func reset() {
        sampleBuffer = []
        bands = [Float](repeating: 0, count: Self.bandCount)
    }

    func consume(_ samples: [Float], sampleRate: Float) {
        guard sampleRate > 0 else { return }
        sampleBuffer.append(contentsOf: samples)
        guard sampleBuffer.count >= fftSize else { return }
        sampleBuffer.removeFirst(sampleBuffer.count - fftSize)
        let magnitudes = transform(sampleBuffer)
        let ranges = Self.binRanges(sampleRate: sampleRate, fftSize: fftSize)
        bands = ranges.enumerated().map { index, range in
            let peak = magnitudes[range.clamped(to: 0..<magnitudes.count)].max() ?? 0
            return Self.smooth(previous: bands[index], next: Self.normalize(magnitude: peak))
        }
    }

    private func transform(_ frame: [Float]) -> [Float] {
        let half = fftSize / 2
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
        var real = [Float](repeating: 0, count: half)
        var imaginary = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedPointer in
                    windowedPointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }
        var scale = 1 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(half))
        return magnitudes
    }

    /// The `bandCount + 1` edges of the bands, spaced evenly on a log scale.
    nonisolated static func edges() -> [Float] {
        let ratio = highestHz / lowestHz
        return (0...bandCount).map { lowestHz * pow(ratio, Float($0) / Float(bandCount)) }
    }

    nonisolated static func binRanges(sampleRate: Float, fftSize: Int) -> [Range<Int>] {
        let edges = edges()
        let binCount = fftSize / 2
        let hzPerBin = sampleRate / Float(fftSize)
        return (0..<bandCount).map { index in
            let low = min(max(Int(edges[index] / hzPerBin), 0), binCount - 1)
            let high = min(max(Int(edges[index + 1] / hzPerBin), low + 1), binCount)
            return low..<high
        }
    }

    /// Maps a magnitude to 0…1: 0 at the dB floor and below, 1 at 0 dB.
    nonisolated static func normalize(magnitude: Float) -> Float {
        guard magnitude > 0, magnitude.isFinite else { return 0 }
        let db = min(max(20 * log10(magnitude), floorDb), 0)
        return (db - floorDb) / -floorDb
    }

    nonisolated static func smooth(previous: Float, next: Float) -> Float {
        let factor: Float = next > previous ? 0.6 : 0.18
        return previous + (next - previous) * factor
    }
}
