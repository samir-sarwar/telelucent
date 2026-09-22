import Foundation

/// A UserDefaults-backed value that registers its own default.
@propertyWrapper
struct Pref<T> {
    let key: String

    init(wrappedValue: T, _ key: String) {
        self.key = key
        UserDefaults.standard.register(defaults: [key: wrappedValue])
    }

    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as! T }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum Prefs {
    @Pref("fontSize") static var fontSize: Double = 34
    @Pref("wpm") static var wpm: Double = 140
    @Pref("opacity") static var opacity: Double = 0.6
    @Pref("centered") static var centered = false
    @Pref("guide") static var guide = true
    @Pref("hideFromCapture") static var hideFromCapture = true
    @Pref("showTimer") static var showTimer = true
    @Pref("hotkeys") static var hotkeys = true
    @Pref("hotkeyModifiers") static var hotkeyModifiersRaw = 0
    static var hotkeyModifiers: ShortcutModifiers {
        get { ShortcutModifiers(rawValue: hotkeyModifiersRaw) ?? .controlShift }
        set { hotkeyModifiersRaw = newValue.rawValue }
    }
    /// Seconds of 3·2·1 before scrolling starts from the top. 0 turns it off.
    @Pref("countdown") static var countdown = 3
    /// Planned length of the talk in seconds, 0 for none.
    @Pref("talkLength") static var talkLength: Double = 0
}
