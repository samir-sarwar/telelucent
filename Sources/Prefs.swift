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
}
