//
//  AppDelegate.swift
//  Noti5
//
//  Handles app lifecycle and background tasks
//

import UIKit
import UserNotifications
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Request notification permissions including Critical Alerts
        requestNotificationPermissions()

        // Register background tasks
        registerBackgroundTasks()

        // Start listening for Darwin notifications from helper
        DarwinNotificationCenter.shared.startListening()

        // Ensure root helper is running
        HelperManager.shared.ensureHelperRunning()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Check helper status when app becomes active
        HelperManager.shared.ensureHelperRunning()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background refresh
        scheduleBackgroundRefresh()
    }

    // MARK: - Notification Permissions

    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Request Critical Alert permission (requires entitlement)
        center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            if granted {
                print("Noti5: Notification permissions granted (including Critical Alerts)")
            } else if let error = error {
                print("Noti5: Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.noti5.refresh",
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.noti5.monitor",
            using: nil
        ) { task in
            self.handleBackgroundMonitor(task: task as! BGProcessingTask)
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.noti5.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1 minute

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Noti5: Failed to schedule background refresh: \(error)")
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Ensure helper is still running
        HelperManager.shared.ensureHelperRunning()

        // Schedule next refresh
        scheduleBackgroundRefresh()

        task.setTaskCompleted(success: true)
    }

    private func handleBackgroundMonitor(task: BGProcessingTask) {
        // Check for any pending matched notifications
        HelperManager.shared.checkPendingNotifications()

        task.setTaskCompleted(success: true)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo

        if let bundleId = userInfo["originalBundleId"] as? String {
            // Could open the original app here
            print("Noti5: User tapped notification from \(bundleId)")
        }

        completionHandler()
    }
}
