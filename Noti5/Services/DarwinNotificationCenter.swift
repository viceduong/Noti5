//
//  DarwinNotificationCenter.swift
//  Noti5
//
//  Darwin notifications for IPC with root helper
//

import Foundation

class DarwinNotificationCenter {
    static let shared = DarwinNotificationCenter()

    // Notification names
    static let matchedNotification = "com.noti5.matched"
    static let rulesUpdatedNotification = "com.noti5.rules.updated"
    static let startNotification = "com.noti5.start"
    static let stopNotification = "com.noti5.stop"
    static let heartbeatNotification = "com.noti5.heartbeat"

    private var observerTokens: [String: Int32] = [:]
    private var callbacks: [String: () -> Void] = [:]

    private init() {}

    // MARK: - Posting Notifications

    func post(_ name: String) {
        let cfName = name as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(cfName),
            nil,
            nil,
            true
        )
    }

    // MARK: - Observing Notifications

    func observe(_ name: String, callback: @escaping () -> Void) {
        callbacks[name] = callback

        let cfName = name as CFString

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { (_, observer, name, _, _) in
                guard let observer = observer,
                      let name = name?.rawValue as String? else { return }

                let center = Unmanaged<DarwinNotificationCenter>.fromOpaque(observer).takeUnretainedValue()
                center.handleNotification(name)
            },
            cfName,
            nil,
            .deliverImmediately
        )
    }

    func removeObserver(_ name: String) {
        callbacks.removeValue(forKey: name)

        let cfName = name as CFString

        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(cfName),
            nil
        )
    }

    private func handleNotification(_ name: String) {
        DispatchQueue.main.async { [weak self] in
            self?.callbacks[name]?()
        }
    }

    // MARK: - Setup

    func startListening() {
        // Listen for matched notifications from helper
        observe(Self.matchedNotification) {
            print("Noti5: Received matched notification from helper")
            HelperManager.shared.checkPendingNotifications()
        }

        // Listen for heartbeat to confirm helper is alive
        observe(Self.heartbeatNotification) {
            HelperManager.shared.helperDidSendHeartbeat()
        }
    }

    func stopListening() {
        removeObserver(Self.matchedNotification)
        removeObserver(Self.heartbeatNotification)
    }

    // MARK: - Helper Control

    func notifyRulesUpdated() {
        post(Self.rulesUpdatedNotification)
    }

    func notifyStart() {
        post(Self.startNotification)
    }

    func notifyStop() {
        post(Self.stopNotification)
    }
}
