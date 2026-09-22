import AppKit

/// Small labels drawn on top of the script. None of them take mouse clicks, so
/// dragging anywhere still moves the window.
class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

func makeLabel(size: CGFloat, weight: NSFont.Weight = .medium, mono: Bool = false) -> NSTextField {
    let label = NSTextField(labelWithString: "")
    label.font = mono ? .monospacedDigitSystemFont(ofSize: size, weight: weight) : .systemFont(ofSize: size, weight: weight)
    label.textColor = NSColor.white.withAlphaComponent(0.7)
    label.lineBreakMode = .byClipping
    return label
}

extension NSTextField {
    /// Only touches the field when the text actually changes, to avoid needless redraws.
    func setIfChanged(_ text: String, color: NSColor? = nil) {
        if stringValue != text { stringValue = text }
        if let color, textColor != color { textColor = color }
    }
}

/// Timer strip along the bottom edge: elapsed on the left, pace on the right, a progress line underneath.
final class HUDView: PassthroughView {
    let elapsed = makeLabel(size: 11, mono: true)
    let remaining = makeLabel(size: 11, mono: true)
    private let track = NSView()
    private let fill = NSView()
    private var fraction: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        remaining.alignment = .right
        for bar in [track, fill] {
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 1
        }
        track.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        fill.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.55).cgColor
        [elapsed, remaining, track, fill].forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    var progress: CGFloat {
        get { fraction }
        set {
            let width = (track.frame.width * newValue).rounded()
            fraction = newValue
            if fill.frame.width != width { fill.frame.size.width = width }
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let w = newSize.width
        elapsed.frame = NSRect(x: 0, y: 0, width: w / 2, height: 16)
        remaining.frame = NSRect(x: w / 2, y: 0, width: w / 2, height: 16)
        track.frame = NSRect(x: 0, y: newSize.height - 2, width: w, height: 2)
        fill.frame = NSRect(x: 0, y: newSize.height - 2, width: (w * fraction).rounded(), height: 2)
    }
}

/// A pill that briefly shows what a shortcut just did ("150 wpm", "Paused" …).
final class ToastView: PassthroughView {
    private let label = makeLabel(size: 13, weight: .semibold)
    private var hideWork: DispatchWorkItem?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        label.textColor = .white
        label.alignment = .center
        addSubview(label)
        alphaValue = 0
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ text: String, in parent: NSRect) {
        label.stringValue = text
        let size = label.intrinsicContentSize
        let w = ceil(size.width) + 24, h: CGFloat = 26
        frame = NSRect(x: (parent.width - w) / 2, y: parent.height - h - 30, width: w, height: h)
        layer?.cornerRadius = h / 2
        label.frame = NSRect(x: 12, y: (h - size.height) / 2, width: w - 24, height: size.height)
        alphaValue = 1
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                self?.animator().alphaValue = 0
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
    }
}

/// Big 3 · 2 · 1 before the text starts moving.
final class CountdownView: PassthroughView {
    private let label = makeLabel(size: 64, weight: .bold, mono: true)

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.textColor = .white
        label.alignment = .center
        addSubview(label)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ value: Int?) {
        isHidden = value == nil
        guard let value else { return }
        let size = min(72, max(28, bounds.height * 0.4))
        label.font = .monospacedDigitSystemFont(ofSize: size, weight: .bold)
        label.stringValue = "\(value)"
        let h = label.intrinsicContentSize.height
        label.frame = NSRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let d = label.frame.height * 1.25
        let disc = NSRect(x: bounds.midX - d / 2, y: bounds.midY - d / 2, width: d, height: d)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(ovalIn: disc).fill()
    }
}

func formatTime(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded()))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                     : String(format: "%d:%02d", s / 60, s % 60)
}
