import Carbon.HIToolbox
import Testing
@testable import Stenographer

@MainActor
struct PasterTests {
    /// Finds an installed keyboard layout by its ID, also when the user has not turned it on.
    private func layout(_ id: String) throws -> TISInputSource {
        let filter = [kTISPropertyInputSourceID: id] as CFDictionary
        let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
        return try #require(list?.first, "no layout \(id)")
    }

    @Test(arguments: [
        ("com.apple.keylayout.US", 9),
        ("com.apple.keylayout.German", 9),
        ("com.apple.keylayout.French", 9),
        ("com.apple.keylayout.Colemak", 9),
        // Dvorak types "v" with the key that is "." on QWERTY.
        ("com.apple.keylayout.Dvorak", 47),
        // This layout uses QWERTY while ⌘ is held.
        ("com.apple.keylayout.DVORAK-QWERTYCMD", 9),
    ])
    func commandVKey(layoutID: String, expected: Int) throws {
        #expect(Paster.commandVKey(in: try layout(layoutID)) == CGKeyCode(expected))
    }
}
