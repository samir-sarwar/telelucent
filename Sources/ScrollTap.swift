import AppKit
import ApplicationServices

/// Optional: hold the shortcut modifiers and scroll anywhere to move the prompter.
///
/// The scroll events are swallowed, so whatever is under the pointer (the window
/// you're sharing, say) doesn't move. Swallowing input needs an active event tap,
/// and that needs Accessibility permission, so this is off unless turned on.
final class ScrollTap {
    static let shared = ScrollTap()

    var onScroll: ((CGFloat) -> Void)?
    var modifiers: CGEventFlags = [.maskControl, .maskShift]

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Keeps momentum scrolling with the prompter after the keys are let go.
    private var capturing = false

    var isRunning: Bool { tap != nil }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to Privacy & Security › Accessibility.
    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: { _, type, event, _ in ScrollTap.shared.handle(type, event) },
                                          userInfo: nil) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        capturing = false
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let relevant: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
        let held = event.flags.intersection(relevant) == modifiers
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        if held { capturing = true } else if !momentum { capturing = false }
        guard capturing else { return Unmanaged.passUnretained(event) }

        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        var dy: Double
        if continuous {
            dy = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            // Shift turns a vertical scroll into a horizontal one on some devices.
            if dy == 0 { dy = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2) }
        } else {
            var lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            if lines == 0 { lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis2) }
            dy = Double(lines) * 16
        }
        onScroll?(CGFloat(-dy))
        return nil
    }
}
