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
            "Give Stenographer access to start"
        case .ready:
            "Hold right ⌥ to dictate"
        }
    }

    var modelFailed: Bool {
        if case .failed = modelState { true } else { false }
    }

    /// The fraction of the model that is ready, while it loads.
    var modelProgress: Double? {
        if case .loading(let fraction) = modelState { fraction } else { nil }
    }

    var hasAllPermissions: Bool { hasMicrophone && hasAccessibility }

    /// Called at start, and when a permission goes away, if a permission is missing.
    @ObservationIgnored var onPermissionMissing: () -> Void = {}

    func start() {
        key.onPress = { [weak self] in self?.startRecording() }
        key.onRelease = { [weak self] in self?.stopRecording() }
        key.onOtherKey = { [weak self] in self?.cancelRecording() }
        loadModel()
        if !hasAllPermissions { onPermissionMissing() }
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

    /// No notification tells us when the user gives or removes access, so check again and again:
    /// every second while access is missing, so the setup window updates at once, and less
    /// frequently after that, because a menu bar app that wakes up every second costs energy.
    private func watchPermissions() {
        Task {
            while true {
                let lostMicrophone = hasMicrophone && !Permissions.hasMicrophone
                let lostAccessibility = hasAccessibility && !Permissions.hasAccessibility
                if hasMicrophone != Permissions.hasMicrophone { hasMicrophone.toggle() }
                if hasAccessibility != Permissions.hasAccessibility { hasAccessibility.toggle() }
                if lostMicrophone || lostAccessibility { onPermissionMissing() }
                if hasAccessibility { key.start() }
                try? await Task.sleep(for: .seconds(hasAllPermissions ? 10 : 1))
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

    /// Removes fillers, writes numbers with digits, trims the text, and adds a space after a final
    /// punctuation mark so the next dictation does not join on to it.
    nonisolated static func pasteable(_ text: String) -> String? {
        let cleaned = NumberFormatting.writtenNumbers(removingFillers(text))
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return nil }
        return last.isPunctuation ? trimmed + " " : trimmed
    }

    /// Removes "um", "uh" and similar sounds. Each one is not a word in any of the 25 languages,
    /// so "er" (German) and "eh" (Italian, Spanish) stay.
    nonisolated static func removingFillers(_ text: String) -> String {
        // A filler that starts a sentence goes with its punctuation, and the next word gets a
        // capital letter. Repeat, because the next word can be a filler too ("Uh, um, so").
        let atSentenceStart = /(^|[.?!])\s*\b(?:um+|uh+|uhm|erm|hm+|mm+|ähm?|euh)\b[,.?!]?(\s*)(\p{L}?)/
            .ignoresCase()
        var result = text
        while true {
            let next = result.replacing(atSentenceStart) { $0.1 + $0.2 + $0.3.uppercased() }
            if next == result { break }
            result = next
        }
        // In a sentence, a filler goes with the commas around it.
        let inSentence = /,?\s*\b(?:um+|uh+|uhm|erm|hm+|mm+|ähm?|euh)\b,?/.ignoresCase()
        return result.replacing(inSentence, with: "")
    }
}
