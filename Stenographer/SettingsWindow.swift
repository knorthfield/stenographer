import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, permissions, dictionary

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .permissions: "Permissions"
        case .dictionary: "Dictionary"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .permissions: "lock.shield"
        case .dictionary: "character.book.closed"
        }
    }
}

@MainActor
@Observable
private final class SettingsSelection {
    var pane = SettingsPane.general
}

/// The window with all the options: open at login, the permissions and the dictionary.
@MainActor
final class SettingsWindow {
    private let window: NSWindow
    private let dictation: Dictation
    private let selection = SettingsSelection()

    init(dictation: Dictation) {
        self.dictation = dictation
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.title = "Stenographer Settings"
        window.isReleasedWhenClosed = false
        let view = SettingsView(dictation: dictation, selection: selection) { [weak self] in self?.updateLevel() }
        let hostingController = NSHostingController(rootView: view)
        // Let the split view put its toolbar and title in the window.
        hostingController.sceneBridgingOptions = .all
        window.contentViewController = hostingController
        // The hosting controller has no size before the first layout, and then `center()` puts the window in a corner.
        window.setContentSize(NSSize(width: 640, height: 420))
    }

    func show(_ pane: SettingsPane? = nil) {
        if let pane { selection.pane = pane }
        if !window.isVisible { window.center() }
        updateLevel()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Stay above other apps' windows while a permission is missing, because the user opens
    /// System Settings while this window is open.
    private func updateLevel() {
        window.level = dictation.hasAllPermissions ? .normal : .floating
    }
}

private struct SettingsView: View {
    let dictation: Dictation
    @Bindable var selection: SettingsSelection
    let permissionsChanged: () -> Void

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection.pane) { pane in
                Label(pane.title, systemImage: pane.symbolName)
            }
            .navigationSplitViewColumnWidth(180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selection.pane {
                case .general: GeneralPane(dictation: dictation)
                case .permissions: PermissionsPane(dictation: dictation)
                case .dictionary: DictionaryPane()
                }
            }
            .navigationTitle(selection.pane.title)
        }
        .frame(width: 640, height: 420)
        .onChange(of: dictation.hasAllPermissions) { permissionsChanged() }
    }
}

private struct GeneralPane: View {
    let dictation: Dictation
    @State private var opensAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Toggle("Open at Login", isOn: $opensAtLogin)
                .onChange(of: opensAtLogin) { _, isOn in LoginItem.set(isOn) }
            Section("Speech Model") {
                ModelStatus(dictation: dictation)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionsPane: View {
    let dictation: Dictation

    var body: some View {
        Form {
            Section {
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
            } header: {
                Text("Hold right ⌥ to dictate. Stenographer needs this access:")
            }
            Section {
                ModelStatus(dictation: dictation)
            }
        }
        .formStyle(.grouped)
    }
}

/// The progress of the speech model download, and its result.
private struct ModelStatus: View {
    let dictation: Dictation

    var body: some View {
        if let progress = dictation.modelProgress {
            ProgressView(value: progress)
        }
        Text(dictation.status)
            .foregroundStyle(.secondary)
        if dictation.modelFailed {
            Button("Try Again") { dictation.loadModel() }
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

/// Where the user adds their own words and the wrong forms that Stenographer writes.
private struct DictionaryPane: View {
    @State private var entries = PersonalDictionary.load()

    var body: some View {
        Form {
            Section {
                ForEach($entries) { $entry in
                    HStack {
                        TextField("Word", text: $entry.word, prompt: Text("Word"))
                        TextField("Heard as", text: $entry.heardAs, prompt: Text("Heard as (optional)"))
                        Button {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove")
                    }
                    .labelsHidden()
                }
                Button("Add Word") { entries.append(PersonalDictionary.Entry()) }
            } footer: {
                Text("Add the words that Stenographer writes incorrectly, such as names. If it writes a different word, put that word in “Heard as”. For example: Kris, heard as Chris.")
            }
        }
        .formStyle(.grouped)
        .textFieldStyle(.roundedBorder)
        .onChange(of: entries) { _, entries in PersonalDictionary.save(entries) }
    }
}
