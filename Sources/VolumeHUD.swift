import AppKit

final class VolumeHUD {
    private let panel: NSPanel
    private let icon = NSImageView()
    private let progress = NSProgressIndicator()
    private var dismiss: DispatchWorkItem?
    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 180, height: 75), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = NSColor.black.withAlphaComponent(0.78)
        panel.hasShadow = true; panel.level = .floating; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView?.wantsLayer = true; panel.contentView?.layer?.cornerRadius = 12
        icon.frame = NSRect(x: 76, y: 36, width: 28, height: 25); icon.contentTintColor = .white
        panel.contentView?.addSubview(icon)
        progress.frame = NSRect(x: 20, y: 16, width: 140, height: 10)
        progress.isIndeterminate = false; progress.minValue = 0; progress.maxValue = 1
        panel.contentView?.addSubview(progress)
    }
    func show(volume: Double, muted: Bool) {
        dismiss?.cancel(); panel.animator().alphaValue = 1
        icon.image = NSImage(systemSymbolName: muted || volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", accessibilityDescription: nil)
        progress.doubleValue = muted ? 0 : volume
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 90))
        }
        panel.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in context.duration = 0.25; self.panel.animator().alphaValue = 0 }
            completionHandler: { self.panel.orderOut(nil) }
        }
        dismiss = work; DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }
}
