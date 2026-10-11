import CodeCatchCore
import SwiftUI

/// A site's logo, a monogram when it has none, or a globe for every site.
struct SiteIcon: View {
    let site: String?
    var size: CGFloat = 22
    @ObservedObject private var icons = IconStore.shared

    var body: some View {
        Group {
            if let site {
                if let icon = icons.icon(for: SiteQuery(site)?.domain) { LogoTile(icon: icon, size: size) } else { Monogram(name: site, size: size) }
            } else {
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(Color.orange.gradient)
                    .frame(width: size, height: size)
                    .overlay(Image(systemName: "globe").font(.system(size: size * 0.55, weight: .semibold)).foregroundStyle(.white))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Settings → Agents → Always Allowed: every rule.
struct AgentRulesSheet: View {
    @ObservedObject private var access = AppModel.shared.agents
    @Local private var selection = Set<AgentRule.ID>()

    var body: some View {
        ListSheet(title: "Always Allowed", about: "These apps get codes without asking you. To add one, choose Always Allow on a request.") {
            List(selection: $selection) {
                ForEach(rules) { AgentRuleRow(rule: $0) }
            }
            .contextMenu(forSelectionType: AgentRule.ID.self) { picked in
                Button("Stop Allowing") { remove(picked) }
            }
            .onDeleteCommand { remove(selection) }
            .overlay {
                if rules.isEmpty {
                    ContentUnavailableView("Nothing Allowed", systemImage: "checkmark.shield",
                                           description: Text("Every code asks for \(DeviceAuthentication.unlockMethods)."))
                }
            }
        } bar: {
            HStack(spacing: 0) {
                Button { remove(selection) } label: { Image(systemName: "minus").frame(width: 24, height: 22) }
                    .help("Stop allowing the selected")
                    .accessibilityLabel("Stop allowing")
                    .disabled(selection.isEmpty)
                Spacer()
            }
            .padding(4)
        }
    }

    /// By app, then "all sites" before single sites, then by site.
    private var rules: [AgentRule] {
        access.config.rules.sorted { ($0.app.name, $0.site ?? "", $0.id.uuidString) < ($1.app.name, $1.site ?? "", $1.id.uuidString) }
    }

    private func remove(_ picked: Set<AgentRule.ID>) {
        guard !picked.isEmpty else { return }
        access.removeRules(picked)
        selection.subtract(picked)
    }
}

private struct AgentRuleRow: View {
    let rule: AgentRule

    var body: some View {
        HStack(spacing: 10) {
            SiteIcon(site: rule.site, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.site ?? "All Sites").lineLimit(1)
                Text("From \(rule.app.name)")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(rule.added.formatted(date: .abbreviated, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

/// Settings → Agents → Request History: recent requests by day, newest first.
struct AgentHistorySheet: View {
    @ObservedObject private var access = AppModel.shared.agents

    var body: some View {
        ListSheet(title: "Request History", about: "What agents and scripts asked for, and what happened. Codes are never saved here.", height: 320) {
            List {
                // Day titles as plain rows: a List's section headers stick with an opaque background here.
                ForEach(days, id: \.day) { group in
                    Text(title(group.day)).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .listRowSeparator(.hidden)
                    ForEach(group.entries) { AgentLogRow(entry: $0) }
                }
            }
            .overlay {
                if access.log.isEmpty {
                    ContentUnavailableView("No Requests", systemImage: "terminal",
                                           description: Text("Requests show here once an agent asks for a code."))
                }
            }
        } bar: {
            HStack {
                Text(access.log.isEmpty ? "" : "Last \(access.log.count) of up to 50").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { access.clearLog() }.disabled(access.log.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var days: [(day: Date, entries: [AgentLogEntry])] {
        Dictionary(grouping: access.log) { Calendar.current.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value) }
            .sorted { $0.day > $1.day }
    }

    private func title(_ day: Date) -> String {
        Calendar.current.isDateInToday(day) ? "Today" : Calendar.current.isDateInYesterday(day) ? "Yesterday"
            : day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct AgentLogRow: View {
    let entry: AgentLogEntry

    var body: some View {
        HStack(spacing: 10) {
            SiteIcon(site: entry.site.isEmpty ? nil : entry.site, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.site.isEmpty ? "CodeCatch" : entry.site).lineLimit(1)
                // CodeCatch's own entries (access turned off) have no site, and would name it twice.
                if !entry.site.isEmpty {
                    Text(entry.caller).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(entry.outcome).font(.subheadline)
                }
                Text(entry.date.formatted(date: .omitted, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    /// The same dots as a source's status: green went out, red was refused, orange ended another way.
    private var color: Color {
        entry.outcome.hasPrefix("Allowed") ? .green : entry.outcome == "Denied" ? .red : .orange
    }
}
