//
//  RuleEditorView.swift
//  NotifyFilter
//
//  Create and edit filter rules
//

import SwiftUI

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let existingRule: FilterRule?
    let onSave: (FilterRule) -> Void

    @State private var name: String = ""
    @State private var action: RuleAction = .notify
    @State private var logicOperator: LogicOperator = .and
    @State private var conditions: [RuleCondition] = []
    @State private var isEnabled: Bool = true

    init(rule: FilterRule?, onSave: @escaping (FilterRule) -> Void) {
        self.existingRule = rule
        self.onSave = onSave

        // Initialize state from existing rule
        if let rule = rule {
            _name = State(initialValue: rule.name)
            _action = State(initialValue: rule.action)
            _logicOperator = State(initialValue: rule.logicOperator)
            _conditions = State(initialValue: rule.conditions)
            _isEnabled = State(initialValue: rule.isEnabled)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section(header: Text("Rule")) {
                    TextField("Rule Name", text: $name)

                    Picker("Action", selection: $action) {
                        ForEach(RuleAction.allCases, id: \.self) { action in
                            Label(action.displayName, systemImage: action.iconName)
                                .tag(action)
                        }
                    }

                    Toggle("Enabled", isOn: $isEnabled)
                }

                // Conditions
                Section(header: Text("Conditions")) {
                    if conditions.isEmpty {
                        Text("No conditions. Tap + to add one.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(conditions.indices, id: \.self) { index in
                            ConditionRow(condition: $conditions[index])
                        }
                        .onDelete { offsets in
                            conditions.remove(atOffsets: offsets)
                        }
                    }

                    Button(action: addCondition) {
                        Label("Add Condition", systemImage: "plus.circle")
                    }
                }

                // Logic
                if conditions.count > 1 {
                    Section(header: Text("Logic")) {
                        Picker("Match", selection: $logicOperator) {
                            ForEach(LogicOperator.allCases, id: \.self) { op in
                                Text(op.displayName).tag(op)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(logicDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Preview
                Section(header: Text("Preview")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(rulePreview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Quick Add
                Section(header: Text("Quick Add")) {
                    QuickAddSenderButton { sender in
                        addSenderCondition(sender)
                    }

                    QuickAddAppButton { bundleId in
                        addAppCondition(bundleId)
                    }
                }
            }
            .navigationTitle(existingRule == nil ? "New Rule" : "Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(name.isEmpty || conditions.isEmpty)
                }
            }
        }
    }

    private var logicDescription: String {
        switch logicOperator {
        case .and:
            return "All conditions must match for this rule to trigger"
        case .or:
            return "Any condition matching will trigger this rule"
        }
    }

    private var rulePreview: String {
        if conditions.isEmpty {
            return "Add conditions to see preview"
        }

        let actionText = action == .notify ? "NOTIFY" : "BLOCK"
        let conditionText = conditions.map { condition in
            "\(condition.field.displayName) \(condition.matchType.displayName) \"\(condition.value)\""
        }
        let logic = logicOperator == .and ? " AND " : " OR "

        return "IF \(conditionText.joined(separator: logic)) THEN \(actionText)"
    }

    private func addCondition() {
        conditions.append(RuleCondition(field: .sender, matchType: .contains, value: ""))
    }

    private func addSenderCondition(_ sender: String) {
        conditions.append(RuleCondition(field: .sender, matchType: .contains, value: sender))
    }

    private func addAppCondition(_ bundleId: String) {
        conditions.append(RuleCondition(field: .app, matchType: .equals, value: bundleId))
    }

    private func saveRule() {
        var rule: FilterRule

        if let existing = existingRule {
            rule = existing
            rule.name = name
            rule.action = action
            rule.logicOperator = logicOperator
            rule.conditions = conditions
            rule.isEnabled = isEnabled
        } else {
            rule = FilterRule(
                name: name,
                action: action,
                conditions: conditions,
                logicOperator: logicOperator
            )
            rule.isEnabled = isEnabled
        }

        onSave(rule)
        dismiss()
    }
}

// MARK: - Condition Row

struct ConditionRow: View {
    @Binding var condition: RuleCondition

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Field", selection: $condition.field) {
                    ForEach(ConditionField.allCases, id: \.self) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .pickerStyle(.menu)

                Picker("Match", selection: $condition.matchType) {
                    ForEach(MatchType.allCases, id: \.self) { match in
                        Text(match.displayName).tag(match)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                TextField("Value", text: $condition.value)
                    .textFieldStyle(.roundedBorder)

                Toggle("Aa", isOn: $condition.isCaseSensitive)
                    .toggleStyle(.button)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Quick Add Buttons

struct QuickAddSenderButton: View {
    let onAdd: (String) -> Void

    @State private var showingAlert = false
    @State private var senderName = ""

    var body: some View {
        Button(action: { showingAlert = true }) {
            Label("Add Sender", systemImage: "person.badge.plus")
        }
        .alert("Add Sender", isPresented: $showingAlert) {
            TextField("Sender name", text: $senderName)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                if !senderName.isEmpty {
                    onAdd(senderName)
                    senderName = ""
                }
            }
        } message: {
            Text("Enter the sender name as it appears in notifications")
        }
    }
}

struct QuickAddAppButton: View {
    let onAdd: (String) -> Void

    @State private var showingPicker = false

    var body: some View {
        Button(action: { showingPicker = true }) {
            Label("Add App", systemImage: "app.badge.plus")
        }
        .sheet(isPresented: $showingPicker) {
            AppPickerView { app in
                onAdd(app.bundleId)
                showingPicker = false
            }
        }
    }
}

struct AppPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (KnownApp) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(AppCategory.allCases, id: \.self) { category in
                    if let apps = KnownApp.grouped()[category], !apps.isEmpty {
                        Section(header: Text(category.rawValue)) {
                            ForEach(apps) { app in
                                Button(action: { onSelect(app) }) {
                                    HStack {
                                        Image(systemName: app.iconSystemName)
                                            .frame(width: 24)
                                        Text(app.name)
                                        Spacer()
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RuleEditorView(rule: nil) { _ in }
}
