import ServiceManagement
import SwiftUI

@main
struct StenographerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Stenographer", systemImage: "waveform") {
            MenuContent(dictation: appDelegate.dictation)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dictation = Dictation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests run inside the app: do not download the model or add a login item.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        LoginItem.enableOnFirstLaunch()
        dictation.start()
    }
}

private struct MenuContent: View {
    let dictation: Dictation
    @State private var opensAtLogin = LoginItem.isEnabled

    var body: some View {
        Text(dictation.status)
        if let lastError = dictation.lastError {
            Text(lastError)
        }
        if dictation.modelFailed {
            Button("Try Again") { dictation.loadModel() }
        }
        if !dictation.hasMicrophone {
            Button("Allow Microphone…") { Task { await Permissions.requestMicrophone() } }
        }
        if !dictation.hasAccessibility {
            Button("Allow Accessibility…") { Permissions.requestAccessibility() }
        }
        Divider()
        Toggle("Open at Login", isOn: $opensAtLogin)
            .onChange(of: opensAtLogin) { _, isOn in LoginItem.set(isOn) }
        Button("Quit Stenographer") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ isEnabled: Bool) {
        try? isEnabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
    }

    static func enableOnFirstLaunch() {
        let key = "didEnableLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(true)
    }
}
