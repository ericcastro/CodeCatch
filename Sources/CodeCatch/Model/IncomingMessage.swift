import CodeCatchCore
import Foundation

/// A message from any source, before code extraction.
struct IncomingMessage {
    var text: String
    var subject: String? = nil
    var senderName: String
    var senderID: String
    var sourceKey: String
    var sourceLabel: String
    var date: Date
    var isMail: Bool
    var links: [MailLink] = []
    /// Source identifier only; never a code or a sign-in token.
    var messageID: String? = nil
    /// The mail server's verdict on the From domain; nil when it left none.
    var senderVerified: Bool? = nil
    /// The Message-ID header, for opening the email in Mail.
    var internetMessageID: String? = nil
    /// The email's own page at its provider (Gmail, Outlook on the web).
    var webURL: URL? = nil

    /// Subject and body: what codes and service names are read from.
    var fullText: String { [subject, text].compactMap { $0 }.joined(separator: "\n") }
    var dismissKey: String { "message:\(sourceKey)|\(messageID ?? "\(senderID.lowercased())|\(date.timeIntervalSince1970)")" }
    var service: String { ServiceIdentity.name(senderName: senderName, senderAddress: senderID, isMail: isMail, text: fullText) }
}

extension IncomingMessage {
    /// How much of an email is read: codes live in the text, not attachments.
    static let mailReadLimit = 262_144

    /// An email from a mail account, parsed from the start of its MIME source. `receiver` is set only
    /// when the provider's own API returned it, so its Authentication-Results can be trusted.
    init(mail raw: Data, receiver: MIME.Receiver? = nil, account: MailAccount, date: Date?, messageID: String?, webURL: URL? = nil) {
        let m = MIME.parse(raw.prefix(Self.mailReadLimit), receiver: receiver)
        self.init(
            text: m.text, subject: m.subject, senderName: m.fromName, senderID: m.fromAddress,
            sourceKey: account.id.uuidString, sourceLabel: account.label, date: date ?? Date(), isMail: true,
            links: m.links, messageID: messageID, senderVerified: m.senderVerified, internetMessageID: m.messageID, webURL: webURL)
    }
}
