//
//  RuleStorage.swift
//  Noti5
//
//  Persistent storage for filter rules
//

import Foundation
import Combine

class RuleStorage: ObservableObject {
    static let shared = RuleStorage()

    @Published var rules: [FilterRule] = []
    @Published var globalMode: GlobalFilterMode = .whitelist

    private let rulesKey = "filterRules"
    private let modeKey = "globalFilterMode"

    private init() {
        loadRules()
    }

    // MARK: - CRUD Operations

    func addRule(_ rule: FilterRule) {
        rules.append(rule)
        saveRules()
    }

    func updateRule(_ rule: FilterRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
        }
    }

    func deleteRule(_ rule: FilterRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    func deleteRules(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }

    func moveRules(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        // Update priorities based on new order
        for (index, _) in rules.enumerated() {
            rules[index].priority = index
        }
        saveRules()
    }

    func toggleRule(_ rule: FilterRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            saveRules()
        }
    }

    // MARK: - Persistence

    private func saveRules() {
        // Save to UserDefaults for quick access
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
        UserDefaults.standard.set(globalMode.rawValue, forKey: modeKey)

        // Also save to shared location for root helper
        HelperManager.shared.saveRules(rules)
    }

    private func loadRules() {
        // Try loading from UserDefaults first
        if let data = UserDefaults.standard.data(forKey: rulesKey) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([FilterRule].self, from: data) {
                rules = decoded
            }
        }

        // Load global mode
        if let modeString = UserDefaults.standard.string(forKey: modeKey),
           let mode = GlobalFilterMode(rawValue: modeString) {
            globalMode = mode
        }

        // If no rules, try loading from helper's shared location
        if rules.isEmpty {
            rules = HelperManager.shared.loadRules()
        }

        // If still empty, create default rules
        if rules.isEmpty {
            createDefaultRules()
        }
    }

    // MARK: - Default Rules

    private func createDefaultRules() {
        // Create some example rules to help users get started
        rules = [
            FilterRule(
                name: "Priority Contacts",
                action: .notify,
                conditions: [
                    RuleCondition(field: .sender, matchType: .contains, value: "Mom"),
                    RuleCondition(field: .sender, matchType: .contains, value: "Dad"),
                ],
                logicOperator: .or
            ),
            FilterRule(
                name: "Urgent Keywords",
                action: .notify,
                conditions: [
                    RuleCondition(field: .keyword, matchType: .contains, value: "urgent"),
                    RuleCondition(field: .keyword, matchType: .contains, value: "emergency"),
                    RuleCondition(field: .keyword, matchType: .contains, value: "ASAP"),
                ],
                logicOperator: .or
            ),
        ]

        // Disable by default so users can customize
        for i in rules.indices {
            rules[i].isEnabled = false
        }

        saveRules()
    }

    // MARK: - Rule Evaluation

    func evaluate(notification: NotificationRecord) -> EvaluationResult {
        // Sort rules by priority
        let sortedRules = rules.filter { $0.isEnabled }.sorted { $0.priority < $1.priority }

        // Find first matching rule
        for rule in sortedRules {
            if rule.matches(notification: notification) {
                return .matched(rule: rule)
            }
        }

        // No rule matched - use global default
        let defaultAction: RuleAction = globalMode == .whitelist ? .block : .notify
        return .defaultResult(action: defaultAction)
    }

    // MARK: - Import/Export

    func exportRules() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(rules)
    }

    func importRules(from data: Data) -> Bool {
        let decoder = JSONDecoder()
        guard let imported = try? decoder.decode([FilterRule].self, from: data) else {
            return false
        }

        rules.append(contentsOf: imported)
        saveRules()
        return true
    }
}
