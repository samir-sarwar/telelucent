import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PrompterPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PrompterPanel()
        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        bg.layer?.cornerRadius = 14
        panel.contentView = bg
        panel.orderFrontRegardless()
    }
}
