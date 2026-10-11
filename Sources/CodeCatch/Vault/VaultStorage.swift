import CodeCatchCore
import Foundation

/// Keep the existing login-Keychain item; macOS authentication gates every session read.
@MainActor
enum VaultStorage {
    private static let key = "bitwarden.codes"

    static func unlockPolicy() -> UnlockPolicy {
        let authentication = DeviceAuthentication()
        return UnlockPolicy(
            load: { try Secrets.read("unlock-with-mac") == "true" },
            save: { try Secrets.set($0 ? "true" : "false", for: "unlock-with-mac") },
            authenticate: { try await authentication.authenticate() },
            cancel: { authentication.cancel() })
    }

    static func session(defaults: UserDefaults = .standard, unlockPolicy: UnlockPolicy? = nil) -> VaultSession {
        let policy = unlockPolicy ?? self.unlockPolicy()
        let session = VaultSession(
            authenticate: { try await policy.authenticate() },
            read: {
                guard defaults.bool(forKey: Prefs.bitwarden) else { return [] }
                guard let json = try Secrets.read(key) else { return [] }
                return try JSONDecoder().decode([VaultCode].self, from: Data(json.utf8))
            },
            write: { codes in
                let data = try JSONEncoder().encode(codes)
                try Secrets.set(String(decoding: data, as: UTF8.self), for: key)
                defaults.set(Date(), forKey: Prefs.vaultImportedAt)
            },
            remove: {
                try Secrets.remove(key)
                defaults.removeObject(forKey: Prefs.vaultImportedAt)
            })
        session.cancelAuthentication = { policy.cancelAuthentication() }
        session.didLock = { Clipboard.clearIfOurs() }
        return session
    }
}
