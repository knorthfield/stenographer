import ApplicationServices
import Carbon.HIToolbox

/// Reads the text before the cursor in the focused app, so the clean-up can spell names and terms
/// as the app does. The text is never stored or logged.
enum ScreenText {
    /// Terminals and long documents give a lot of text. The nearest text is the most useful, and
    /// the model's context is small.
    static let maximumLength = 1_000

    /// Without a timeout, an app that does not respond blocks each call for about 6 s.
    private static let timeout: Float = 0.1

    static func beforeCursor() -> String? {
        // A password field has the keyboard.
        guard !IsSecureEventInputEnabled() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, timeout)
        if let app: AXUIElement = attribute(kAXFocusedApplicationAttribute, of: systemWide) {
            // Chrome and Electron apps give no text until this is set. The first read can still
            // be empty. (Not AXEnhancedUserInterface: it makes Chrome's windows animate badly.)
            AXUIElementSetMessagingTimeout(app, timeout)
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
        guard let element: AXUIElement = attribute(kAXFocusedUIElementAttribute, of: systemWide) else { return nil }
        AXUIElementSetMessagingTimeout(element, timeout)
        let subrole: String? = attribute(kAXSubroleAttribute, of: element)
        guard subrole != kAXSecureTextFieldSubrole,
              let value: String = attribute(kAXValueAttribute, of: element) else { return nil }

        var cursor = value.utf16.count
        if let rangeValue: AXValue = attribute(kAXSelectedTextRangeAttribute, of: element) {
            var range = CFRange()
            if AXValueGetValue(rangeValue, .cfRange, &range) { cursor = min(max(range.location, 0), cursor) }
        }
        let end = String.Index(utf16Offset: cursor, in: value)
        let text = value[..<end].suffix(maximumLength).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func attribute<T>(_ name: String, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
