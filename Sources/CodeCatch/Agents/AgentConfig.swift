import Foundation

/// "Always allow": codes for one site, or for every site, from one app. Sign-in links too while
/// `AgentConfig.links` is on.
struct AgentRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var app: AgentApp
    /// The sender's registrable domain; nil for every site.
    var site: String?
    var added = Date()
}

/// Kept in the login Keychain, not UserDefaults: a script can `defaults write` a switch on,
/// but can't write an item that only this team's builds may change without a prompt.
struct AgentConfig: Codable, Equatable {
    var enabled = false
    var rules: [AgentRule] = []
    /// Every code to any agent, without asking, like skipping permission prompts.
    var allowAll = false
    /// Sign-in links may go to agents at all. A link signs the agent in as the user, so it's off until
    /// turned on; then links follow the same card, rules and Allow All as codes.
    var links = false
    /// Automatic releases share the protected store with the grants they consume.
    var releases: [Date] = []

    init(enabled: Bool = false, rules: [AgentRule] = [], allowAll: Bool = false, links: Bool = false) {
        self.enabled = enabled; self.rules = rules; self.allowAll = allowAll; self.links = links
    }

    /// Settings saved before a field existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        rules = try c.decodeIfPresent([AgentRule].self, forKey: .rules) ?? []
        allowAll = try c.decodeIfPresent(Bool.self, forKey: .allowAll) ?? false
        links = try c.decodeIfPresent(Bool.self, forKey: .links) ?? false
        releases = try c.decodeIfPresent([Date].self, forKey: .releases) ?? []
    }
}

/// The switch and rules in the login Keychain, beside the app's other secrets.
enum AgentStore {
    private static let key = "agent-access"

    static func load() throws -> AgentConfig {
        guard let json = try Secrets.read(key) else { return AgentConfig() }
        return try JSONDecoder().decode(AgentConfig.self, from: Data(json.utf8))
    }

    static func save(_ config: AgentConfig) throws {
        try Secrets.set(String(decoding: try JSONEncoder().encode(config), as: UTF8.self), for: key)
    }
}
