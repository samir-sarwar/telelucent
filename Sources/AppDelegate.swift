import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prompter: PrompterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        prompter = PrompterController()
        registerHotKeys()
        prompter.show()
    }

    func registerHotKeys() {
        guard Prefs.hotkeys else { return HotKeys.shared.unregisterAll() }
        let p = prompter!
        func tap(_ action: @escaping () -> Void) -> (Bool) -> Void {
            { pressed in if pressed { action() } }
        }
        HotKeys.shared.register([
            .init(keyCode: kVK_ANSI_P, handler: tap { p.togglePlay() }),
            .init(keyCode: kVK_DownArrow) { p.nudge($0 ? 1 : 0) },
            .init(keyCode: kVK_UpArrow) { p.nudge($0 ? -1 : 0) },
            .init(keyCode: kVK_RightArrow, repeats: true, handler: tap { p.changeSpeed(by: 10) }),
            .init(keyCode: kVK_LeftArrow, repeats: true, handler: tap { p.changeSpeed(by: -10) }),
            .init(keyCode: kVK_ANSI_Equal, repeats: true, handler: tap { p.changeFontSize(by: 2) }),
            .init(keyCode: kVK_ANSI_Minus, repeats: true, handler: tap { p.changeFontSize(by: -2) }),
            .init(keyCode: kVK_ANSI_R, handler: tap { p.restart() }),
            .init(keyCode: kVK_ANSI_H, handler: tap { p.toggleVisible() }),
        ], modifiers: Prefs.hotkeyModifiers.carbon)
    }

    /// telelucent://play, /pause, /toggle, /restart, /faster, /slower – handy for
    /// Shortcuts or a Stream Deck. Use `open -g` so the app isn't brought forward.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "telelucent" {
            switch url.host ?? "" {
            case "play": prompter.play()
            case "pause": prompter.pause()
            case "toggle": prompter.togglePlay()
            case "restart": prompter.restart()
            case "faster": prompter.changeSpeed(by: 10)
            case "slower": prompter.changeSpeed(by: -10)
            case "bigger": prompter.changeFontSize(by: 2)
            case "smaller": prompter.changeFontSize(by: -2)
            case "show": prompter.show()
            case "hide": prompter.hide()
            default: break
            }
        }
    }
}
