import AppKit

/// Owns the prompter panel and everything that happens in it.
final class PrompterController: NSObject {
    let panel = PrompterPanel()
    let view: PrompterView

    override init() {
        view = PrompterView(frame: NSRect(origin: .zero, size: panel.frame.size))
        super.init()
        panel.contentView = view
        view.text = Script.load()
        applyPrefs()
        view.scrollY = view.startY
    }

    func applyPrefs() {
        panel.sharingType = Prefs.hideFromCapture ? .none : .readOnly
        view.opacity = Prefs.opacity
        view.showsGuide = Prefs.guide
        view.setStyle(fontSize: Prefs.fontSize, centered: Prefs.centered)
    }

    func show() {
        panel.orderFrontRegardless()
    }
}
