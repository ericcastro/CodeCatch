import AppKit

/// Asks before something that can't be undone. An alert rather than a SwiftUI dialog,
/// so it works the same from the menu-bar popover as from Settings. `safeDefault` makes
/// Return cancel, for when going ahead is the risk. `details` sits under the message in small,
/// selectable text; `also` adds a third button that runs instead of the action.
@MainActor
func confirmed(
    _ title: String, _ message: String, action: String, safeDefault: Bool = false,
    details: String? = nil, also: (title: String, run: () -> Void)? = nil
) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    // A safe default comes first, as Apple orders them; the risky action last.
    let go: NSButton
    var alsoButton: NSButton?
    if safeDefault {
        alert.addButton(withTitle: "Cancel")
        alsoButton = also.map { alert.addButton(withTitle: $0.title) }
        go = alert.addButton(withTitle: action)
    } else {
        go = alert.addButton(withTitle: action)
        alsoButton = also.map { alert.addButton(withTitle: $0.title) }
        alert.addButton(withTitle: "Cancel")
    }
    go.hasDestructiveAction = true
    if let details {
        let text = NSTextField(wrappingLabelWithString: details)
        text.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        text.textColor = .secondaryLabelColor
        text.preferredMaxLayoutWidth = 220
        text.frame.size = text.fittingSize
        alert.accessoryView = text
    }
    NSApp.activate()
    let tapped = alert.buttons[alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue]
    if tapped == alsoButton { also?.run() }
    return tapped == go
}

/// Settings and the menu's Clear History: a clear outlasts restarts, so it asks first.
@MainActor
func confirmClearHistory(_ model: AppModel) {
    guard
        confirmed(
            "Clear history?", "Codes and links you have received are removed and don't come back after a restart. Bitwarden codes are kept.",
            action: "Clear")
    else { return }
    model.clearHistory()
}
