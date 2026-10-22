import Foundation
import Testing

@testable import CodeCatch

@MainActor @Suite(.serialized) struct BrowserSignInTests {
    private final class Log {
        var accepted: [URL] = []
        var cancelled = 0
    }

    /// A pending sign-in that takes only callbacks carrying `code=ok`.
    private func begin(_ log: Log, scheme: String = "msauth.com.uros.codecatch") -> UUID {
        let id = UUID()
        BrowserSignIn.pending = BrowserSignIn.Pending(id: id, scheme: scheme) { url in
            guard url.query?.contains("code=ok") == true else { return false }
            log.accepted.append(url)
            return true
        } cancel: {
            log.cancelled += 1
        }
        return id
    }

    @Test func otherSchemesAreLeftForTheRestOfTheApp() {
        let log = Log()
        _ = begin(log)
        defer { BrowserSignIn.pending = nil }
        #expect(!BrowserSignIn.handle(URL(string: "codecatch://search?q=github")!))
        #expect(log.accepted.isEmpty && BrowserSignIn.pending != nil)
    }

    @Test func aStaleCallbackKeepsWaitingAndTheRightOneEndsIt() {
        let log = Log()
        _ = begin(log)
        #expect(BrowserSignIn.handle(URL(string: "msauth.com.uros.codecatch://auth?code=stale")!))
        #expect(log.accepted.isEmpty && BrowserSignIn.pending != nil)
        #expect(BrowserSignIn.handle(URL(string: "MSAUTH.com.uros.codecatch://auth?code=ok")!))
        #expect(log.accepted.count == 1 && log.cancelled == 0 && BrowserSignIn.pending == nil)
        // Nothing waits any more: a repeat is not claimed.
        #expect(!BrowserSignIn.handle(URL(string: "msauth.com.uros.codecatch://auth?code=ok")!))
    }

    @Test func aNewSignInCancelsTheOldOneOnce() {
        let first = Log()
        let second = Log()
        let old = begin(first)
        _ = begin(second)
        defer { BrowserSignIn.pending = nil }
        #expect(first.cancelled == 1 && second.cancelled == 0)
        BrowserSignIn.cancel(old)  // the old task's own cancel arrives late: it must not end the new one
        #expect(first.cancelled == 1 && second.cancelled == 0 && BrowserSignIn.pending != nil)
    }

    @Test func cancelEndsTheWaitOnceAndNotAfterItFinished() {
        let log = Log()
        let id = begin(log)
        BrowserSignIn.cancel(id)
        BrowserSignIn.cancel(id)
        #expect(log.cancelled == 1 && BrowserSignIn.pending == nil)

        let done = Log()
        let finished = begin(done)
        #expect(BrowserSignIn.handle(URL(string: "msauth.com.uros.codecatch://auth?code=ok")!))
        BrowserSignIn.cancel(finished)
        #expect(done.cancelled == 0)
    }
}
