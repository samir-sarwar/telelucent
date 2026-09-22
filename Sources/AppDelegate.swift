import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prompter: PrompterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        prompter = PrompterController()
        prompter.show()
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
            default: break
            }
        }
    }
}
