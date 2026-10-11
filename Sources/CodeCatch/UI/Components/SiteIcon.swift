import CodeCatchCore
import SwiftUI

/// A site's logo, a monogram when it has none, or a globe for every site.
struct SiteIcon: View {
    let site: String?
    var size: CGFloat = 22
    @ObservedObject private var icons = IconStore.shared

    var body: some View {
        Group {
            if let site {
                if let icon = icons.icon(for: SiteQuery(site)?.domain) { LogoTile(icon: icon, size: size) } else { Monogram(name: site, size: size) }
            } else {
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(Color.orange.gradient)
                    .frame(width: size, height: size)
                    .overlay(Image(systemName: "globe").font(.system(size: size * 0.55, weight: .semibold)).foregroundStyle(.white))
            }
        }
        .accessibilityHidden(true)
    }
}
