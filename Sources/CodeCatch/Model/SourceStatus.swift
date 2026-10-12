import Foundation

enum SourceStatus: Equatable {
    case off, connecting, live
    case attention(String)
    case failed(String)

    /// What a local store reports until the app is allowed to read it.
    static let needsDiskAccess = "Needs Full Disk Access"
    /// What a signed-in mail account reports when its provider no longer accepts the sign-in.
    static let signInExpired = "Sign-in expired. Sign in again."
    /// A mail account with no password or sign-in saved.
    static let needsSignIn = "Needs sign-in"
    /// What an IMAP account reports when the server turns its password down.
    static let signInFailed = "Sign-in failed. Check the app password."
    /// A mail account while the Mac is offline: nothing to fix in CodeCatch.
    static let waitingForNetwork = "Waiting for network"

    var needsDiskAccess: Bool { self == .attention(Self.needsDiskAccess) }
    /// Fixed by signing in to the account again.
    var needsSignIn: Bool { needsAttention && [Self.needsSignIn, Self.signInExpired, Self.signInFailed].contains(summary) }

    var needsAttention: Bool {
        switch self {
        case .attention, .failed: true
        default: false
        }
    }

    var summary: String {
        switch self {
        case .off: "Off"
        case .connecting: "Connecting…"
        case .live: "Watching"
        case .attention(let s), .failed(let s): s
        }
    }
}
