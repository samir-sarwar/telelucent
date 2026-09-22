import AppKit

/// Floating, non-activating panel. Clicking or scrolling it never pulls focus away
/// from the app you're presenting, and it is left out of screen capture.
final class PrompterPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 640, height: 220),
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        minSize = NSSize(width: 260, height: 120)
        sharingType = .none

        if !setFrameUsingName("Prompter") { moveToTopCenter() }
        setFrameAutosaveName("Prompter")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Parks the panel just under the menu bar, which is where the camera is on a laptop.
    func moveToTopCenter() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        var f = frame
        f.origin.x = vf.midX - f.width / 2
        f.origin.y = vf.maxY - f.height - 6
        setFrame(f, display: true)
    }
}
