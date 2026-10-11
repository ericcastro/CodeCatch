import SwiftUI

struct BannerCard: View {
    let id: UUID
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        if let item = model.items.first(where: { $0.id == id }) {
            CodeCard(item: item, style: .banner)
                .floatingCard()
        }
    }
}
