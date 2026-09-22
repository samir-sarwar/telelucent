import AppKit
import CoreVideo

/// Calls `tick` on the main thread once per display refresh while running.
/// When stopped nothing is scheduled at all, so an idle prompter costs no CPU.
final class DisplayLink {
    private var link: CVDisplayLink?
    private var last: CFTimeInterval = 0
    private let tick: (Double) -> Void

    init(tick: @escaping (Double) -> Void) {
        self.tick = tick
    }

    deinit { stop() }

    var isRunning: Bool { link.map { CVDisplayLinkIsRunning($0) } ?? false }

    func start() {
        if link == nil {
            CVDisplayLinkCreateWithActiveCGDisplays(&link)
            guard let link else { return }
            CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
                DispatchQueue.main.async { self?.fire() }
                return kCVReturnSuccess
            }
        }
        guard let link, !CVDisplayLinkIsRunning(link) else { return }
        last = CACurrentMediaTime()
        CVDisplayLinkStart(link)
    }

    func stop() {
        if let link, CVDisplayLinkIsRunning(link) { CVDisplayLinkStop(link) }
    }

    private func fire() {
        guard isRunning else { return }
        let now = CACurrentMediaTime()
        let dt = min(now - last, 0.05)
        last = now
        tick(dt)
    }
}
