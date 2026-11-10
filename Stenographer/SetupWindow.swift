import AppKit
import SwiftUI

/// The window that asks for the microphone and Accessibility, and shows the model download.
/// It closes itself when both permissions are given.
@MainActor
final class SetupWindow {
    private let window: NSWindow

    init(dictation: Dictation) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.title = "Welcome to Stenographer"
        window.isReleasedWhenClosed = false
        // Stay above other apps' windows, because the user opens System Settings while this window is open.
        window.level = .floating
        let view = SetupView(dictation: dictation) { [weak self] in self?.window.close() }
        window.contentViewController = NSHostingController(rootView: view)
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct SetupView: View {
    let dictation: Dictation
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hold right ⌥ to dictate. First, give Stenographer access:")
            PermissionRow(title: "Microphone", isGiven: dictation.hasMicrophone) {
                Task { await Permissions.requestMicrophone() }
            }
            PermissionRow(
                title: "Accessibility",
                note: "Turn on Stenographer in System Settings › Privacy & Security › Accessibility.",
                isGiven: dictation.hasAccessibility
            ) {
                Permissions.requestAccessibility()
            }
            Divider()
            if let progress = dictation.modelProgress {
                ProgressView(value: progress)
            }
            Text(dictation.status)
                .foregroundStyle(.secondary)
            if dictation.modelFailed {
                Button("Try Again") { dictation.loadModel() }
            }
        }
        .padding(20)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: dictation.hasAllPermissions) { _, hasAll in
            if hasAll { close() }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    var note: String?
    let isGiven: Bool
    let allow: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: isGiven ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGiven ? .green : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if let note, !isGiven {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !isGiven {
                Button("Allow…", action: allow)
            }
        }
    }
}
