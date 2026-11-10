import AppKit
import Carbon.HIToolbox

/// Pastes text into the focused app with ⌘V, then puts the old clipboard back.
@MainActor
enum Paster {
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Tells clipboard managers not to keep this text.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let changeCount = pasteboard.changeCount
        pressCommandV()

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            // Something else changed the clipboard after us: leave it alone.
            guard pasteboard.changeCount == changeCount, !saved.isEmpty else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects(saved.map { contents in
                let item = NSPasteboardItem()
                for (type, data) in contents { item.setData(data, forType: type) }
                return item
            })
        }
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
