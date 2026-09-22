import AppKit

/// Loading and saving the script. It lives as plain text in Application Support.
enum Script {
    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Telelucent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("script.txt")
    }()

    static func load() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? welcome
    }

    static func save(_ text: String) {
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    static let welcome = """
    Welcome to Telelucent 👋

    This prompter floats over everything, stays see-through, and never shows up when you share your screen. Read your notes while looking right at the camera.

    Press ⌃⇧P to start scrolling and again to pause. Hold ⌃⇧↓ to skim ahead or ⌃⇧↑ to go back. None of this moves your mouse or takes focus from the app you're presenting.

    ⌃⇧→ and ⌃⇧← change the speed. ⌃⇧= and ⌃⇧− change the text size.

    Drag the edges to resize the prompter, or drag the text to move it. Keep it close to your camera so your eyes stay on your audience.

    Double-click the text, or hit the pencil in the toolbar, to paste in your own script. You can also drop a text, Markdown, RTF or Word file right onto the prompter.

    The strip along the bottom shows how long you've been talking and how much is left at your current pace. Set a talk length from the menu bar icon and it'll warn you when you're running over.

    Break a leg!
    """
}
