import AppKit

/// Everything inside the prompter panel: the tinted background, the script and the reading guide.
final class PrompterView: NSView {
    static let cornerRadius: CGFloat = 14
    /// Where the line being read sits, as a fraction of the height from the top.
    static let guideFraction: CGFloat = 0.33

    let scrollView = NSScrollView()
    let textView: PromptTextView
    private let fadeView = NSView()
    private let fadeMask = CAGradientLayer()
    private let guideView = GuideView()
    private(set) var lineHeight: CGFloat = 40

    var opacity: CGFloat = 0.6 { didSet { needsDisplay = true } }
    var showsGuide = true { didSet { guideView.isHidden = !showsGuide } }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: frame.width, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        textView = PromptTextView(frame: NSRect(origin: .zero, size: frame.size), textContainer: container)
        super.init(frame: frame)
        wantsLayer = true

        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 22, height: 0)
        textView.insertionPointColor = .white

        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentView.postsBoundsChangedNotifications = true

        fadeView.wantsLayer = true
        fadeView.layer?.mask = fadeMask
        fadeView.addSubview(scrollView)
        addSubview(fadeView)
        addSubview(guideView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(opacity).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutContents()
    }

    var text: String {
        get { textView.string }
        set { textView.string = newValue; restyle() }
    }

    private var fontSize: CGFloat = 34
    private var centered = false

    func setStyle(fontSize: CGFloat, centered: Bool) {
        self.fontSize = fontSize
        self.centered = centered
        restyle()
    }

    private func restyle() {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let para = NSMutableParagraphStyle()
        para.lineHeightMultiple = 1.12
        para.paragraphSpacing = fontSize * 0.2
        para.alignment = centered ? .center : .natural
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.white, .paragraphStyle: para, .shadow: shadow,
        ]
        textView.typingAttributes = attrs
        textView.defaultParagraphStyle = para
        if let storage = textView.textStorage {
            storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
        }
        lineHeight = (textView.layoutManager?.defaultLineHeight(for: font) ?? fontSize * 1.2) * para.lineHeightMultiple
        layoutContents()
    }

    // MARK: Geometry

    private var guideY: CGFloat { (bounds.height * Self.guideFraction).rounded() }

    /// Height of the laid-out text.
    var textHeight: CGFloat {
        guard let lm = textView.layoutManager, let tc = textView.textContainer else { return 0 }
        lm.ensureLayout(for: tc)
        return lm.usedRect(for: tc).height
    }

    /// Scroll offset with the first line on the guide.
    var startY: CGFloat { lineHeight / 2 - guideY }
    /// Scroll offset with the last line on the guide.
    var endY: CGFloat { max(startY, textHeight - lineHeight / 2 - guideY) }

    var scrollY: CGFloat {
        get { scrollView.contentView.bounds.origin.y }
        set {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: newValue))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    /// 0 at the first line, 1 at the last.
    var progress: Double {
        let span = endY - startY
        return span > 0 ? Double(min(max((scrollY - startY) / span, 0), 1)) : 0
    }

    private func layoutContents() {
        let b = bounds
        fadeView.frame = b
        scrollView.frame = fadeView.bounds
        textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: textView.frame.height))

        let top = max(0, guideY - lineHeight / 2)
        let bottom = max(0, b.height - guideY - lineHeight / 2 + 1)
        let keep = progress
        scrollView.contentInsets = NSEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        scrollY = startY + CGFloat(keep) * (endY - startY)

        guideView.frame = NSRect(x: 0, y: guideY - lineHeight / 2, width: b.width, height: lineHeight)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fadeMask.frame = fadeView.bounds
        let fade = Double(min(46, b.height * 0.2) / max(b.height, 1))
        fadeMask.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        fadeMask.locations = [0, NSNumber(value: fade), NSNumber(value: 1 - fade), 1]
        CATransaction.commit()
    }
}

/// The script itself. Read-only unless editing; dragging it moves the window.
final class PromptTextView: NSTextView {
    var onDoubleClick: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { !isEditable }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if isEditable { return super.mouseDown(with: event) }
        if event.clickCount == 2 { onDoubleClick?(); return }
        window?.performDrag(with: event)
    }
}

/// A faint band plus a small arrow marking the line to read.
final class GuideView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.06).setFill()
        bounds.fill()
        let mid = bounds.midY
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 6, y: mid - 7))
        arrow.line(to: NSPoint(x: 14, y: mid))
        arrow.line(to: NSPoint(x: 6, y: mid + 7))
        arrow.close()
        NSColor.white.withAlphaComponent(0.85).setFill()
        arrow.fill()
    }
}
