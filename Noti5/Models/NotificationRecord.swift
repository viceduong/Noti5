//
//  NotificationRecord.swift
//  NotifyFilter
//
//  Represents a parsed notification from the SEGB database
//

import Foundation

// MARK: - Notification Record

struct NotificationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let guid: String           // Original GUID from SEGB
    let bundleId: String       // App bundle identifier
    let title: String          // Usually sender name
    let subtitle: String?      // Secondary text
    let body: String           // Message content
    let appleId: String?       // Contact identifier if available
    let timestamp: Date        // When notification was received
    let fileOffset: UInt64     // Offset in SEGB file (for tracking)

    init(guid: String, bundleId: String, title: String, subtitle: String?, body: String, appleId: String?, timestamp: Date, fileOffset: UInt64) {
        self.id = UUID()
        self.guid = guid
        self.bundleId = bundleId
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.appleId = appleId
        self.timestamp = timestamp
        self.fileOffset = fileOffset
    }

    // Hash for deduplication
    var contentHash: String {
        let content = "\(bundleId)|\(title)|\(subtitle ?? "")|\(body)"
        return String(content.hashValue)
    }
}

// MARK: - Known Apps

struct KnownApp: Identifiable {
    let id: String  // Bundle ID
    let name: String
    let category: AppCategory
    let iconSystemName: String

    var bundleId: String { id }
}

enum AppCategory: String, CaseIterable {
    case messaging = "Messaging"
    case social = "Social"
    case work = "Work"
    case email = "Email"
    case other = "Other"
}

// Pre-defined list of common apps
extension KnownApp {
    static let all: [KnownApp] = [
        // Messaging
        KnownApp(id: "net.whatsapp.WhatsApp", name: "WhatsApp", category: .messaging, iconSystemName: "message.fill"),
        KnownApp(id: "ph.telegra.Telegraph", name: "Telegram", category: .messaging, iconSystemName: "paperplane.fill"),
        KnownApp(id: "com.apple.MobileSMS", name: "iMessage", category: .messaging, iconSystemName: "message.fill"),
        KnownApp(id: "org.whispersystems.signal", name: "Signal", category: .messaging, iconSystemName: "lock.fill"),
        KnownApp(id: "com.facebook.Messenger", name: "Messenger", category: .messaging, iconSystemName: "message.circle.fill"),
        KnownApp(id: "com.viber", name: "Viber", category: .messaging, iconSystemName: "phone.fill"),
        KnownApp(id: "com.skype.skype", name: "Skype", category: .messaging, iconSystemName: "video.fill"),

        // Work
        KnownApp(id: "com.tinyspeck.chatlyio", name: "Slack", category: .work, iconSystemName: "number"),
        KnownApp(id: "com.microsoft.skype.teams", name: "Microsoft Teams", category: .work, iconSystemName: "person.3.fill"),
        KnownApp(id: "us.zoom.videomeetings", name: "Zoom", category: .work, iconSystemName: "video.fill"),
        KnownApp(id: "com.discord", name: "Discord", category: .work, iconSystemName: "bubble.left.and.bubble.right.fill"),

        // Email
        KnownApp(id: "com.google.Gmail", name: "Gmail", category: .email, iconSystemName: "envelope.fill"),
        KnownApp(id: "com.microsoft.Office.Outlook", name: "Outlook", category: .email, iconSystemName: "envelope.fill"),
        KnownApp(id: "com.apple.mobilemail", name: "Apple Mail", category: .email, iconSystemName: "envelope.fill"),

        // Social
        KnownApp(id: "com.burbn.instagram", name: "Instagram", category: .social, iconSystemName: "camera.fill"),
        KnownApp(id: "com.atebits.Tweetie2", name: "Twitter/X", category: .social, iconSystemName: "at"),
        KnownApp(id: "com.facebook.Facebook", name: "Facebook", category: .social, iconSystemName: "person.2.fill"),
        KnownApp(id: "com.zhiliaoapp.musically", name: "TikTok", category: .social, iconSystemName: "music.note"),
        KnownApp(id: "com.linkedin.LinkedIn", name: "LinkedIn", category: .social, iconSystemName: "briefcase.fill"),
    ]

    static func find(bundleId: String) -> KnownApp? {
        all.first { $0.bundleId == bundleId }
    }

    static func grouped() -> [AppCategory: [KnownApp]] {
        Dictionary(grouping: all, by: { $0.category })
    }
}

// MARK: - Notification History Entry

struct NotificationHistoryEntry: Codable, Identifiable {
    let id: UUID
    let notification: NotificationRecord
    let evaluationResult: EvaluationResult
    let timestamp: Date

    init(notification: NotificationRecord, result: EvaluationResult) {
        self.id = UUID()
        self.notification = notification
        self.evaluationResult = result
        self.timestamp = Date()
    }
}

struct EvaluationResult: Codable, Equatable {
    let action: RuleAction
    let matchedRuleName: String?
    let matchedRuleId: UUID?
    let wasDefault: Bool  // True if no rule matched, used global default

    static func matched(rule: FilterRule) -> EvaluationResult {
        EvaluationResult(
            action: rule.action,
            matchedRuleName: rule.name,
            matchedRuleId: rule.id,
            wasDefault: false
        )
    }

    static func defaultResult(action: RuleAction) -> EvaluationResult {
        EvaluationResult(
            action: action,
            matchedRuleName: nil,
            matchedRuleId: nil,
            wasDefault: true
        )
    }
}
