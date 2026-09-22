import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prompter: PrompterController!
    private var statusMenu: StatusMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        prompter = PrompterController()
        statusMenu = StatusMenu(prompter: prompter)
        statusMenu.onShortcutsChanged = { [weak self] in self?.registerHotKeys() }
        registerHotKeys()
        prompter.show()
    }

    /// There's no menu bar while running as an accessory, but the key equivalents
    /// still need to exist for copy, paste and undo to work while editing.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Telelucent", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        for menu in [appMenu, edit] {
            let item = NSMenuItem()
            item.submenu = menu
            main.addItem(item)
        }
        return main
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
