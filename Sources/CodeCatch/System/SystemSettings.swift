import AppKit

enum SystemSettings {
    static func open(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }
    /// macOS lists an app here once it has tried to read a protected file, which is
    /// what leads to this pane: the user only turns its switch on.
    static func fullDiskAccess() { open("Privacy_AllFiles") }
    static func accessibility() { open("Privacy_Accessibility") }
}
