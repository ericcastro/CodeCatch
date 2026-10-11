import AppKit
import SwiftUI

/// The card that slides in at the top-right when a code arrives. It is a
/// non-activating panel, so the app you are typing in keeps focus and
/// "Type" can send the code straight into it.
@MainActor
final class Banner {
    static let shared = Banner()

    private let panel = NSPanel.card()

    private var hideTask: Task<Void, Never>?

    func show(_ id: UUID) {
        guard let target = panel.host(BannerCard(id: id)) else { return }
        panel.setFrame(target.offsetBy(dx: slide, dy: 0), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
        hide(after: 25)
    }

    func hide(after delay: TimeInterval = 0) {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
                panel.animator().setFrameOrigin(NSPoint(x: panel.frame.minX + slide, y: panel.frame.minY))
            }
            guard !Task.isCancelled else { return }  // a new card arrived during the fade
            panel.orderOut(nil)
        }
    }

    /// Slides in from and out to the right like a notification; only fades with Reduce Motion.
    private var slide: CGFloat { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 24 }

    func setHovering(_ on: Bool) {
        if on { hideTask?.cancel() } else { hide(after: 6) }
    }
}

extension NSPanel {
    /// A borderless panel above other windows that never takes focus: the code banner and the agent card.
    static func card() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false  // the card draws its own (glass or material) shadow
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return p
    }

    /// Shows `view` in the panel and returns its frame at the top-right of the screen under the pointer.
    func host<V: View>(_ view: V) -> NSRect? {
        sharingType = Prefs[Prefs.hideFromCapture] ? .none : .readOnly  // from its first frame; AppModel.tick keeps it current
        let host = FirstClickHostingView(rootView: view)
        contentView = host
        let size = host.fittingSize
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return nil }
        let frame = screen.visibleFrame
        return NSRect(x: frame.maxX - size.width, y: frame.maxY - size.height + 2, width: size.width, height: size.height)
    }
}
