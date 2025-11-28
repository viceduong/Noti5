//
//  RulesListView.swift
//  Noti5
//
//  List and manage filter rules
//

import SwiftUI

struct RulesListView: View {
    @StateObject private var ruleStorage = RuleStorage.shared
    @State private var showingAddRule = false
    @State private var editingRule: FilterRule?
    @State private var showingModeInfo = false

    var body: some View {
        NavigationView {
            List {
                // Global Mode Section
                Section {
                    Picker("Filter Mode", selection: $ruleStorage.globalMode) {
                        ForEach(GlobalFilterMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Text(ruleStorage.globalMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Active Rules Section
                Section(header: Text("Active Rules (\(activeRules.count))")) {
                    if activeRules.isEmpty {
                        Text("No active rules")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(activeRules) { rule in
                            RuleRow(rule: rule, onToggle: { toggleRule(rule) })
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRule = rule
                                }
                        }
                        .onDelete { offsets in
                            deleteActiveRules(at: offsets)
                        }
                        .onMove { source, destination in
                            moveActiveRules(from: source, to: destination)
                        }
                    }
                }

                // Inactive Rules Section
                if !inactiveRules.isEmpty {
                    Section(header: Text("Inactive Rules (\(inactiveRules.count))")) {
                        ForEach(inactiveRules) { rule in
                            RuleRow(rule: rule, onToggle: { toggleRule(rule) })
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRule = rule
                                }
                        }
                        .onDelete { offsets in
                            deleteInactiveRules(at: offsets)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Rules")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRule = true }) {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddRule) {
                RuleEditorView(rule: nil) { newRule in
                    ruleStorage.addRule(newRule)
                }
            }
            .sheet(item: $editingRule) { rule in
                RuleEditorView(rule: rule) { updatedRule in
                    ruleStorage.updateRule(updatedRule)
                }
            }
        }
    }

    private var activeRules: [FilterRule] {
        ruleStorage.rules.filter { $0.isEnabled }.sorted { $0.priority < $1.priority }
    }

    private var inactiveRules: [FilterRule] {
        ruleStorage.rules.filter { !$0.isEnabled }
    }

    private func toggleRule(_ rule: FilterRule) {
        ruleStorage.toggleRule(rule)
    }

    private func deleteActiveRules(at offsets: IndexSet) {
        let rulesToDelete = offsets.map { activeRules[$0] }
        for rule in rulesToDelete {
            ruleStorage.deleteRule(rule)
        }
    }

    private func deleteInactiveRules(at offsets: IndexSet) {
        let rulesToDelete = offsets.map { inactiveRules[$0] }
        for rule in rulesToDelete {
            ruleStorage.deleteRule(rule)
        }
    }

    private func moveActiveRules(from source: IndexSet, to destination: Int) {
        var rules = activeRules
        rules.move(fromOffsets: source, toOffset: destination)

        // Update priorities
        for (index, rule) in rules.enumerated() {
            var updated = rule
            updated.priority = index
            ruleStorage.updateRule(updated)
        }
    }
}

// MARK: - Rule Row

struct RuleRow: View {
    let rule: FilterRule
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.name)
                        .font(.body)

                    Spacer()

                    Image(systemName: rule.action.iconName)
                        .foregroundColor(rule.action == .notify ? .green : .red)
                        .font(.caption)
                }

                Text(ruleDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private var ruleDescription: String {
        if rule.conditions.isEmpty {
            return "No conditions"
        }

        let conditionDescriptions = rule.conditions.map { condition in
            "\(condition.field.displayName) \(condition.matchType.displayName) \"\(condition.value)\""
        }

        let logic = rule.logicOperator == .and ? " AND " : " OR "
        return conditionDescriptions.joined(separator: logic)
    }
}

#if DEBUG
struct RulesListView_Previews: PreviewProvider {
    static var previews: some View {
        RulesListView()
    }
}
#endif
