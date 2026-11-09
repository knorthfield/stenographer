import SwiftUI

// The Liquid Glass recording bubble: a glass capsule with the waveform and the red dot.
//
// A trimmed copy of `RecordingBubble` and `WaveformMeter` from OpenSuperWhisper (my-monkeys fork,
// MIT), fixed at the setup we use: waveform height 30, size 0.8, waveform then dot, no label and
// no controls.

enum BubblePhase {
    /// Listening: live waveform, breathing dot.
    case recording
    /// Transcribing: a spinner in the waveform's place, a steady dot.
    case processing
}

struct RecordingBubble: View {
    var phase: BubblePhase
    var bands: [Float]
    /// Showing and hiding go through the glass's own `.materialize` transition. Glass is composited
    /// by the system on its own layer and ignores outside scale, blur and opacity.
    var visible: Bool

    private static let waveformHeight: CGFloat = 30
    private static let size: CGFloat = 0.8
    /// The pill's height: the waveform plus some breathing room.
    private let bar = max(26, ((waveformHeight + 16) * size).rounded())
    private let meterHeight = (waveformHeight * size).rounded()
    private var glyphSize: CGFloat { (bar * 0.45).rounded() }
    /// The edge highlight. Glass takes its edge from what is behind it, so over a dark, flat
    /// window the edge all but disappears; this hairline keeps it readable.
    private let rim = 0.45
    /// A dimming layer inside the glass, for contrast: black under dark mode, white under light.
    private let dim = 0.35

    static let appear = Animation.smooth(duration: 0.28)
    static let morph = Animation.spring(duration: 0.3, bounce: 0.12)

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer {
            // A hidden stand-in holds the size, so the window has its size before the glass
            // materialises into it.
            ZStack {
                content.hidden()
                if visible { glass.transition(.opacity) }
            }
        }
        .animation(Self.morph, value: phase)
    }

    private var glass: some View {
        content
            .background { rimStroke }
            .background { Capsule().fill((colorScheme == .dark ? Color.black : .white).opacity(dim)) }
            .glassEffect(.regular, in: .capsule)
            .glassEffectID("bubble", in: namespace)
            .glassEffectTransition(.materialize)
    }

    private var content: some View {
        HStack(spacing: 10) {
            if phase == .processing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: WaveformMeter.width, height: meterHeight)
                    .transition(.opacity)
            } else {
                WaveformMeter(height: meterHeight, bands: bands)
                    .transition(.opacity)
            }
            recordDot
        }
        .padding(.leading, (bar * 0.36).rounded())
        .padding(.trailing, (bar * 0.42).rounded())
        .padding(.vertical, (6 * Self.size).rounded())
        .frame(minHeight: bar)
    }

    /// While listening the dot breathes (one breath per 1.6 s) and casts a soft red glow onto the
    /// glass. The glow is part of the glass's content, so it moves and materialises with it;
    /// `.plusLighter` makes it read as light on the glass rather than paint.
    private var recordDot: some View {
        let dotSize = (bar * 0.22).rounded()
        let live = phase == .recording
        return TimelineView(.animation(paused: !live || reduceMotion)) { timeline in
            let breath = live
                ? (reduceMotion ? 0.6 : (sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.6) + 1) / 2)
                : 0
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: dotSize * 2.2, height: dotSize * 2.2)
                    .blur(radius: dotSize * 0.9)
                    .scaleEffect(0.85 + 0.3 * breath)
                    .opacity(live ? 0.035 + 0.085 * breath : 0)
                    .blendMode(.plusLighter)
                Circle()
                    .fill(Color.red)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(live ? 0.75 + 0.25 * breath : 0.55)
            }
        }
        .frame(width: glyphSize, height: glyphSize)
        .accessibilityHidden(true)
    }

    /// A hairline, brighter at the top (where light hits) and faint at the bottom.
    private var rimStroke: some View {
        Capsule().strokeBorder(
            LinearGradient(colors: [.white.opacity(rim), .white.opacity(rim * 0.25), .white.opacity(rim * 0.5)],
                           startPoint: .top, endPoint: .bottom),
            lineWidth: 1)
    }
}

/// One capsule bar per spectrum band.
struct WaveformMeter: View {
    var height: CGFloat
    var bands: [Float]

    private static let barWidth: CGFloat = 2.5
    private static let barSpacing: CGFloat = 2.5
    private static let restHeight: CGFloat = 2.5

    static var width: CGFloat {
        let count = CGFloat(Spectrum.bandCount)
        return count * barWidth + (count - 1) * barSpacing
    }

    var body: some View {
        HStack(alignment: .center, spacing: Self.barSpacing) {
            ForEach(bands.indices, id: \.self) { band in
                let level = CGFloat(min(1, max(0, bands[band])))
                Capsule()
                    .fill(Color.primary.opacity(0.55 + 0.45 * level))
                    .frame(width: Self.barWidth, height: Self.restHeight + (height - Self.restHeight) * level)
            }
        }
        .frame(height: height)
        .animation(.linear(duration: 0.08), value: bands)
        .accessibilityHidden(true)
    }
}
