//
//  NotifyFilterApp.swift
//  NotifyFilter
//
//  Main app entry point
//

import SwiftUI

@main
struct NotifyFilterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isMonitoring: Bool = false
    @Published var helperRunning: Bool = false
    @Published var matchedNotifications: [MatchedNotification] = []
    @Published var processedCount: Int = 0
    @Published var matchedCount: Int = 0

    private init() {
        loadState()
    }

    func loadState() {
        // Load persisted state
    }

    func saveState() {
        // Save state to disk
    }
}

// MARK: - Matched Notification Model

struct MatchedNotification: Identifiable, Codable {
    let id: UUID
    let bundleId: String
    let title: String
    let subtitle: String?
    let body: String
    let matchedRuleName: String
    let timestamp: Date

    init(bundleId: String, title: String, subtitle: String?, body: String, matchedRuleName: String) {
        self.id = UUID()
        self.bundleId = bundleId
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.matchedRuleName = matchedRuleName
        self.timestamp = Date()
    }
}
