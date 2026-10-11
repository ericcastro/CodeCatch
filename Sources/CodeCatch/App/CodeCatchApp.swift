import AppKit
import SwiftUI

@main
enum Entry {
    static func main() {
        #if DEBUG
            DebugCommand.runIfAsked()
        #endif
        // One menu bar icon: a second copy (the DMG's, or another install) bows out.
        if let id = Bundle.main.bundleIdentifier,
            NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != .current })
        {
            exit(0)
        }
        CodeCatchApp.main()
    }
}

struct CodeCatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }

        Window("Recent Emails", id: RecoveryView.windowID) {
            RecoveryView(model: AppModel.shared)
        }
        .defaultSize(width: 700, height: 450)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("Welcome", id: WelcomeView.windowID) {
            WelcomeView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(Prefs[Prefs.welcomed] ? .suppressed : .presented)
        .restorationBehavior(.disabled)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppModel.shared.start()
            _ = Updater.controller  // starts the scheduled update checks
        }
    }

    func applicationWillTerminate(_ notification: Notification) { CLIServer.stop() }

    /// Opened again while running (Finder, Spotlight): with no window to bring forward,
    /// show the popover, or the app seems not to respond.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }
        MainActor.assumeIsolated { MenuBarPopover.open(query: nil) }
        return false
    }

    /// codecatch:// links. SwiftUI keeps `application(_:open:)` for its own scenes, so take the event directly.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(openURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc private func openURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue.flatMap(URL.init(string:)) else { return }
        MainActor.assumeIsolated { MenuBarPopover.handle(url) }
    }
}
