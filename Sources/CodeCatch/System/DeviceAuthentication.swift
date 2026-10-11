import AppKit
import LocalAuthentication

@MainActor
final class DeviceAuthentication {
    static var unlockMethods: String {
        supportsTouchID() ? "Touch ID or your Mac password" : "your Mac password"
    }

    static func supportsTouchID(context: LAContext = LAContext()) -> Bool {
        // Ask each time: enrollment, lockout and external keyboards can change.
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            && context.biometryType == .touchID
    }

    private var context: LAContext?

    func authenticate(reason: String = "show your verification codes") async throws {
        let context = LAContext()
        self.context = context
        // The prompt is macOS's own window: it closes the popover and, when done, hands focus
        // to the app used before. Bring back what was open, unless a lock cancelled the prompt.
        let wasActive = NSApp.isActive
        let popoverWasOpen = MenuBarPopover.isOpen
        Self.watchHandOff()
        defer {
            if self.context === context {
                self.context = nil
                if wasActive || popoverWasOpen { Self.takeFocusBack() }
                if popoverWasOpen { MenuBarPopover.open(query: nil) }
            }
        }
        guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) else {
            throw LAError(.authenticationFailed)
        }
    }

    func cancel() {
        context?.invalidate()
        context = nil
        Self.handOffDeadline = .distantPast
    }

    // Shared: the hand-off outlives a `DeviceAuthentication` made for one prompt.
    private static var handOff: NSObjectProtocol?
    private static var handOffDeadline = Date.distantPast

    /// macOS's hand-off to the app used before lands just after we come forward (3 ms, measured),
    /// and that app's windows then cover ours: come forward once more when it does. Only while
    /// the prompt is still in front (a system agent, never a regular app), and briefly, so an
    /// app the user switches to stays in front.
    private static func takeFocusBack() {
        let front = NSWorkspace.shared.frontmostApplication
        let pending = front != nil && front != .current && front?.activationPolicy != .regular
        NSApp.comeForward()
        handOffDeadline = pending ? Date().addingTimeInterval(0.5) : .distantPast
    }

    /// Before the prompt opens: an observer added as it closes misses the hand-off.
    private static func watchHandOff() {
        handOffDeadline = .distantPast  // a new prompt ends the wait for the last one's hand-off
        guard handOff == nil else { return }
        handOff = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) {
            note in
            let other = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication != .current
            MainActor.assumeIsolated {
                guard other, Date() < handOffDeadline else { return }
                handOffDeadline = .distantPast
                NSApp.comeForward()
            }
        }
    }
}
