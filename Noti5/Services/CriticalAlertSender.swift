//
//  CriticalAlertSender.swift
//  Noti5
//
//  Sends Critical Alert notifications that bypass Do Not Disturb
//

import Foundation
import UserNotifications

class CriticalAlertSender {
    static let shared = CriticalAlertSender()

    private let notificationCenter = UNUserNotificationCenter.current()
    private var recentNotifications: [String: Date] = [:]
    private let deduplicationWindow: TimeInterval = 300  // 5 minutes

    private init() {}

    // MARK: - Send Critical Alert

    func sendAlert(title: String, body: String, bundleId: String, ruleName: String) {
        // Check for duplicate
        let fingerprint = "\(bundleId)|\(title)|\(body)".hashValue
        let key = String(fingerprint)

        if let lastSent = recentNotifications[key],
           Date().timeIntervalSince(lastSent) < deduplicationWindow {
            print("Noti5: Skipping duplicate notification")
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        // Add app name as subtitle if we can identify it
        if let appName = KnownApp.find(bundleId: bundleId)?.name {
            content.subtitle = "via \(appName)"
        }

        // Critical Alert sound - bypasses DND
        content.sound = .defaultCriticalSound(withAudioVolume: 0.8)

        // Set interruption level for iOS 15+
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .critical
        }

        // Store metadata
        content.userInfo = [
            "originalBundleId": bundleId,
            "matchedRuleName": ruleName,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Thread identifier for grouping
        content.threadIdentifier = bundleId

        // Create request
        let identifier = "noti5-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        // Send
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                print("Noti5: Failed to send critical alert: \(error)")
            } else {
                print("Noti5: Critical alert sent for \(title)")

                // Track for deduplication
                self?.recentNotifications[key] = Date()

                // Update app state
                DispatchQueue.main.async {
                    AppState.shared.matchedCount += 1
                }
            }
        }

        // Cleanup old deduplication entries
        cleanupDeduplicationCache()
    }

    // MARK: - Authorization

    func checkAuthorization(completion: @escaping (Bool, Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized
            let criticalAuthorized = settings.criticalAlertSetting == .enabled

            DispatchQueue.main.async {
                completion(authorized, criticalAuthorized)
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Deduplication

    private func cleanupDeduplicationCache() {
        let now = Date()
        recentNotifications = recentNotifications.filter { _, date in
            now.timeIntervalSince(date) < deduplicationWindow * 2
        }
    }

    // MARK: - Testing

    func sendTestAlert() {
        sendAlert(
            title: "Test Notification",
            body: "This is a test critical alert from Noti5. It should play sound even in Do Not Disturb mode.",
            bundleId: "com.noti5.test",
            ruleName: "Test Rule"
        )
    }
}
