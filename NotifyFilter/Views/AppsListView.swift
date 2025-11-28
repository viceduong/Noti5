//
//  AppsListView.swift
//  NotifyFilter
//
//  Quick per-app settings and filtering
//

import SwiftUI

struct AppsListView: View {
    @StateObject private var ruleStorage = RuleStorage.shared
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(AppCategory.allCases, id: \.self) { category in
                    if let apps = filteredApps(for: category), !apps.isEmpty {
                        Section(header: Text(category.rawValue)) {
                            ForEach(apps) { app in
                                AppRow(
                                    app: app,
                                    rules: rulesForApp(app.bundleId),
                                    onQuickAction: { action in
                                        handleQuickAction(action, for: app)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search apps")
            .navigationTitle("Apps")
        }
    }

    private func filteredApps(for category: AppCategory) -> [KnownApp]? {
        guard let apps = KnownApp.grouped()[category] else { return nil }

        if searchText.isEmpty {
            return apps
        }

        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func rulesForApp(_ bundleId: String) -> [FilterRule] {
        ruleStorage.rules.filter { rule in
            rule.conditions.contains { condition in
                condition.field == .app && condition.value == bundleId
            }
        }
    }

    private func handleQuickAction(_ action: AppQuickAction, for app: KnownApp) {
        switch action {
        case .allowAll:
            // Create a rule to allow all notifications from this app
            let rule = FilterRule(
                name: "Allow \(app.name)",
                action: .notify,
                conditions: [
                    RuleCondition(field: .app, matchType: .equals, value: app.bundleId)
                ],
                logicOperator: .and
            )
            ruleStorage.addRule(rule)

        case .blockAll:
            // Create a rule to block all notifications from this app
            let rule = FilterRule(
                name: "Block \(app.name)",
                action: .block,
                conditions: [
                    RuleCondition(field: .app, matchType: .equals, value: app.bundleId)
                ],
                logicOperator: .and
            )
            ruleStorage.addRule(rule)

        case .removeRules:
            // Remove all rules for this app
            let rulesToRemove = rulesForApp(app.bundleId)
            for rule in rulesToRemove {
                ruleStorage.deleteRule(rule)
            }
        }
    }
}

enum AppQuickAction {
    case allowAll
    case blockAll
    case removeRules
}

// MARK: - App Row

struct AppRow: View {
    let app: KnownApp
    let rules: [FilterRule]
    let onQuickAction: (AppQuickAction) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            Image(systemName: app.iconSystemName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.body)

                if rules.isEmpty {
                    Text("No rules")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(rulesSummary)
                        .font(.caption)
                        .foregroundColor(rulesColor)
                }
            }

            Spacer()

            // Quick action menu
            Menu {
                Button(action: { onQuickAction(.allowAll) }) {
                    Label("Allow All", systemImage: "bell.badge")
                }

                Button(action: { onQuickAction(.blockAll) }) {
                    Label("Block All", systemImage: "bell.slash")
                }

                if !rules.isEmpty {
                    Divider()

                    Button(role: .destructive, action: { onQuickAction(.removeRules) }) {
                        Label("Remove Rules", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var rulesSummary: String {
        let notifyCount = rules.filter { $0.action == .notify && $0.isEnabled }.count
        let blockCount = rules.filter { $0.action == .block && $0.isEnabled }.count

        var parts: [String] = []
        if notifyCount > 0 {
            parts.append("\(notifyCount) allow")
        }
        if blockCount > 0 {
            parts.append("\(blockCount) block")
        }

        return parts.joined(separator: ", ") + " rule\(rules.count == 1 ? "" : "s")"
    }

    private var rulesColor: Color {
        let hasNotify = rules.contains { $0.action == .notify && $0.isEnabled }
        let hasBlock = rules.contains { $0.action == .block && $0.isEnabled }

        if hasNotify && hasBlock {
            return .orange
        } else if hasNotify {
            return .green
        } else if hasBlock {
            return .red
        } else {
            return .secondary
        }
    }
}

#Preview {
    AppsListView()
}
