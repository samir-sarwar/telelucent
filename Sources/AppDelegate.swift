import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prompter: PrompterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        prompter = PrompterController()
        prompter.show()
    }
}
