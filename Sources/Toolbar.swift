import AppKit

/// Borderless symbol button that works on the first click even though the panel
/// never becomes key.
final class ToolButton: NSButton {
    private var handler: () -> Void = {}

    convenience init(symbol: String, tip: String, _ handler: @escaping () -> Void) {
        self.init(frame: NSRect(x: 0, y: 0, width: 28, height: 26))
        self.handler = handler
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = .white
        refusesFirstResponder = true
        toolTip = tip
        target = self
        action = #selector(fire)
        setSymbol(symbol)
    }

    convenience init(title: String, _ handler: @escaping () -> Void) {
        self.init(symbol: "", tip: title, handler)
        imagePosition = .noImage
        attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        ])
        frame.size.width = ceil(attributedTitle.size().width) + 16
    }

    func setSymbol(_ name: String) {
        guard !name.isEmpty else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        image = NSImage(systemSymbolName: name, accessibilityDescription: toolTip)?.withSymbolConfiguration(config)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func fire() { handler() }
}

/// Controls the toolbar can trigger. Kept as closures so the view stays dumb.
struct ToolbarActions {
    var restart: () -> Void = {}
    var togglePlay: () -> Void = {}
    var slower: () -> Void = {}
    var faster: () -> Void = {}
    var smaller: () -> Void = {}
    var bigger: () -> Void = {}
    var edit: () -> Void = {}
    var menu: (NSView) -> Void = { _ in }
    var hide: () -> Void = {}
    var open: () -> Void = {}
    var done: () -> Void = {}
}

/// Pill of controls along the top edge, shown while the pointer is over the prompter.
final class ToolbarView: NSView {
    var actions = ToolbarActions() { didSet { rebuild() } }
    var isEditing = false { didSet { if isEditing != oldValue { rebuild() } } }

    private var playButton: ToolButton?
    private let speedLabel = makeLabel(size: 11, weight: .semibold, mono: true)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        speedLabel.alignment = .center
        speedLabel.textColor = .white
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Invisible means gone: don't swallow clicks while faded out.
    override func hitTest(_ point: NSPoint) -> NSView? { alphaValue > 0.5 ? super.hitTest(point) : nil }

    func update(playing: Bool, wpm: Int) {
        playButton?.setSymbol(playing ? "pause.fill" : "play.fill")
        speedLabel.setIfChanged("\(wpm)")
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }
        let a = actions
        var views: [NSView]
        if isEditing {
            views = [
                ToolButton(symbol: "folder", tip: "Open a script file", a.open),
                ToolButton(title: "Done", a.done),
            ]
            playButton = nil
        } else {
            let play = ToolButton(symbol: "play.fill", tip: "Play / pause", a.togglePlay)
            playButton = play
            speedLabel.frame.size = NSSize(width: 30, height: 14)
            speedLabel.toolTip = "Words per minute"
            views = [
                ToolButton(symbol: "backward.end.fill", tip: "Back to top", a.restart),
                play,
                ToolButton(symbol: "tortoise.fill", tip: "Slower", a.slower),
                speedLabel,
                ToolButton(symbol: "hare.fill", tip: "Faster", a.faster),
                ToolButton(symbol: "textformat.size.smaller", tip: "Smaller text", a.smaller),
                ToolButton(symbol: "textformat.size.larger", tip: "Bigger text", a.bigger),
                ToolButton(symbol: "pencil", tip: "Edit script", a.edit),
            ]
            let more = ToolButton(symbol: "ellipsis.circle", tip: "Settings", {})
            more.target = self
            more.action = #selector(showMenu(_:))
            views += [more, ToolButton(symbol: "eye.slash", tip: "Hide (bring back from the menu bar)", a.hide)]
        }

        var x: CGFloat = 6
        let h: CGFloat = 28
        for v in views {
            v.frame.origin = NSPoint(x: x, y: (h - v.frame.height) / 2)
            addSubview(v)
            x += v.frame.width + 2
        }
        setFrameSize(NSSize(width: x + 4, height: h))
        layer?.cornerRadius = h / 2
    }

    @objc private func showMenu(_ sender: NSView) {
        actions.menu(sender)
    }
}

/// Corner handle for resizing, in case the window edges are hard to grab.
final class ResizeGrip: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { alphaValue > 0.5 ? super.hitTest(point) : nil }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        for i in 0..<3 {
            let d = CGFloat(i) * 4 + 4
            path.move(to: NSPoint(x: bounds.maxX - d, y: bounds.maxY - 2))
            path.line(to: NSPoint(x: bounds.maxX - 2, y: bounds.maxY - d))
        }
        path.lineWidth = 1.2
        path.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.55).setStroke()
        path.stroke()
    }

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let start = NSEvent.mouseLocation
        let original = window.frame
        while let e = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), e.type != .leftMouseUp {
            let now = NSEvent.mouseLocation
            var f = original
            f.size.width = max(window.minSize.width, original.width + now.x - start.x)
            f.size.height = max(window.minSize.height, original.height - (now.y - start.y))
            f.origin.y = original.maxY - f.height
            window.setFrame(f, display: true)
        }
    }
}
