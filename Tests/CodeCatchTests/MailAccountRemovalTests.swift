import Foundation
import Testing
@testable import CodeCatch
@testable import CodeCatchCore

private enum AccountRemovalFailure: Error { case denied }

/// Keychain whose `read` returns a token naming its key, and which logs every read, removal and revoke in order.
@MainActor private final class RevokeRecorder {
    var hasTokens = true
    var removeError: Error?
    var events: [String] = []
    var revoked: [(provider: String, token: String)] = []

    var keychain: AccountKeychain {
        AccountKeychain(
            read: { [self] key in events.append("read \(key)"); return hasTokens ? "token for \(key)" : nil },
            write: { _, _ in },
            remove: { [self] key in
                events.append("remove \(key)")
                if let removeError { throw removeError }
            },
            revoke: { [self] provider, token in
                events.append("revoke")
                revoked.append((provider.name, token))
            })
    }
}

/// The three ways a sign-in is forgotten: removing the account, editing its identity, or switching it to a password.
@MainActor private enum RevokeEntry: CaseIterable {
    case remove, identityEdit, switchToPassword

    func run(on model: AppModel, _ original: MailAccount, _ keychain: AccountKeychain) throws {
        switch self {
        case .remove:
            try model.remove(original, keychain: keychain)
        case .identityEdit:
            var edited = original
            edited.user = "new@example.com"
            model.save(edited)
            try model.removeUnusedCredentials(for: original, keychain: keychain)
        case .switchToPassword:
            var edited = original
            edited.signedIn = false
            try model.saveAccount(edited, password: "pw", refreshToken: nil, keychain: keychain)
        }
    }
}

@MainActor private final class AccountRemovalFixture {
    let suite = "MailAccountRemovalTests.\(UUID())"
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "messagesEnabled")
    }

    func makeModel() -> AppModel {
        let session = VaultSession(authenticate: {}, read: { [] }, write: { _ in }, remove: {})
        let monitor = SourceMonitor(watchMail: { _, _ in }, hasCredential: { _ in false }, defaults: defaults)
        return AppModel(vaultSession: session, monitor: monitor, defaults: defaults,
                        copyToClipboard: { _, _ in })
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}

@MainActor @Suite struct MailAccountRemovalTests {
    @Test func changedCallerFieldsCannotDeleteAnotherAccountsCredentials() throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let saved = MailAccount(label: "Work", host: "work.example.com", user: "work@example.com")
        let other = MailAccount(label: "Personal", host: "personal.example.com", user: "personal@example.com")
        model.save(saved)
        model.save(other)
        var supplied = saved
        supplied.host = other.host
        supplied.user = other.user
        var removed: [String] = []

        try model.remove(supplied, keychain: .stub(remove: { key in
            #expect(Set(model.accounts.map(\.id)) == Set([saved.id, other.id]))
            removed.append(key)
        }))

        #expect(removed.count == 2)
        #expect(Set(removed) == Set([saved.secretKey, saved.refreshTokenKey]))
        #expect(model.accounts.map(\.id) == [other.id])
        #expect(fixture.makeModel().accounts.map(\.id) == [other.id])
    }

    @Test func unknownIDCannotDeleteMatchingCredentialsOrSavedMetadata() throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let saved = MailAccount(label: "Work", host: "work.example.com", user: "work@example.com")
        model.save(saved)
        var unknown = saved
        unknown.id = UUID()
        var removed: [String] = []

        try model.remove(unknown, keychain: .stub(remove: { removed.append($0) }))

        #expect(removed.isEmpty)
        #expect(model.accounts.map(\.id) == [saved.id])
        #expect(fixture.makeModel().accounts.map(\.id) == [saved.id])
    }

    @Test func removingOneAccountPreservesCredentialsSharedByAnotherAccount() throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let first = MailAccount(label: "Work", host: "work.example.com", user: "work@example.com")
        var second = first
        second.id = UUID()
        second.label = "Also work"
        model.save(first)
        model.save(second)
        var removed: [String] = []

        try model.remove(first, keychain: .stub(remove: { removed.append($0) }))

        #expect(removed.isEmpty)
        #expect(model.accounts.map(\.id) == [second.id])
        #expect(fixture.makeModel().accounts.map(\.id) == [second.id])

        try model.remove(second, keychain: .stub(remove: { removed.append($0) }))
        #expect(removed.count == 2)
        #expect(Set(removed) == Set([second.secretKey, second.refreshTokenKey]))
        #expect(fixture.makeModel().accounts.isEmpty)
    }

    @Test(arguments: [1, 2])
    func credentialDeletionFailurePreservesAccountForRetry(failingCall: Int) throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let saved = MailAccount(label: "Work", host: "work.example.com", user: "work@example.com")
        model.save(saved)
        var attempted: [String] = []

        do {
            try model.remove(saved, keychain: .stub(remove: { key in
                attempted.append(key)
                if attempted.count == failingCall { throw AccountRemovalFailure.denied }
            }))
            Issue.record("Credential deletion failure must propagate")
        } catch AccountRemovalFailure.denied {
        }

        #expect(attempted.count == failingCall)
        #expect(model.accounts.map(\.id) == [saved.id])
        #expect(fixture.makeModel().accounts.map(\.id) == [saved.id])

        var retried: [String] = []
        try model.remove(saved, keychain: .stub(remove: { retried.append($0) }))
        #expect(retried.count == 2)
        #expect(Set(retried) == Set([saved.secretKey, saved.refreshTokenKey]))
        #expect(model.accounts.isEmpty)
        #expect(fixture.makeModel().accounts.isEmpty)
    }

    @Test(arguments: [false, true])
    func unusedCredentialCleanupPreservesSecretsReferencedByAnySavedAccount(differentID: Bool) throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let original = MailAccount(label: "Work", host: "work.example.com", user: "work@example.com")
        var saved = original
        if differentID { saved.id = UUID() }
        model.save(saved)
        var removed: [String] = []

        try model.removeUnusedCredentials(for: original, keychain: .stub(remove: { removed.append($0) }))

        #expect(removed.isEmpty)
        #expect(model.accounts.map(\.id) == [saved.id])
        #expect(model.accounts.map(\.secretKey) == [saved.secretKey])
        #expect(fixture.makeModel().accounts.map(\.id) == [saved.id])
    }

    @Test func identityChangeCleansOnlyOriginalCredentialsAndPreservesSavedReplacement() throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let original = MailAccount(label: "Work", host: "work.example.com", user: "work@example.com")
        model.save(original)
        var edited = original
        edited.host = "new.example.com"
        edited.user = "new@example.com"
        edited.label = "New work"
        model.save(edited)
        var removed: [String] = []

        try model.removeUnusedCredentials(for: original, keychain: .stub(remove: { key in
            #expect(model.accounts.map(\.id) == [edited.id])
            #expect(model.accounts.map(\.secretKey) == [edited.secretKey])
            removed.append(key)
        }))

        #expect(removed.count == 2)
        #expect(Set(removed) == Set([original.secretKey, original.refreshTokenKey]))
        let reloaded = fixture.makeModel()
        for snapshot in [model, reloaded] {
            #expect(snapshot.accounts.map(\.id) == [edited.id])
            #expect(snapshot.accounts.map(\.host) == [edited.host])
            #expect(snapshot.accounts.map(\.user) == [edited.user])
            #expect(snapshot.accounts.map(\.label) == [edited.label])
        }
    }

    @Test(arguments: [1, 2])
    func unusedCredentialCleanupFailureCannotRollBackSavedIdentity(failingCall: Int) throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let original = MailAccount(label: "Work", host: "work.example.com", user: "work@example.com")
        model.save(original)
        var edited = original
        edited.host = "new.example.com"
        edited.user = "new@example.com"
        edited.label = "New work"
        model.save(edited)
        var attempted: [String] = []

        do {
            try model.removeUnusedCredentials(for: original, keychain: .stub(remove: { key in
                attempted.append(key)
                if attempted.count == failingCall { throw AccountRemovalFailure.denied }
            }))
            Issue.record("Unused credential deletion failure must propagate")
        } catch AccountRemovalFailure.denied {
        }

        #expect(attempted.count == failingCall)
        #expect(Set(attempted).isSubset(of: Set([original.secretKey, original.refreshTokenKey])))
        let reloaded = fixture.makeModel()
        for snapshot in [model, reloaded] {
            #expect(snapshot.accounts.map(\.id) == [edited.id])
            #expect(snapshot.accounts.map(\.host) == [edited.host])
            #expect(snapshot.accounts.map(\.user) == [edited.user])
            #expect(snapshot.accounts.map(\.label) == [edited.label])
        }
    }

    /// A forgotten sign-in token must be revoked at its provider (not left live), once, after the
    /// Keychain removal, and never for a plain IMAP host that has no provider.
    @Test(arguments: RevokeEntry.allCases,
          [("imap.gmail.com", "Google"), ("outlook.office365.com", "Microsoft"), ("work.example.com", nil)])
    private func forgettingASignInRevokesItsTokenWithTheRightProvider(entry: RevokeEntry,
                                                                      host: (String, String?)) throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let recorder = RevokeRecorder()
        let original = MailAccount(label: "Mail", host: host.0, user: "me@example.com")
        model.save(original)

        try entry.run(on: model, original, recorder.keychain)

        if let provider = host.1 {
            #expect(recorder.revoked.map(\.provider) == [provider])
            #expect(recorder.revoked.map(\.token) == ["token for \(original.refreshTokenKey)"])
            #expect(recorder.events.contains("remove \(original.refreshTokenKey)"))
            #expect(recorder.events.last == "revoke")
        } else {
            #expect(recorder.revoked.isEmpty)
        }
    }

    /// If the Keychain refuses to remove the token, revoking would break the sign-in while the
    /// app still holds it; the error must propagate with no revoke.
    @Test(arguments: RevokeEntry.allCases)
    private func keychainRemovalFailureNeverRevokes(entry: RevokeEntry) throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let recorder = RevokeRecorder()
        recorder.removeError = AccountRemovalFailure.denied
        let original = MailAccount(label: "Gmail", host: "imap.gmail.com", user: "me@gmail.com")
        model.save(original)

        do {
            try entry.run(on: model, original, recorder.keychain)
            Issue.record("Keychain failure must propagate")
        } catch AccountRemovalFailure.denied {
        }

        #expect(recorder.revoked.isEmpty)
    }

    /// No stored token means nothing to revoke; revoking an empty or invented token would be a bogus network call.
    @Test func noStoredTokenMeansNoRevoke() throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let recorder = RevokeRecorder()
        recorder.hasTokens = false
        let account = MailAccount(label: "Gmail", host: "imap.gmail.com", user: "me@gmail.com")
        model.save(account)

        try model.remove(account, keychain: recorder.keychain)

        #expect(recorder.revoked.isEmpty)
        #expect(model.accounts.isEmpty)
    }

    /// Removing one of two accounts that share credentials must not revoke the token the other still uses.
    @Test func sharedCredentialsAreNeverReadRemovedOrRevoked() throws {
        let fixture = try AccountRemovalFixture()
        defer { fixture.cleanUp() }
        let model = fixture.makeModel()
        let recorder = RevokeRecorder()
        let first = MailAccount(label: "Gmail", host: "imap.gmail.com", user: "me@gmail.com")
        var second = first
        second.id = UUID()
        model.save(first)
        model.save(second)

        try model.remove(first, keychain: recorder.keychain)

        #expect(recorder.events.isEmpty)
        #expect(recorder.revoked.isEmpty)
        #expect(model.accounts.map(\.id) == [second.id])
    }
}
