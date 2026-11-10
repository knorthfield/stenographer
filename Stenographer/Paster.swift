import AppKit

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
        let vKey: CGKeyCode = 9
        let source = CGEventSource(stateID: .combinedSessionState)
        let keys: [(CGKeyCode, Bool)] = [(commandKey, true), (vKey, true), (vKey, false), (commandKey, false)]
        for (key, isDown) in keys {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = key == commandKey && !isDown ? [] : .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
