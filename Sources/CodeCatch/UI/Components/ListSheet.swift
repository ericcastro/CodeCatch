import SwiftUI

/// A Settings sheet that is one list, like Mail's blocked senders: a header, the list in a box with
/// a bar of buttons along its bottom, and Done.
struct ListSheet<Content: View, Bar: View>: View {
    let title: String
    let about: String
    var height: CGFloat = 280
    @ViewBuilder var content: Content
    @ViewBuilder var bar: Bar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: title, about: about)
            VStack(spacing: 0) {
                content.scrollContentBackground(.hidden)
                Divider()
                bar.buttonStyle(.borderless)
            }
            .frame(height: height)
            .well()
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
