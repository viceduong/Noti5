//
//  FilterRule.swift
//  NotifyFilter
//
//  Data models for filtering rules
//

import Foundation

// MARK: - Filter Rule

struct FilterRule: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var priority: Int  // Lower number = higher priority
    var action: RuleAction
    var conditions: [RuleCondition]
    var logicOperator: LogicOperator

    init(name: String, action: RuleAction = .notify, conditions: [RuleCondition] = [], logicOperator: LogicOperator = .and) {
        self.id = UUID()
        self.name = name
        self.isEnabled = true
        self.priority = 100
        self.action = action
        self.conditions = conditions
        self.logicOperator = logicOperator
    }

    // Evaluate rule against a notification
    func matches(notification: NotificationRecord) -> Bool {
        guard isEnabled, !conditions.isEmpty else { return false }

        let results = conditions.map { $0.matches(notification: notification) }

        switch logicOperator {
        case .and:
            return results.allSatisfy { $0 }
        case .or:
            return results.contains { $0 }
        }
    }
}

// MARK: - Rule Condition

struct RuleCondition: Codable, Identifiable, Equatable {
    var id: UUID
    var field: ConditionField
    var matchType: MatchType
    var value: String
    var isCaseSensitive: Bool

    init(field: ConditionField, matchType: MatchType = .contains, value: String, isCaseSensitive: Bool = false) {
        self.id = UUID()
        self.field = field
        self.matchType = matchType
        self.value = value
        self.isCaseSensitive = isCaseSensitive
    }

    func matches(notification: NotificationRecord) -> Bool {
        let fieldValue = getFieldValue(from: notification)
        let compareValue = isCaseSensitive ? fieldValue : fieldValue.lowercased()
        let targetValue = isCaseSensitive ? value : value.lowercased()

        switch matchType {
        case .equals:
            return compareValue == targetValue
        case .contains:
            return compareValue.contains(targetValue)
        case .startsWith:
            return compareValue.hasPrefix(targetValue)
        case .endsWith:
            return compareValue.hasSuffix(targetValue)
        case .notEquals:
            return compareValue != targetValue
        case .notContains:
            return !compareValue.contains(targetValue)
        }
    }

    private func getFieldValue(from notification: NotificationRecord) -> String {
        switch field {
        case .sender:
            return notification.title
        case .keyword:
            // Search in title, subtitle, and body
            return [notification.title, notification.subtitle ?? "", notification.body].joined(separator: " ")
        case .app:
            return notification.bundleId
        }
    }
}

// MARK: - Enums

enum ConditionField: String, Codable, CaseIterable {
    case sender = "sender"
    case keyword = "keyword"
    case app = "app"

    var displayName: String {
        switch self {
        case .sender: return "Sender"
        case .keyword: return "Keyword"
        case .app: return "App"
        }
    }

    var description: String {
        switch self {
        case .sender: return "Match sender name in notification title"
        case .keyword: return "Match keyword in any text field"
        case .app: return "Match app bundle identifier"
        }
    }
}

enum MatchType: String, Codable, CaseIterable {
    case equals = "equals"
    case contains = "contains"
    case startsWith = "startsWith"
    case endsWith = "endsWith"
    case notEquals = "notEquals"
    case notContains = "notContains"

    var displayName: String {
        switch self {
        case .equals: return "equals"
        case .contains: return "contains"
        case .startsWith: return "starts with"
        case .endsWith: return "ends with"
        case .notEquals: return "not equals"
        case .notContains: return "not contains"
        }
    }
}

enum LogicOperator: String, Codable, CaseIterable {
    case and = "and"
    case or = "or"

    var displayName: String {
        switch self {
        case .and: return "ALL conditions (AND)"
        case .or: return "ANY condition (OR)"
        }
    }
}

enum RuleAction: String, Codable, CaseIterable {
    case notify = "notify"
    case block = "block"

    var displayName: String {
        switch self {
        case .notify: return "Notify (Critical Alert)"
        case .block: return "Block (Silence)"
        }
    }

    var iconName: String {
        switch self {
        case .notify: return "bell.badge.fill"
        case .block: return "bell.slash.fill"
        }
    }
}

// MARK: - Global Mode

enum GlobalFilterMode: String, Codable, CaseIterable {
    case whitelist = "whitelist"  // Only allow matched rules
    case blacklist = "blacklist"  // Allow all except matched blocking rules

    var displayName: String {
        switch self {
        case .whitelist: return "Whitelist Mode"
        case .blacklist: return "Blacklist Mode"
        }
    }

    var description: String {
        switch self {
        case .whitelist: return "Only notify for notifications that match your rules"
        case .blacklist: return "Notify for everything except what matches blocking rules"
        }
    }
}
