import AppKit
import UniformTypeIdentifiers

/// Owns the prompter panel and everything that happens in it.
final class PrompterController: NSObject {
    static let wpmRange: ClosedRange<Double> = 40...400
    static let fontRange: ClosedRange<Double> = 14...120

    let panel = PrompterPanel()
    let view: PrompterView
    /// Called whenever play state or settings change, so menus can refresh.
    var onChange: (() -> Void)?

    private(set) var isPlaying = false
    private(set) var words = 0
    /// Direction of a held scroll shortcut (+1, -1 or 0) and how long it's been held.
    private var nudge: CGFloat = 0
    private var nudgeHeld = 0.0
    /// Scroll offset with sub-pixel precision; the view snaps what we hand it to pixels.
    private var position: CGFloat = 0
    private var lastApplied: CGFloat = 0
    private var sinceHUDUpdate = 0.0
    private lazy var link = DisplayLink { [weak self] dt in self?.step(dt) }

    /// Talk time. Starts on the first play, keeps going through pauses, stops at the end.
    private var elapsedBefore = 0.0
    private var runningSince: CFTimeInterval?
    private var clock: Timer?
    private var countdownTimer: Timer?
    private var countdownLeft = 0

    override init() {
        view = PrompterView(frame: NSRect(origin: .zero, size: panel.frame.size))
        super.init()
        panel.contentView = view
        view.canvas.onScroll = { [weak self] dy in self?.scrollBy(dy) }
        view.canvas.onDoubleClick = { [weak self] in self?.beginEditing() }
        view.textView.onEscape = { [weak self] in self?.endEditing() }
        view.onDropFile = { [weak self] url in self?.load(url) }
        view.onDropText = { [weak self] text in self?.replaceScript(with: text) }
        applyPrefs()
        setScript(Script.load())
    }

    /// Hooks the toolbar buttons up. `menu` shows the settings menu under a button.
    func connectToolbar(menu: @escaping (NSView) -> Void) {
        view.toolbar.actions = ToolbarActions(
            restart: { [weak self] in self?.restart() },
            togglePlay: { [weak self] in self?.togglePlay() },
            slower: { [weak self] in self?.changeSpeed(by: -10) },
            faster: { [weak self] in self?.changeSpeed(by: 10) },
            smaller: { [weak self] in self?.changeFontSize(by: -2) },
            bigger: { [weak self] in self?.changeFontSize(by: 2) },
            edit: { [weak self] in self?.beginEditing() },
            menu: menu,
            hide: { [weak self] in self?.hide() },
            open: { [weak self] in self?.openScript() },
            done: { [weak self] in self?.endEditing() }
        )
        changed()
    }

    /// Refreshes anything that mirrors playback state.
    private func changed() {
        view.toolbar.update(playing: isPlaying || isCountingDown, wpm: Int(Prefs.wpm))
        onChange?()
    }

    func applyPrefs() {
        panel.sharingType = Prefs.hideFromCapture ? .none : .readOnly
        view.opacity = Prefs.opacity
        view.blursBackground = Prefs.blur
        view.mirrored = Prefs.mirror
        view.showsGuide = Prefs.guide
        view.setStyle(fontSize: Prefs.fontSize, centered: Prefs.centered)
        updateHUD()
    }

    func setScript(_ text: String) {
        view.text = text
        words = Script.wordCount(text)
        restart()
    }

    func show() {
        panel.orderFrontRegardless()
        changed()
    }

    func hide() {
        pause()
        panel.orderOut(nil)
        changed()
    }

    // MARK: Editing

    var isEditing: Bool { view.isEditing }

    /// Swaps in the editable text view with the caret on the line you were reading.
    func beginEditing() {
        guard !view.isEditing else { return }
        pause()
        let index = view.characterAtGuide
        view.isEditing = true
        NSApp.activate(ignoringOtherApps: true)
        show()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view.textView)
        let caret = NSRange(location: min(index, view.storage.length), length: 0)
        view.textView.setSelectedRange(caret)
        view.textView.scrollRangeToVisible(caret)
        changed()
    }

    func endEditing() {
        guard view.isEditing else { return }
        let caret = view.textView.selectedRange().location
        view.isEditing = false
        view.restyle()
        words = Script.wordCount(view.text)
        Script.save(view.text)
        view.scroll(toCharacter: caret)
        panel.makeFirstResponder(nil)
        NSApp.deactivate()
        updateHUD()
        changed()
    }

    func openScript() {
        NSApp.activate(ignoringOtherApps: true)
        let open = NSOpenPanel()
        open.message = "Choose a script"
        open.allowedContentTypes = [.plainText, .rtf, .rtfd, .html]
            + ["md", "docx", "doc", "odt"].compactMap { UTType(filenameExtension: $0) }
        guard open.runModal() == .OK, let url = open.url else { return }
        load(url)
    }

    func load(_ url: URL) {
        do {
            replaceScript(with: try Script.read(url))
            view.showToast("Opened \(url.lastPathComponent)")
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

    func replaceScript(with text: String) {
        setScript(text)
        Script.save(text)
    }

    func toggleVisible() {
        panel.isVisible ? hide() : show()
    }

    // MARK: Playback

    /// Auto-scroll speed. Words per minute is converted to points using the
    /// script's average words per point, so it holds across font sizes and widths.
    var pointsPerSecond: CGFloat {
        guard words > 0 else { return 0 }
        return CGFloat(Prefs.wpm / 60) * view.textHeight / CGFloat(words)
    }

    var isCountingDown: Bool { countdownTimer != nil }

    func togglePlay() {
        if isCountingDown { finishCountdown() } // pressing again skips the count
        else if isPlaying { pause() }
        else { play() }
    }

    func play() {
        guard !isPlaying, !isCountingDown, !isEditing else { return }
        if view.scrollY >= view.endY - 1 { restart() }
        if Prefs.countdown > 0 && view.scrollY <= view.startY + 1 && elapsed == 0 {
            countdownLeft = Prefs.countdown
            view.countdown.show(countdownLeft)
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.countdownTick()
            }
            changed()
        } else {
            beginScrolling()
        }
    }

    func pause() {
        cancelCountdown()
        guard isPlaying else { return }
        isPlaying = false
        updateLink()
        updateHUD()
        changed()
    }

    /// Back to the first line with a fresh timer.
    func restart() {
        pause()
        stopClock()
        elapsedBefore = 0
        view.scrollY = view.startY
        updateHUD()
    }

    func changeSpeed(by delta: Double) {
        setSpeed(Prefs.wpm + delta)
    }

    func setSpeed(_ wpm: Double) {
        Prefs.wpm = min(max(wpm.rounded(), Self.wpmRange.lowerBound), Self.wpmRange.upperBound)
        view.showToast("\(Int(Prefs.wpm)) wpm")
        updateHUD()
        changed()
    }

    /// Picks the speed that gets through the rest of the script in `seconds`.
    func finish(in seconds: Double) {
        guard words > 0, seconds > 0 else { return }
        let left = Double(words) * (1 - view.progress)
        setSpeed(left / (seconds / 60))
    }

    func changeFontSize(by delta: Double) {
        Prefs.fontSize = min(max(Prefs.fontSize + delta, Self.fontRange.lowerBound), Self.fontRange.upperBound)
        view.setStyle(fontSize: Prefs.fontSize, centered: Prefs.centered)
        view.showToast("\(Int(Prefs.fontSize)) pt")
        changed()
    }

    /// Hold-to-scroll: direction is +1 (forward), -1 (back) or 0 (released).
    func nudge(_ direction: CGFloat) {
        nudge = direction
        nudgeHeld = 0
        updateLink()
    }

    /// Manual scrolling from the trackpad or mouse wheel.
    func scrollBy(_ dy: CGFloat) {
        view.scrollY = min(max(view.scrollY + dy, view.startY), view.endY)
        updateHUD()
    }

    private func beginScrolling() {
        isPlaying = true
        startClock()
        updateLink()
        updateHUD()
        changed()
    }

    private func countdownTick() {
        countdownLeft -= 1
        if countdownLeft > 0 { view.countdown.show(countdownLeft) } else { finishCountdown() }
    }

    private func finishCountdown() {
        cancelCountdown()
        beginScrolling()
    }

    private func cancelCountdown() {
        guard let timer = countdownTimer else { return }
        timer.invalidate()
        countdownTimer = nil
        view.countdown.show(nil)
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

        // Holding starts at about two lines a second and speeds up to eight.
        var velocity: CGFloat = 0
        if nudge != 0 {
            nudgeHeld += dt
            velocity = nudge * view.lineHeight * CGFloat(2 + 6 * min(nudgeHeld / 1.2, 1))
        }
        if isPlaying { velocity += pointsPerSecond }
        position = min(max(position + velocity * CGFloat(dt), view.startY), view.endY)
        view.scrollY = position
        lastApplied = view.scrollY

        view.hud.progress = CGFloat(view.progress)
        sinceHUDUpdate += dt
        if sinceHUDUpdate > 0.25 { updateHUD() }

        if isPlaying && position >= view.endY {
            pause()
            stopClock()
            view.showToast("The end 🎉")
        }
    }

    // MARK: Timer

    var elapsed: Double {
        elapsedBefore + (runningSince.map { CACurrentMediaTime() - $0 } ?? 0)
    }

    private func startClock() {
        guard runningSince == nil else { return }
        runningSince = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateHUD() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    private func stopClock() {
        if let since = runningSince { elapsedBefore += CACurrentMediaTime() - since }
        runningSince = nil
        clock?.invalidate()
        clock = nil
    }

    func updateHUD() {
        sinceHUDUpdate = 0
        let hud = view.hud
        view.showsHUD = Prefs.showTimer
        guard Prefs.showTimer else { return }

        let normal = NSColor.white.withAlphaComponent(0.7)
        let t = elapsed, talk = Prefs.talkLength, progress = view.progress
        let left = words > 0 ? Double(words) * (1 - progress) / Prefs.wpm * 60 : 0

        var elapsedText = formatTime(t.rounded(.down))
        var elapsedColor = normal
        if talk > 0 {
            elapsedText += " / " + formatTime(talk)
            if t > talk { elapsedColor = .systemRed } else if t > talk * 0.9 { elapsedColor = .systemYellow }
        }
        let pace = progress >= 1 ? "done" : formatTime(left) + " left"
        // Orange when finishing at this speed would run past the talk length.
        let late = talk > 0 && progress < 1 && t + left > talk + 1
        hud.elapsed.setIfChanged(elapsedText, color: elapsedColor)
        hud.remaining.setIfChanged("\(Int(Prefs.wpm)) wpm · \(pace)", color: late ? .systemOrange : normal)
        hud.progress = CGFloat(progress)
    }
}
