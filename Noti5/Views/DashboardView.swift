//
//  DashboardView.swift
//  Noti5
//
//  Main dashboard showing monitoring status and recent activity
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var ruleStorage = RuleStorage.shared

    @State private var showingTestAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Card
                    StatusCard(
                        isMonitoring: appState.isMonitoring,
                        helperRunning: appState.helperRunning
                    )

                    // Statistics
                    StatisticsSection(
                        processedCount: appState.processedCount,
                        matchedCount: appState.matchedCount
                    )

                    // Recent Activity
                    RecentActivitySection(
                        notifications: appState.matchedNotifications
                    )
                }
                .padding()
            }
            .navigationTitle("Noti5")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { sendTestAlert() }) {
                            Label("Send Test Alert", systemImage: "bell.badge")
                        }

                        Button(action: { restartHelper() }) {
                            Label("Restart Helper", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func sendTestAlert() {
        CriticalAlertSender.shared.sendTestAlert()
    }

    private func restartHelper() {
        HelperManager.shared.stopHelper()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            HelperManager.shared.spawnRootHelper()
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let isMonitoring: Bool
    let helperRunning: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.headline)

                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Helper", systemImage: helperRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(helperRunning ? .green : .red)
                        .font(.subheadline)

                    Label("Monitoring", systemImage: isMonitoring ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(isMonitoring ? .green : .secondary)
                        .font(.subheadline)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        if helperRunning && isMonitoring {
            return .green
        } else if helperRunning {
            return .yellow
        } else {
            return .red
        }
    }

    private var statusText: String {
        if helperRunning && isMonitoring {
            return "Active - Monitoring"
        } else if helperRunning {
            return "Helper Running"
        } else {
            return "Inactive"
        }
    }
}

// MARK: - Statistics Section

struct StatisticsSection: View {
    let processedCount: Int
    let matchedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 16) {
                StatCard(title: "Processed", value: "\(processedCount)", icon: "tray.full")
                StatCard(title: "Matched", value: "\(matchedCount)", icon: "bell.badge")

                let rate = processedCount > 0 ? Double(matchedCount) / Double(processedCount) * 100 : 0
                StatCard(title: "Match Rate", value: String(format: "%.0f%%", rate), icon: "percent")
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Recent Activity Section

struct RecentActivitySection: View {
    let notifications: [MatchedNotification]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)

                Spacer()

                if !notifications.isEmpty {
                    NavigationLink(destination: NotificationHistoryView()) {
                        Text("See All")
                            .font(.subheadline)
                    }
                }
            }

            if notifications.isEmpty {
                EmptyActivityCard()
            } else {
                ForEach(notifications.prefix(5)) { notification in
                    ActivityCard(notification: notification)
                }
            }
        }
    }
}

struct EmptyActivityCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No recent notifications")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Matched notifications will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ActivityCard: View {
    let notification: MatchedNotification

    var body: some View {
        HStack(spacing: 12) {
            // App icon placeholder
            Image(systemName: appIcon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text("Matched: \(notification.matchedRuleName)")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var appIcon: String {
        KnownApp.find(bundleId: notification.bundleId)?.iconSystemName ?? "app"
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.timestamp, relativeTo: Date())
    }
}

// MARK: - Notification History View

struct NotificationHistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            ForEach(appState.matchedNotifications) { notification in
                ActivityCard(notification: notification)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Notification History")
    }
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(AppState.shared)
    }
}
#endif
