import Foundation

/// Runs its body at most once, for a continuation that callbacks may try to resume more than once.
final class Once: @unchecked Sendable {
    private var done = false
    private let lock = NSLock()
    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        if !done {
            done = true
            body()
        }
    }
}
