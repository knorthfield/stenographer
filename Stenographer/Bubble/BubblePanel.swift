import AppKit
import SwiftUI

/// The floating window that holds the recording bubble, at the bottom centre of the screen.
@MainActor
final class BubblePanel {
    @Observable
    final class Model {
        var phase = BubblePhase.recording
        var visible = false
    }

    /// The gap between the bottom of the screen and the bubble.
    private static let bottomInset: CGFloat = 120

    private let model = Model()
    private let panel: NSPanel

    init(spectrum: Spectrum) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none

        let root = BubbleRoot(model: model, spectrum: spectrum) { [weak self] size in self?.resize(to: size) }
        let host = NSHostingController(rootView: root)
        // Never `.preferredContentSize`: on macOS 26 it can recurse and crash.
        host.sizingOptions = []
        panel.contentViewController = host
    }

    func show() {
        model.phase = .recording
        place()
        panel.orderFrontRegardless()
        withAnimation(RecordingBubble.appear) { model.visible = true }
    }

    func showProcessing() {
        model.phase = .processing
    }

    func hide() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            model.visible = false
        } completion: { [weak self] in
            guard let self, !model.visible else { return }
            panel.orderOut(nil)
        }
    }

    private func resize(to size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        panel.setContentSize(NSSize(width: ceil(size.width), height: ceil(size.height)))
        place()
    }

    /// Bottom centre of the screen with the mouse pointer.
    private func place() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let frame = screen.frame
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + Self.bottomInset))
    }
}

private struct BubbleRoot: View {
    let model: BubblePanel.Model
    let spectrum: Spectrum
    let onResize: (CGSize) -> Void

    var body: some View {
        RecordingBubble(phase: model.phase, bands: spectrum.bands, visible: model.visible)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onResize($0) }
    }
}
