import AppKit

/// Owns the prompter panel and everything that happens in it.
final class PrompterController: NSObject {
    static let wpmRange: ClosedRange<Double> = 40...400

    let panel = PrompterPanel()
    let view: PrompterView

    private(set) var isPlaying = false
    private var words = 0
    /// Extra velocity (points/s) while a scroll shortcut is held down.
    private var nudge: CGFloat = 0
    /// Scroll offset with sub-pixel precision; the clip view rounds what we hand it.
    private var position: CGFloat = 0
    private var lastApplied: CGFloat = 0
    private lazy var link = DisplayLink { [weak self] dt in self?.step(dt) }

    override init() {
        view = PrompterView(frame: NSRect(origin: .zero, size: panel.frame.size))
        super.init()
        panel.contentView = view
        view.canvas.onScroll = { [weak self] dy in self?.scrollBy(dy) }
        applyPrefs()
        setScript(Script.load())
    }

    func applyPrefs() {
        panel.sharingType = Prefs.hideFromCapture ? .none : .readOnly
        view.opacity = Prefs.opacity
        view.showsGuide = Prefs.guide
        view.setStyle(fontSize: Prefs.fontSize, centered: Prefs.centered)
    }

    func setScript(_ text: String) {
        view.text = text
        words = Script.wordCount(text)
        restart()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    // MARK: Playback

    /// Auto-scroll speed. Words per minute is converted to points using the
    /// script's average words per point, so it holds across font sizes and widths.
    var pointsPerSecond: CGFloat {
        guard words > 0 else { return 0 }
        return CGFloat(Prefs.wpm / 60) * view.textHeight / CGFloat(words)
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        if view.scrollY >= view.endY - 1 { view.scrollY = view.startY }
        isPlaying = true
        updateLink()
    }

    func pause() {
        isPlaying = false
        updateLink()
    }

    func restart() {
        pause()
        view.scrollY = view.startY
    }

    func changeSpeed(by delta: Double) {
        Prefs.wpm = min(max(Prefs.wpm + delta, Self.wpmRange.lowerBound), Self.wpmRange.upperBound)
    }

    /// Hold-to-scroll: direction is +1 (forward), -1 (back) or 0 (released).
    func nudge(_ direction: CGFloat) {
        nudge = direction * max(view.lineHeight * 5, 120)
        updateLink()
    }

    /// Manual scrolling from the trackpad or mouse wheel.
    func scrollBy(_ dy: CGFloat) {
        view.scrollY = min(max(view.scrollY + dy, view.startY), view.endY)
    }

    private func updateLink() {
        if isPlaying || nudge != 0 {
            position = view.scrollY
            lastApplied = position
            link.start()
        } else {
            link.stop()
        }
    }

    private func step(_ dt: Double) {
        let actual = view.scrollY
        if abs(actual - lastApplied) > 0.75 { position = actual } // trackpad scrolled meanwhile

        var velocity = nudge
        if isPlaying { velocity += pointsPerSecond }
        position = min(max(position + velocity * CGFloat(dt), view.startY), view.endY)
        view.scrollY = position
        lastApplied = view.scrollY

        if isPlaying && position >= view.endY { pause() }
    }
}
