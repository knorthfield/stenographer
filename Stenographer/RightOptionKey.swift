import CoreGraphics

/// Watches the right Option key through a listen-only event tap. Needs Accessibility.
@MainActor
final class RightOptionKey {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    /// Another key was pressed while right Option was down: the user is typing a character
    /// such as ⌥3 (#), not dictating.
    var onOtherKey: () -> Void = {}

    private var tap: CFMachPort?
    private var isDown = false

    private static let keyCode: Int64 = 61
    /// `NX_DEVICERALTKEYMASK`: set while the right Option key is down.
    private static let deviceFlag = CGEventFlags(rawValue: 0x40)

    /// Does nothing if the tap is already running. Fails quietly without Accessibility, so call it again later.
    func start() {
        guard tap == nil else { return }
        let events = [CGEventType.flagsChanged, .keyDown]
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                let key = Unmanaged<RightOptionKey>.fromOpaque(userInfo!).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                // The tap's run loop source is on the main run loop.
                MainActor.assumeIsolated { key.handle(type, keyCode: keyCode, flags: flags) }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
    }

    private func handle(_ type: CGEventType, keyCode: Int64, flags: CGEventFlags) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown:
            if isDown { onOtherKey() }
        case .flagsChanged where keyCode == Self.keyCode:
            let isDownNow = flags.contains(Self.deviceFlag)
            guard isDownNow != isDown else { return }
            isDown = isDownNow
            isDown ? onPress() : onRelease()
        case .flagsChanged:
            if isDown { onOtherKey() }
        default:
            break
        }
    }
}
