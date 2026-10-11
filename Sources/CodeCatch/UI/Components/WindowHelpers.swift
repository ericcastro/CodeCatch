import AppKit
import SwiftUI

extension NSApplication {
    /// Activates the app and puts its open windows in front. A menu-bar app is rarely the
    /// active one, and `activate()` alone only asks the app in front to yield: a window
    /// shown at launch, or after macOS's own password prompt, then stays behind it.
    func comeForward() {
        activate(ignoringOtherApps: true)
        for window in orderedWindows.reversed() where window.isVisible && window.styleMask.contains(.titled) && !(window is NSPanel) {
            window.orderFrontRegardless()
        }
    }
}

extension View {
    /// Applies Hide from Screen Capture to this view's window as soon as it has one, before
    /// a code is drawn; `AppModel.tick` keeps every window current when the setting changes.
    func hiddenFromCapture() -> some View { background(CaptureGuard()) }
}

private struct CaptureGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) {}
    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.sharingType = Prefs[Prefs.hideFromCapture] ? .none : .readOnly
        }
    }
}
