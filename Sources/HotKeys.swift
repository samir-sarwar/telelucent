import AppKit
import Carbon.HIToolbox

/// Which modifier combo the global shortcuts use.
enum ShortcutModifiers: Int, CaseIterable {
    case controlShift, controlOption, controlOptionCommand

    var carbon: UInt32 {
        switch self {
        case .controlOption: return UInt32(controlKey | optionKey)
        case .controlShift: return UInt32(controlKey | shiftKey)
        case .controlOptionCommand: return UInt32(controlKey | optionKey | cmdKey)
        }
    }

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .controlOption: return [.control, .option]
        case .controlShift: return [.control, .shift]
        case .controlOptionCommand: return [.control, .option, .command]
        }
    }

    var eventFlags: CGEventFlags {
        switch self {
        case .controlOption: return [.maskControl, .maskAlternate]
        case .controlShift: return [.maskControl, .maskShift]
        case .controlOptionCommand: return [.maskControl, .maskAlternate, .maskCommand]
        }
    }

    var symbols: String {
        switch self {
        case .controlOption: return "⌃⌥"
        case .controlShift: return "⌃⇧"
        case .controlOptionCommand: return "⌃⌥⌘"
        }
    }
}

/// System-wide shortcuts through Carbon's RegisterEventHotKey. Unlike an NSEvent
/// monitor this needs no Accessibility permission, and it fires no matter which app
/// is in front, so the prompter can be driven without ever touching it.
final class HotKeys {
    struct Binding {
        let keyCode: Int
        /// Whether holding the key should keep firing (speed, size) or not (play/pause).
        var repeats = false
        let handler: (_ pressed: Bool) -> Void
    }

    static let shared = HotKeys()

    private var refs: [EventHotKeyRef] = []
    private var bindings: [UInt32: Binding] = [:]
    private var held: Set<UInt32> = []
    private var handlerInstalled = false

    func register(_ list: [Binding], modifiers: UInt32) {
        unregisterAll()
        installHandler()
        for (i, binding) in list.enumerated() {
            let id = UInt32(i + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(binding.keyCode), modifiers,
                                             EventHotKeyID(signature: 0x544C_4354, id: id), // 'TLCT'
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
                bindings[id] = binding
            }
        }
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        bindings.removeAll()
        held.removeAll()
    }

    private func handle(id: UInt32, pressed: Bool) {
        guard let binding = bindings[id] else { return }
        if pressed {
            if held.contains(id) && !binding.repeats { return }
            held.insert(id)
        } else {
            held.remove(id)
        }
        binding.handler(pressed)
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            HotKeys.shared.handle(id: id.id, pressed: pressed)
            return noErr
        }, types.count, &types, nil, nil)
    }
}
