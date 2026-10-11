import SwiftUI

/// An info button with a popover, for headers that need a short explanation.
struct SettingInfo<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Local private var presented = false

    var body: some View {
        GlyphButton(symbol: "info.circle", help: "\(title) information") { presented.toggle() }
            .popover(isPresented: $presented) { InfoCard(title: title) { content } }
    }
}

/// A button inside a popover that closes it first, so a sheet it opens can show.
struct PopoverButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(title, role: role) {
            dismiss()
            action()
        }
    }
}

/// The popover body every settings explanation and details panel uses.
struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 300)
    }
}

/// Shows `text` in a popover after the pointer rests on the view for a moment.
private struct HoverInfo: ViewModifier {
    let title: String
    let text: String?
    @Local private var shown = false
    @Local private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                pending?.cancel()
                guard inside, text != nil else {
                    shown = false
                    return
                }
                pending = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    if !Task.isCancelled { shown = true }
                }
            }
            .popover(isPresented: $shown, arrowEdge: .bottom) {
                InfoCard(title: title) { Text(text ?? "").foregroundStyle(.secondary) }
            }
    }
}

extension View {
    func hoverInfo(_ title: String, _ text: String?) -> some View { modifier(HoverInfo(title: title, text: text)) }
}
