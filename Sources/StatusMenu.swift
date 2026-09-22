import AppKit

/// NSMenuItem that runs a closure.
final class ClosureItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool = false, key: String = "",
         modifiers: NSEvent.ModifierFlags = [], _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
        state = checked ? .on : .off
        if !key.isEmpty { keyEquivalentModifierMask = modifiers }
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}

private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let menu = NSMenu(title: title)
    items.forEach(menu.addItem)
    item.submenu = menu
    return item
}

private func arrow(_ key: Int) -> String { String(Character(UnicodeScalar(UInt16(key))!)) }

/// The menu bar icon. The menu is rebuilt every time it opens so it always reflects current state.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let prompter: PrompterController
    /// Called when shortcut settings change and hot keys need re-registering.
    var onShortcutsChanged: (() -> Void)?

    init(prompter: PrompterController) {
        self.prompter = prompter
        super.init()
        let image = NSImage(systemSymbolName: "scroll", accessibilityDescription: "Telelucent")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "Telelucent"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        build().forEach(menu.addItem)
    }

    /// Same menu, popped up from the prompter's toolbar.
    func popUp(below view: NSView) {
        let menu = NSMenu()
        build().forEach(menu.addItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
    }

    private func build() -> [NSMenuItem] {
        let p = prompter
        let mods = Prefs.hotkeyModifiers.flags
        let keys = Prefs.hotkeys
        func key(_ k: String) -> String { keys ? k : "" }
        func update(_ change: () -> Void) {
            change()
            p.applyPrefs()
        }

        var items: [NSMenuItem] = [
            ClosureItem(p.isPlaying || p.isCountingDown ? "Pause" : "Play", key: key("p"), modifiers: mods) { p.togglePlay() },
            ClosureItem("Back to Top", key: key("r"), modifiers: mods) { p.restart() },
            ClosureItem(p.panel.isVisible ? "Hide Prompter" : "Show Prompter", key: key("h"), modifiers: mods) { p.toggleVisible() },
            .separator(),
            ClosureItem(p.isEditing ? "Done Editing" : "Edit Script…") { p.isEditing ? p.endEditing() : p.beginEditing() },
            ClosureItem("Open Script…") { p.openScript() },
            .separator(),
        ]

        let speeds: [NSMenuItem] = [
            ClosureItem("Faster", key: key(arrow(NSRightArrowFunctionKey)), modifiers: mods) { p.changeSpeed(by: 10) },
            ClosureItem("Slower", key: key(arrow(NSLeftArrowFunctionKey)), modifiers: mods) { p.changeSpeed(by: -10) },
            .separator(),
        ] + [100, 120, 140, 160, 180, 200].map { wpm in
            ClosureItem("\(wpm) wpm", checked: Int(Prefs.wpm) == wpm) { p.setSpeed(Double(wpm)) }
        } + [
            .separator(),
            submenu("Finish the Rest In", [1, 2, 3, 5, 10, 15, 20, 30].map { min in
                ClosureItem("\(min) min") { p.finish(in: Double(min) * 60) }
            }),
        ]
        items.append(submenu("Speed: \(Int(Prefs.wpm)) wpm", speeds))

        let sizes: [NSMenuItem] = [
            ClosureItem("Bigger", key: key("="), modifiers: mods) { p.changeFontSize(by: 2) },
            ClosureItem("Smaller", key: key("-"), modifiers: mods) { p.changeFontSize(by: -2) },
            .separator(),
        ] + [24, 28, 34, 42, 56, 72].map { size in
            ClosureItem("\(size) pt", checked: Int(Prefs.fontSize) == size) {
                update { Prefs.fontSize = Double(size) }
            }
        }
        items.append(submenu("Text Size: \(Int(Prefs.fontSize)) pt", sizes))

        let talkLengths = [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60].map { min in
            ClosureItem(min == 0 ? "None" : "\(min) min", checked: Int(Prefs.talkLength) == min * 60) {
                update { Prefs.talkLength = Double(min * 60) }
            }
        }
        items.append(submenu("Timer", [
            ClosureItem("Show Timer", checked: Prefs.showTimer) { update { Prefs.showTimer.toggle() } },
            submenu("Talk Length", talkLengths),
            submenu("Countdown", [0, 3, 5].map { secs in
                ClosureItem(secs == 0 ? "Off" : "\(secs) seconds", checked: Prefs.countdown == secs) {
                    Prefs.countdown = secs
                }
            }),
        ]))

        items.append(submenu("Appearance", [
            submenu("Background", [0.2, 0.4, 0.6, 0.8, 1.0].map { value in
                ClosureItem("\(Int(value * 100))%", checked: abs(Prefs.opacity - value) < 0.01) {
                    update { Prefs.opacity = value }
                }
            }),
            ClosureItem("Blur Behind", checked: Prefs.blur) { update { Prefs.blur.toggle() } },
            .separator(),
            ClosureItem("Center Text", checked: Prefs.centered) { update { Prefs.centered.toggle() } },
            ClosureItem("Mirror Text", checked: Prefs.mirror) { update { Prefs.mirror.toggle() } },
            ClosureItem("Reading Guide", checked: Prefs.guide) { update { Prefs.guide.toggle() } },
        ]))

        items.append(submenu("Window", [
            ClosureItem("Small") { p.panel.resize(to: NSSize(width: 480, height: 160)) },
            ClosureItem("Medium") { p.panel.resize(to: NSSize(width: 640, height: 220)) },
            ClosureItem("Large") { p.panel.resize(to: NSSize(width: 860, height: 320)) },
            ClosureItem("Move Under Camera") { p.panel.moveToTopCenter() },
            .separator(),
            ClosureItem("Hide from Screen Sharing", checked: Prefs.hideFromCapture) {
                update { Prefs.hideFromCapture.toggle() }
            },
        ]))

        let modifierItems = ShortcutModifiers.allCases.map { m in
            ClosureItem("Use \(m.symbols)", checked: Prefs.hotkeyModifiers == m) { [weak self] in
                Prefs.hotkeyModifiers = m
                self?.onShortcutsChanged?()
            }
        }
        let symbols = Prefs.hotkeyModifiers.symbols
        var scrollTitle = "Scroll Anywhere with \(symbols) + Trackpad"
        if Prefs.scrollAnywhere && !ScrollTap.isTrusted { scrollTitle += " (needs Accessibility)" }
        items.append(submenu("Shortcuts", [
            ClosureItem("Global Shortcuts", checked: Prefs.hotkeys) { [weak self] in
                Prefs.hotkeys.toggle()
                self?.onShortcutsChanged?()
            },
            ClosureItem(scrollTitle, checked: Prefs.scrollAnywhere) { [weak self] in
                Prefs.scrollAnywhere.toggle()
                self?.onShortcutsChanged?()
            },
            .separator(),
        ] + modifierItems))

        items += [
            .separator(),
            ClosureItem("About Telelucent") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            },
            ClosureItem("Quit Telelucent", key: "q", modifiers: .command) { NSApp.terminate(nil) },
        ]
        return items
    }
}
