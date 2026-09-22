import AppKit

/// Read-only rendering of the script used while prompting.
///
/// Scrolling a text view makes AppKit re-record and repaint glyphs on every step,
/// which adds up at 60–120 fps. Here the text is rendered once into fixed-height
/// bitmap tiles held by plain CALayers, and only the tiles around the visible area
/// exist at any time. Scrolling changes a single transform, so it's nearly free.
final class TextCanvas: NSView {
    static let tileHeight: CGFloat = 256

    let layoutManager = NSLayoutManager()
    let container = NSTextContainer()
    var inset: CGFloat = 22
    var onDoubleClick: (() -> Void)?
    /// Called with a delta in points when the user scrolls with a trackpad or wheel.
    var onScroll: ((CGFloat) -> Void)?

    private let host = CALayer()
    private var tiles: [Int: CALayer] = [:]
    private var renderedWidth: CGFloat = -1
    private(set) var textHeight: CGFloat = 0

    /// Distance the text has been scrolled up, in points.
    var offset: CGFloat = 0 {
        didSet { if offset != oldValue { place() } }
    }

    /// Flip left-to-right, for reading off teleprompter glass.
    var mirrored = false {
        didSet { if mirrored != oldValue { place() } }
    }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(storage: NSTextStorage) {
        super.init(frame: .zero)
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        host.masksToBounds = true
        host.actions = ["sublayerTransform": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer = host // layer-hosting: AppKit leaves the tiles alone
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onDoubleClick?(); return }
        window?.performDrag(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        var dy = event.scrollingDeltaY
        if !event.hasPreciseScrollingDeltas { dy *= 16 }
        onScroll?(-dy)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if newSize.width != renderedWidth { layoutText() } else { place() }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        dropTiles()
        place()
    }

    /// Re-flows the text (after the text, style or width changed) and redraws tiles as needed.
    func layoutText() {
        renderedWidth = bounds.width
        container.size = NSSize(width: max(1, bounds.width - inset * 2), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        textHeight = ceil(layoutManager.usedRect(for: container).height)
        dropTiles()
        place()
    }

    /// Character index of the line sitting at `y` (view coordinates).
    func characterIndex(atViewY y: CGFloat) -> Int {
        let point = NSPoint(x: 1, y: max(0, y + offset))
        let glyph = layoutManager.glyphIndex(for: point, in: container)
        return layoutManager.characterIndexForGlyph(at: glyph)
    }

    /// Vertical middle of the line containing `index`, in text coordinates.
    func lineMidY(forCharacter index: Int) -> CGFloat {
        guard layoutManager.numberOfGlyphs > 0 else { return 0 }
        let glyph = min(layoutManager.glyphIndexForCharacter(at: index), layoutManager.numberOfGlyphs - 1)
        return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).midY
    }

    private func dropTiles() {
        tiles.values.forEach { $0.removeFromSuperlayer() }
        tiles.removeAll()
    }

    /// Moves the text to `offset`, creating tiles that are about to be seen and dropping far ones.
    private func place() {
        let h = Self.tileHeight
        let height = bounds.height
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // AppKit flips the hosting layer to match the view, but don't count on it.
        let flipped = host.isGeometryFlipped
        var transform = CATransform3DMakeTranslation(0, flipped ? -offset : offset, 0)
        if mirrored {
            // Sublayer transforms pivot on the anchor point, so flip around the middle from there.
            let center = bounds.width * (0.5 - host.anchorPoint.x)
            transform = CATransform3DConcat(transform, CATransform3DConcat(CATransform3DMakeScale(-1, 1, 1),
                                                                         CATransform3DMakeTranslation(center * 2, 0, 0)))
        }
        host.sublayerTransform = transform

        if textHeight > 0 && height > 0 {
            let margin = h / 2
            let last = Int((textHeight - 1) / h)
            let lo = max(0, Int(floor((offset - margin) / h)))
            let hi = min(last, Int(floor((offset + height + margin) / h)))
            for (i, tile) in tiles where i < lo || i > hi {
                tile.removeFromSuperlayer()
                tiles[i] = nil
            }
            if lo <= hi {
                for i in lo...hi {
                    let tile = tiles[i] ?? makeTile(i)
                    let y = flipped ? CGFloat(i) * h : height - CGFloat(i + 1) * h
                    tile.frame = CGRect(x: 0, y: y, width: bounds.width, height: h)
                }
            }
        }
        CATransaction.commit()
    }

    private func makeTile(_ i: Int) -> CALayer {
        let h = Self.tileHeight
        let scale = window?.backingScaleFactor ?? 2
        let tile = CALayer()
        tile.contentsScale = scale
        tiles[i] = tile
        host.addSublayer(tile)

        let pw = Int(ceil(bounds.width * scale)), ph = Int(ceil(h * scale))
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                      | CGBitmapInfo.byteOrder32Little.rawValue) else { return tile }
        // Flip to match text layout (y down) and shift so this tile's slice lands at the top.
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.translateBy(x: 0, y: -CGFloat(i) * h)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        let origin = NSPoint(x: inset, y: 0)
        // Pad so shadows of glyphs just outside the tile still get drawn.
        let slice = NSRect(x: 0, y: CGFloat(i) * h - 12, width: bounds.width, height: h + 24)
        let glyphs = layoutManager.glyphRange(forBoundingRect: slice.offsetBy(dx: -origin.x, dy: 0), in: container)
        layoutManager.drawGlyphs(forGlyphRange: glyphs, at: origin)
        NSGraphicsContext.restoreGraphicsState()

        tile.contents = ctx.makeImage()
        return tile
    }
}
