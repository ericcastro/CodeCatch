import SwiftUI

/// A System Settings row: coloured tile, title and subtitle, controls on the trailing edge.
/// `info` shows in a popover on hover. With `details`, clicking the row opens them instead.
struct SettingRow<Trailing: View>: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String?
    var info: String?
    var status: SourceStatus?
    var details: AnyView?
    @ViewBuilder var trailing: Trailing
    @Local private var presented = false

    var body: some View {
        HStack(spacing: 10) {
            if let details {
                Button {
                    presented.toggle()
                } label: {
                    label
                }
                .buttonStyle(.plain)
                .hoverHighlight(in: RoundedRectangle(cornerRadius: 6), outset: 4)
                .accessibilityHint("Shows status and options")
                .popover(isPresented: $presented, arrowEdge: .bottom) { InfoCard(title: title) { details } }
            } else {
                label
            }
            HStack(spacing: 10) { trailing }
        }
    }

    private var label: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(title)
                    if let status {
                        Circle().fill(status.color).frame(width: 6, height: 6)
                            .accessibilityLabel(status.summary)
                    }
                }
                .accessibilityElement(children: .combine)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
        }
        .contentShape(Rectangle())
        .hoverInfo(title, details == nil ? info : nil)
    }
}

extension SettingRow where Trailing == Switch {
    init(symbol: String, color: Color, title: String, subtitle: String? = nil, info: String? = nil, isOn: Binding<Bool>) {
        self.init(symbol: symbol, color: color, title: title, subtitle: subtitle, info: info) { Switch(isOn: isOn, label: title) }
    }
}

struct Switch: View {
    @Binding var isOn: Bool
    var label = ""
    var body: some View { Toggle(label, isOn: $isOn).labelsHidden() }
}
