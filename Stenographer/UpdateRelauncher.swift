import AppKit

/// Homebrew replaces the app on the disk while the app runs, and does not start it again.
/// This finds the new version on the disk and starts it when the app is idle.
@MainActor
final class UpdateRelauncher {
    private static let runningVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

    private let isBusy: () -> Bool
    private var timer: Timer?
    private var versionAtLastCheck = runningVersion

    init(isBusy: @escaping () -> Bool = { false }) {
        self.isBusy = isBusy
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.relaunchIfUpdated() }
        }
    }

    /// The version in the Info.plist on the disk. `Bundle.main` keeps the values from the launch.
    nonisolated static func installedVersion(ofAppAt appURL: URL) -> String? {
        let infoPlist = appURL.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: infoPlist)?["CFBundleVersion"] as? String
    }

    /// True when the disk has a version that is not the running one, and two checks found the
    /// same version: then the copy is complete.
    nonisolated static func isUpdateReady(running: String?, installed: String?, atLastCheck: String?) -> Bool {
        installed != nil && installed != running && installed == atLastCheck
    }

    private func relaunchIfUpdated() {
        let installedVersion = Self.installedVersion(ofAppAt: Bundle.main.bundleURL)
        let isUpdateReady = Self.isUpdateReady(
            running: Self.runningVersion, installed: installedVersion, atLastCheck: versionAtLastCheck)
        versionAtLastCheck = installedVersion
        guard isUpdateReady, !NSApp.isActive, !isBusy() else { return }
        relaunch()
    }

    private func relaunch() {
        // The new version must start after this one stops: two copies would compete for the
        // same hot key, menu bar icon and files.
        let waitThenOpen = Process()
        waitThenOpen.executableURL = URL(fileURLWithPath: "/bin/sh")
        waitThenOpen.arguments = [
            "-c", #"while kill -0 "$0" 2>/dev/null; do sleep 0.2; done; open -g "$1""#,
            String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath,
        ]
        guard (try? waitThenOpen.run()) != nil else { return }
        NSApp.terminate(nil)
    }
}
