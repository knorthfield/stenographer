import AppKit
import Carbon.HIToolbox

/// Pastes text into the focused app with ⌘V, then puts the old clipboard back when the app has
/// read the text.
@MainActor
enum Paster {
    private typealias Items = [[(NSPasteboard.PasteboardType, Data)]]

    /// The user's clipboard while it waits to be put back, and the clipboard state of our paste.
    private struct PendingRestore {
        let saved: Items
        let changeCount: Int
        let promise: PromisedText
        let task: Task<Void, Never>
        var readAt: ContinuousClock.Instant?
    }

    private static var pendingRestore: PendingRestore?

    /// Slow apps (Chromium, Electron, a VM, a busy Mac) can read the clipboard long after ⌘V. A
    /// fixed delay can put the old clipboard back first, and then the app pastes that.
    private static let delayAfterRead = Duration.milliseconds(50)
    private static let shortestRestore = Duration.milliseconds(450)
    /// If no app reads the text in this time, the paste failed: the text stays on the clipboard
    /// so that the user can paste it.
    private static let longestWait = Duration.seconds(3)

    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        // If the last paste is still waiting, the clipboard holds its transcript: keep the
        // user's clipboard that it saved instead.
        let saved: Items
        if let pending = pendingRestore, pending.changeCount == pasteboard.changeCount {
            pending.task.cancel()
            saved = pending.saved
        } else {
            saved = pasteboard.pasteboardItems?.map { item in
                item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
            } ?? []
        }

        // The text is a promise, so that Paster knows when an app reads it.
        let promise = PromisedText(text)
        let item = NSPasteboardItem()
        item.setDataProvider(promise, forTypes: [.string])
        // Tells clipboard managers not to keep this text.
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        let changeCount = pasteboard.changeCount
        pressCommandV()
        let pastedAt = ContinuousClock.now

        let task = Task {
            while true {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                let now = ContinuousClock.now
                if let readAt = pendingRestore?.readAt {
                    guard now >= max(readAt + delayAfterRead, pastedAt + shortestRestore) else { continue }
                    pendingRestore = nil
                    restore(saved, on: pasteboard, ifStill: changeCount)
                    return
                }
                if now >= pastedAt + longestWait {
                    pendingRestore = nil
                    return
                }
            }
        }
        pendingRestore = PendingRestore(saved: saved, changeCount: changeCount, promise: promise, task: task)
    }

    fileprivate static func textWasRead(from promise: PromisedText) {
        guard pendingRestore?.promise === promise, pendingRestore?.readAt == nil else { return }
        pendingRestore?.readAt = .now
    }

    private static func restore(_ saved: Items, on pasteboard: NSPasteboard, ifStill changeCount: Int) {
        // Something else changed the clipboard after us: leave it alone.
        guard pasteboard.changeCount == changeCount, !saved.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(saved.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        })
    }

    /// Presses the ⌘ key itself, not only the ⌘ flag on V: Chrome and Electron apps (Slack,
    /// VS Code) ignore a ⌘V that comes without a ⌘ key-down.
    private static func pressCommandV() {
        let commandKey: CGKeyCode = 0x37
        let qwertyV: CGKeyCode = 9
        let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        let vKey = layout.flatMap(commandVKey(in:)) ?? qwertyV
        let source = CGEventSource(stateID: .combinedSessionState)
        let keys: [(CGKeyCode, Bool)] = [(commandKey, true), (vKey, true), (vKey, false), (commandKey, false)]
        for (key, isDown) in keys {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = key == commandKey && !isDown ? [] : .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    /// The key that types "v" while ⌘ is held in this keyboard layout. It is not the same key on
    /// every layout (Dvorak moves it), and apps find ⌘V by the character.
    static func commandVKey(in layout: TISInputSource) -> CGKeyCode? {
        guard let property = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes -> CGKeyCode? in
            guard let keyboard = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            for key in UInt16(0)..<128 {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(keyboard, key, UInt16(kUCKeyActionDown), UInt32((cmdKey >> 8) & 0xFF),
                                            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                            &deadKeyState, characters.count, &length, &characters)
                if status == noErr, length == 1, characters[0] == UniChar(UInt8(ascii: "v")) { return key }
            }
            return nil
        }
    }
}

/// Gives the text to the app that reads the clipboard, and tells Paster that it was read.
private final class PromisedText: NSObject, NSPasteboardItemDataProvider, Sendable {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem,
                    provideDataForType type: NSPasteboard.PasteboardType) {
        item.setString(text, forType: type)
        Task { @MainActor in Paster.textWasRead(from: self) }
    }
}
