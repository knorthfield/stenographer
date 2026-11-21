import ServiceManagement
import SwiftUI

@main
struct StenographerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Stenographer", systemImage: "waveform") {
            MenuContent(dictation: appDelegate.dictation) { appDelegate.showSettings() }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dictation = Dictation()
    private lazy var settingsWindow = SettingsWindow(dictation: dictation)
    private lazy var updateRelauncher = UpdateRelauncher(isBusy: { [dictation] in dictation.isDictating })

    func showSettings() {
        settingsWindow.show()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests run inside the app: do not download the model, add a login item or show a window.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        LoginItem.enableOnFirstLaunch()
        dictation.onPermissionMissing = { [weak self] in self?.settingsWindow.show(.permissions) }
        dictation.start()
        updateRelauncher.start()
    }
}

private struct MenuContent: View {
    let dictation: Dictation
    let showSettings: () -> Void

    var body: some View {
        Text(dictation.status)
        if let lastError = dictation.lastError {
            Text(lastError)
        }
        if dictation.modelFailed {
            Button("Try Again") { dictation.loadModel() }
        }
        Divider()
        Button("Settings…", action: showSettings)
            .keyboardShortcut(",")
        Button("Quit Stenographer") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

enum LoginItem {
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
