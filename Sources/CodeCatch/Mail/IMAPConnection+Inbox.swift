import CodeCatchCore
import Foundation

extension IMAPConnection {
    init(account: MailAccount) throws { try self.init(host: account.host, port: account.port) }

    /// Signs in and opens the INBOX read-only (EXAMINE): CodeCatch never changes mail.
    @discardableResult
    func openInbox(_ account: MailAccount) async throws -> [Response] {
        guard let password = account.password else { throw IMAPError.noPassword }
        try await open(user: account.user, password: password)
        let response = try await command("EXAMINE INBOX")
        uidValidity = response.lazy.compactMap { $0.number(after: "UIDVALIDITY ") }.first
        return response
    }

    func search(_ criteria: String) async throws -> [Int] {
        try await command("UID SEARCH \(criteria)").flatMap { r in
            r.text.hasPrefix("* SEARCH") ? r.text.split(separator: " ").dropFirst(2).compactMap { Int($0) } : []
        }
    }

    /// Fetches the start of each message, up to `IncomingMessage.mailReadLimit`.
    func fetch(_ uids: [Int], account: MailAccount) async throws -> [IncomingMessage] {
        guard !uids.isEmpty else { return [] }
        let set = uids.map(String.init).joined(separator: ",")
        let internalDate = DateFormatter()
        internalDate.locale = Locale(identifier: "en_US_POSIX")
        internalDate.dateFormat = "d-MMM-yyyy HH:mm:ss Z"
        return try await command("UID FETCH \(set) (UID INTERNALDATE BODY.PEEK[]<0.\(IncomingMessage.mailReadLimit)>)", timeout: 90).compactMap { r in
            guard let raw = r.literals.first, let q = r.text.range(of: "INTERNALDATE \"") else { return nil }
            let dateText = r.text[q.upperBound...].prefix(while: { $0 != "\"" }).trimmingCharacters(in: .whitespaces)
            return IncomingMessage(
                mail: raw, account: account, date: internalDate.date(from: dateText),
                messageID: r.number(after: "UID ").map { "\(uidValidity ?? 0):\($0)" })
        }
    }
}
