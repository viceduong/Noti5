//
//  HelperManager.swift
//  Noti5
//
//  Manages the root helper process lifecycle
//

import Foundation

class HelperManager {
    static let shared = HelperManager()

    private let sharedDataPath = "/var/mobile/Library/Noti5"
    private let matchedFilePath = "/var/mobile/Library/Noti5/matched.json"
    private let rulesFilePath = "/var/mobile/Library/Noti5/rules.json"
    private let pidFilePath = "/var/tmp/noti5.pid"
    private let heartbeatFilePath = "/var/tmp/noti5.heartbeat"

    private var lastHeartbeat: Date?
    private var heartbeatCheckTimer: Timer?

    var isHelperRunning: Bool {
        // Check if PID file exists and process is alive
        guard let pidString = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        // Check if process exists
        return kill(pid, 0) == 0
    }

    private init() {
        setupSharedDirectory()
    }

    // MARK: - Setup

    private func setupSharedDirectory() {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: sharedDataPath) {
            try? fileManager.createDirectory(atPath: sharedDataPath, withIntermediateDirectories: true)
        }
    }

    // MARK: - Helper Lifecycle

    func ensureHelperRunning() {
        if !isHelperRunning {
            spawnRootHelper()
        } else {
            // Helper already running, check heartbeat file to set monitoring status
            checkHelperHealth()
        }

        startHeartbeatMonitoring()
    }

    func spawnRootHelper() {
        guard let helperPath = Bundle.main.path(forResource: "roothelper", ofType: nil) else {
            print("Noti5: Root helper not found in bundle")
            return
        }

        // Spawn root helper using posix_spawn with persona attributes
        let result = spawnAsRoot(path: helperPath, arguments: ["--daemon"])

        if result == 0 {
            print("Noti5: Root helper spawned successfully")
            DispatchQueue.main.async {
                AppState.shared.helperRunning = true
            }
        } else {
            print("Noti5: Failed to spawn root helper, error: \(result)")
        }
    }

    func stopHelper() {
        DarwinNotificationCenter.shared.notifyStop()

        // Also send SIGTERM to helper process
        if let pidString = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
           let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
        }

        DispatchQueue.main.async {
            AppState.shared.helperRunning = false
        }
    }

    // MARK: - posix_spawn as root

    private func spawnAsRoot(path: String, arguments: [String]) -> Int32 {
        var pid: pid_t = 0

        // Prepare arguments
        var args = [path] + arguments
        var cArgs = args.map { strdup($0) }
        cArgs.append(nil)

        defer {
            for arg in cArgs {
                free(arg)
            }
        }

        // Setup spawn attributes for root execution
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)

        // Set persona to root (uid 0, gid 0)
        // This requires com.apple.private.persona-mgmt entitlement
        posix_spawnattr_set_persona_np(&attr, 99, UInt32(POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE))
        posix_spawnattr_set_persona_uid_np(&attr, 0)
        posix_spawnattr_set_persona_gid_np(&attr, 0)

        // Spawn the process
        let result = posix_spawn(&pid, path, nil, &attr, &cArgs, nil)

        posix_spawnattr_destroy(&attr)

        return result
    }

    // MARK: - Heartbeat Monitoring

    private func startHeartbeatMonitoring() {
        heartbeatCheckTimer?.invalidate()

        heartbeatCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkHelperHealth()
        }
    }

    private func checkHelperHealth() {
        // Check heartbeat file timestamp
        if let attrs = try? FileManager.default.attributesOfItem(atPath: heartbeatFilePath),
           let modDate = attrs[.modificationDate] as? Date {
            let elapsed = Date().timeIntervalSince(modDate)

            if elapsed < 60 {
                // Heartbeat file is recent - helper is alive and monitoring
                DispatchQueue.main.async {
                    AppState.shared.isMonitoring = true
                }
            } else {
                // Helper hasn't sent heartbeat in over a minute, restart it
                print("Noti5: Helper heartbeat timeout, restarting...")
                DispatchQueue.main.async {
                    AppState.shared.isMonitoring = false
                }
                spawnRootHelper()
            }
        }
    }

    func helperDidSendHeartbeat() {
        lastHeartbeat = Date()
        DispatchQueue.main.async {
            AppState.shared.helperRunning = true
            AppState.shared.isMonitoring = true
        }
    }

    // MARK: - Rules Management

    func saveRules(_ rules: [FilterRule]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(rules) else {
            print("Noti5: Failed to encode rules")
            return
        }

        try? data.write(to: URL(fileURLWithPath: rulesFilePath))

        // Notify helper that rules changed
        DarwinNotificationCenter.shared.notifyRulesUpdated()
    }

    func loadRules() -> [FilterRule] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: rulesFilePath)) else {
            return []
        }

        let decoder = JSONDecoder()
        return (try? decoder.decode([FilterRule].self, from: data)) ?? []
    }

    // MARK: - Matched Notifications

    func checkPendingNotifications() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: matchedFilePath)) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let notifications = try? decoder.decode([MatchedNotificationData].self, from: data) else {
            return
        }

        // Process and clear
        for notification in notifications {
            CriticalAlertSender.shared.sendAlert(
                title: notification.title,
                body: notification.body,
                bundleId: notification.bundleId,
                ruleName: notification.matchedRuleName
            )
        }

        // Clear the file
        try? "[]".write(toFile: matchedFilePath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Helper Data Types

private struct MatchedNotificationData: Codable {
    let bundleId: String
    let title: String
    let subtitle: String?
    let body: String
    let matchedRuleName: String
    let timestamp: Date
}

// MARK: - posix_spawn persona functions (bridging header needed)

// These functions require a bridging header to import from spawn.h
// For TrollStore, we use the private persona APIs

@_silgen_name("posix_spawnattr_set_persona_np")
func posix_spawnattr_set_persona_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ persona_id: uid_t, _ flags: UInt32) -> Int32

@_silgen_name("posix_spawnattr_set_persona_uid_np")
func posix_spawnattr_set_persona_uid_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ uid: uid_t) -> Int32

@_silgen_name("posix_spawnattr_set_persona_gid_np")
func posix_spawnattr_set_persona_gid_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ gid: gid_t) -> Int32

let POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE: Int32 = 1
