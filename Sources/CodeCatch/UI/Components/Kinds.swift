import SwiftUI

/// What CodeCatch catches, drawn the same in Settings → What to Catch and on the cards.
enum CatchKind {
    case code, signIn, passwordReset

    var title: String { switch self { case .code: "Code"; case .signIn: "Sign-in link"; case .passwordReset: "Password reset" } }
    var symbol: String { switch self { case .code: "number"; case .signIn: "link"; case .passwordReset: "lock.rotation" } }
    var color: Color { switch self { case .code: .blue; case .signIn: .teal; case .passwordReset: .orange } }
}

extension CodeItem {
    var kind: CatchKind { !isLink ? .code : resetsPassword ? .passwordReset : .signIn }
}

/// Where codes come from, drawn the same in Welcome and Settings → Sources.
enum SourceKind {
    case messages, appleMail, mail

    var symbol: String { switch self { case .messages: "message.fill"; case .appleMail: "tray.fill"; case .mail: "envelope.fill" } }
    var color: Color { switch self { case .messages: .green; case .appleMail: .cyan; case .mail: .blue } }
}

/// A System Settings style coloured icon tile.
struct IconTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.gradient)
            .frame(width: 22, height: 22)
            .overlay(Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white))
    }
}
