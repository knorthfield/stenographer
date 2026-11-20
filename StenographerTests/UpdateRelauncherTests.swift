import Foundation
import Testing
@testable import Stenographer

struct UpdateRelauncherTests {
    @Test func readsTheVersionFromTheInfoPlistOnTheDisk() throws {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: app) }
        try #require(NSDictionary(dictionary: ["CFBundleVersion": "7"])
            .write(to: contents.appendingPathComponent("Info.plist"), atomically: true))

        #expect(UpdateRelauncher.installedVersion(ofAppAt: app) == "7")
    }

    @Test func anAppThatIsNotOnTheDiskHasNoVersion() {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).app")
        #expect(UpdateRelauncher.installedVersion(ofAppAt: app) == nil)
    }

    @Test func anUpdateIsReadyWhenTwoChecksFindTheSameNewVersion() {
        #expect(UpdateRelauncher.isUpdateReady(running: "3", installed: "4", atLastCheck: "4"))
    }

    @Test func anUpdateIsNotReadyAtTheFirstCheckThatFindsIt() {
        #expect(!UpdateRelauncher.isUpdateReady(running: "3", installed: "4", atLastCheck: "3"))
    }

    @Test func theSameVersionIsNotAnUpdate() {
        #expect(!UpdateRelauncher.isUpdateReady(running: "3", installed: "3", atLastCheck: "3"))
    }

    @Test func anAppThatIsNotOnTheDiskIsNotAnUpdate() {
        #expect(!UpdateRelauncher.isUpdateReady(running: "3", installed: nil, atLastCheck: nil))
    }
}
