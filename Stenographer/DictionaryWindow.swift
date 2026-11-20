import AppKit
import SwiftUI

/// The window where the user adds their own words and the wrong forms that Stenographer writes.
@MainActor
final class DictionaryWindow {
    private let window: NSWindow

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.title = "Dictionary"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: DictionaryView())
    }

    func show() {
        if !window.isVisible { window.center() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct DictionaryView: View {
    @State private var entries = PersonalDictionary.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add the words that Stenographer writes incorrectly, such as names. If it writes a different word, put that word in “Heard as”. For example: Kris, heard as Chris.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($entries) { $entry in
                        HStack {
                            TextField("Word", text: $entry.word)
                            TextField("Heard as (optional)", text: $entry.heardAs)
                            Button {
                                entries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove")
                        }
                    }
                }
                .padding(1)
            }
            Button("Add Word") { entries.append(PersonalDictionary.Entry()) }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20)
        .frame(width: 460, height: 360)
        .onChange(of: entries) { _, entries in PersonalDictionary.save(entries) }
    }
}
