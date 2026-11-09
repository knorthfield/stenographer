import AppKit
import Observation

/// Hold right Option to record; release to transcribe and paste.
@MainActor @Observable
final class Dictation {
    private enum ModelState: Equatable {
        case loading(Double)
        case ready
        case failed(String)
    }

    private enum Stage {
        case idle, recording, transcribing
    }

    private(set) var hasMicrophone = Permissions.hasMicrophone
    private(set) var hasAccessibility = Permissions.hasAccessibility
    private(set) var lastError: String?
    private var modelState = ModelState.loading(0)

    @ObservationIgnored private var stage = Stage.idle
    @ObservationIgnored private var recordingStartedAt = Date.distantPast
    @ObservationIgnored private let key = RightOptionKey()
    @ObservationIgnored private let recorder = Recorder()
    @ObservationIgnored private let transcriber = Transcriber()
    @ObservationIgnored private let spectrum = Spectrum()
    @ObservationIgnored private lazy var bubble = BubblePanel(spectrum: spectrum)

    /// A shorter press is an accidental tap.
    private static let minimumHold: TimeInterval = 0.3

    var status: String {
        switch modelState {
        case .loading(let fraction):
            "Getting the speech model ready… \(Int(fraction * 100)) %"
        case .failed(let message):
            "The speech model did not load: \(message)"
        case .ready where !hasMicrophone || !hasAccessibility:
            "Give access below to start"
        case .ready:
            "Hold right ⌥ to dictate"
        }
    }

    var modelFailed: Bool {
        if case .failed = modelState { true } else { false }
    }

    func start() {
        key.onPress = { [weak self] in self?.startRecording() }
        key.onRelease = { [weak self] in self?.stopRecording() }
        key.onOtherKey = { [weak self] in self?.cancelRecording() }
        loadModel()
        watchPermissions()
    }

    func loadModel() {
        modelState = .loading(0)
        Task {
            do {
                try await transcriber.load { fraction in
                    Task { @MainActor [weak self] in
                        if case .loading = self?.modelState { self?.modelState = .loading(fraction) }
                    }
                }
                modelState = .ready
            } catch {
                modelState = .failed(error.localizedDescription)
            }
        }
    }

    /// No notification tells us when the user gives access, so check every second.
    private func watchPermissions() {
        Task {
            while true {
                if hasMicrophone != Permissions.hasMicrophone { hasMicrophone.toggle() }
                if hasAccessibility != Permissions.hasAccessibility { hasAccessibility.toggle() }
                if hasAccessibility { key.start() }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func startRecording() {
        guard stage == .idle, modelState == .ready, hasMicrophone else { return }
        let spectrum = spectrum
        do {
            try recorder.start { buffer in
                guard let channel = buffer.floatChannelData?[0] else { return }
                let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                let sampleRate = Float(buffer.format.sampleRate)
                Task { @MainActor in spectrum.consume(samples, sampleRate: sampleRate) }
            }
        } catch {
            lastError = error.localizedDescription
            return
        }
        stage = .recording
        recordingStartedAt = .now
        bubble.show()
    }

    private func stopRecording() {
        guard stage == .recording else { return }
        let samples = recorder.stop()
        spectrum.reset()
        guard Date.now.timeIntervalSince(recordingStartedAt) >= Self.minimumHold else {
            stage = .idle
            bubble.hide()
            return
        }
        stage = .transcribing
        bubble.showProcessing()
        Task {
            defer {
                stage = .idle
                bubble.hide()
            }
            do {
                let text = try await transcriber.transcribe(samples)
                lastError = nil
                if let pasteable = Self.pasteable(text) { Paster.paste(pasteable) }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func cancelRecording() {
        guard stage == .recording else { return }
        _ = recorder.stop()
        spectrum.reset()
        stage = .idle
        bubble.hide()
    }

    /// Trims the text, and adds a space after a final punctuation mark so the next dictation does
    /// not join on to it.
    nonisolated static func pasteable(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return nil }
        return last.isPunctuation ? trimmed + " " : trimmed
    }
}
