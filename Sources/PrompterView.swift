import AppKit

/// Everything inside the prompter panel: the tinted background, the script and the reading guide.
final class PrompterView: NSView {
    static let cornerRadius: CGFloat = 14
    /// Where the line being read sits, as a fraction of the height from the top.
    static let guideFraction: CGFloat = 0.33

    let storage = NSTextStorage()
    let scrollView = NSScrollView()
    let canvas: TextCanvas
    let textView: PromptTextView
    private let fadeView = NSView()
    private let fadeMask = CAGradientLayer()
    private let guideView = GuideView()
    let hud = HUDView()
    let countdown = CountdownView()
    private let toast = ToastView()
    private(set) var lineHeight: CGFloat = 40

    var opacity: CGFloat = 0.6 { didSet { needsDisplay = true } }
    var showsGuide = true { didSet { guideView.isHidden = !showsGuide || isEditing } }
    var showsHUD = true {
        didSet {
            guard showsHUD != oldValue else { return }
            hud.isHidden = !showsHUD
            layoutContents()
        }
    }

    /// While editing, the real text view replaces the tiled canvas.
    var isEditing = false {
        didSet {
            guard isEditing != oldValue else { return }
            textView.isEditable = isEditing
            textView.isSelectable = isEditing
            scrollView.isHidden = !isEditing
            canvas.isHidden = isEditing
            guideView.isHidden = !showsGuide || isEditing
            layoutContents()
        }
    }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        canvas = TextCanvas(storage: storage)

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
        textView.textContainerInset = NSSize(width: canvas.inset, height: 0)
        textView.insertionPointColor = .white

        scrollView.documentView = textView
        scrollView.isHidden = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 44, left: 0, bottom: 30, right: 0)

        fadeView.wantsLayer = true
        fadeView.layer?.mask = fadeMask
        fadeView.addSubview(canvas)
        fadeView.addSubview(scrollView)
        addSubview(fadeView)
        addSubview(guideView)
        addSubview(hud)
        addSubview(countdown)
        addSubview(toast)
    }

    func showToast(_ text: String) {
        toast.show(text, in: bounds)
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
        get { storage.string }
        set {
            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: newValue)
            restyle()
        }
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
        let keep = progress
        storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
        lineHeight = canvas.layoutManager.defaultLineHeight(for: font) * para.lineHeightMultiple
        canvas.layoutText()
        layoutContents()
        scrollY = startY + CGFloat(keep) * (endY - startY)
    }

    // MARK: Geometry

    /// The script area stops above the timer strip so the two never overlap.
    private var textAreaHeight: CGFloat { max(40, bounds.height - (showsHUD ? 24 : 0)) }
    private var guideY: CGFloat { (textAreaHeight * Self.guideFraction).rounded() }

    var textHeight: CGFloat { canvas.textHeight }

    /// Scroll offset with the first line on the guide.
    var startY: CGFloat { lineHeight / 2 - guideY }
    /// Scroll offset with the last line on the guide.
    var endY: CGFloat { max(startY, textHeight - lineHeight / 2 - guideY) }

    /// Scroll position of the prompting view, snapped to whole device pixels.
    var scrollY: CGFloat {
        get { canvas.offset }
        set {
            let scale = window?.backingScaleFactor ?? 2
            canvas.offset = (newValue * scale).rounded() / scale
        }
    }

    /// 0 at the first line, 1 at the last.
    var progress: Double {
        let span = endY - startY
        return span > 0 ? Double(min(max((scrollY - startY) / span, 0), 1)) : 0
    }

    func layoutContents() {
        let b = bounds
        let keep = progress
        fadeView.frame = NSRect(x: 0, y: 0, width: b.width, height: textAreaHeight)
        canvas.frame = fadeView.bounds
        scrollView.frame = fadeView.bounds
        textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: textView.frame.height))
        scrollY = startY + CGFloat(keep) * (endY - startY)

        guideView.frame = NSRect(x: 0, y: guideY - lineHeight / 2, width: b.width, height: lineHeight)
        hud.frame = NSRect(x: 16, y: b.height - 23, width: b.width - 32, height: 19)
        countdown.frame = b

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fadeMask.frame = fadeView.bounds
        let fade = Double(min(46, fadeView.bounds.height * 0.2) / max(fadeView.bounds.height, 1))
        fadeMask.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        fadeMask.locations = [0, NSNumber(value: fade), NSNumber(value: 1 - fade), 1]
        CATransaction.commit()
    }
}

/// The editable version of the script, only on screen while editing.
final class PromptTextView: NSTextView {
    var onEscape: (() -> Void)?

    override func cancelOperation(_ sender: Any?) { onEscape?() }
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
