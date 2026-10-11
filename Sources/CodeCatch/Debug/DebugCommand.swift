#if DEBUG
import Foundation

/// Debug builds' extra launch flags (`scripts/debug.sh <flag>`). Each one runs instead of the app and exits.
enum DebugCommand {
    static func runIfAsked() {
        let args = CommandLine.arguments
        if args.contains("--preview-recovery") {
            MainActor.assumeIsolated { RecoveryPreview.run() }
            exit(0)
        }
        if let i = args.firstIndex(of: "--snapshot") {
            guard i + 1 < args.count else { print("Usage: CodeCatch --snapshot <directory>"); exit(1) }
            MainActor.assumeIsolated { Snapshot.run(to: args[i + 1]) }
            exit(0)
        }
        if let i = args.firstIndex(of: "--import-env") {
            guard i + 1 < args.count else { print("Usage: CodeCatch --import-env <path/to/.env>"); exit(1) }
            var accounts = MailAccount.load()
            do {
                let n = try EnvImport.importCredentials(from: args[i + 1], into: &accounts)
                MailAccount.save(accounts)
                print("Imported \(n) password(s)")
                exit(0)
            } catch {
                print("Import failed: \(error.localizedDescription)")
                exit(1)
            }
        }
        if let probe = Probe.all.first(where: { args.contains($0.key) })?.value {
            Task { await probe(); exit(0) }
            dispatchMain()
        }
    }
}
#endif
