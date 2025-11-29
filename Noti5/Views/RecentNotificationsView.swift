//
//  RecentNotificationsView.swift
//  Noti5
//
//  Displays recent notifications for easy rule creation
//

import SwiftUI

struct RecentNotificationsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var ruleStorage = RuleStorage.shared

    @State private var recentNotifications: [RecentNotification] = []
    @State private var selectedNotification: RecentNotification?
    @State private var showingRuleCreation = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading notifications...")
            } else if recentNotifications.isEmpty {
                EmptyRecentView()
            } else {
                List {
                    ForEach(recentNotifications) { notification in
                        RecentNotificationRow(notification: notification)
                            .onTapGesture {
                                selectedNotification = notification
                                showingRuleCreation = true
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Recent Notifications")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshNotifications) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            refreshNotifications()
        }
        .sheet(isPresented: $showingRuleCreation) {
            if let notification = selectedNotification {
                CreateRuleFromNotificationView(notification: notification)
            }
        }
    }

    private func refreshNotifications() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let notifications = HelperManager.shared.loadRecentNotifications()
            DispatchQueue.main.async {
                self.recentNotifications = notifications
                self.isLoading = false
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyRecentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Recent Notifications")
                .font(.headline)

            Text("Notifications from your apps will appear here once the helper is running and monitoring.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Notification Row

struct RecentNotificationRow: View {
    let notification: RecentNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: appIcon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                Text(timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let subtitle = notification.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(notification.body)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack {
                Spacer()
                Text("Tap to create rule")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
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

// MARK: - Create Rule From Notification

struct CreateRuleFromNotificationView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var ruleStorage = RuleStorage.shared

    let notification: RecentNotification

    @State private var ruleName: String = ""
    @State private var matchBundleId = true
    @State private var matchTitle = false
    @State private var matchBody = false
    @State private var titleContains: String = ""
    @State private var bodyContains: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notification Details")) {
                    HStack {
                        Text("App")
                        Spacer()
                        Text(notification.bundleId)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    HStack {
                        Text("Title")
                        Spacer()
                        Text(notification.title)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    if let subtitle = notification.subtitle, !subtitle.isEmpty {
                        HStack {
                            Text("Subtitle")
                            Spacer()
                            Text(subtitle)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Body")
                        Text(notification.body)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Section(header: Text("Rule Settings")) {
                    TextField("Rule Name", text: $ruleName)

                    Toggle("Match App (Bundle ID)", isOn: $matchBundleId)

                    Toggle("Match Title Contains", isOn: $matchTitle)
                    if matchTitle {
                        TextField("Title contains...", text: $titleContains)
                    }

                    Toggle("Match Body Contains", isOn: $matchBody)
                    if matchBody {
                        TextField("Body contains...", text: $bodyContains)
                    }
                }

                Section(header: Text("Preview")) {
                    Text(ruleDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Create Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createRule()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(ruleName.isEmpty || (!matchBundleId && !matchTitle && !matchBody))
                }
            }
            .onAppear {
                ruleName = "Rule for \(KnownApp.find(bundleId: notification.bundleId)?.name ?? notification.bundleId)"
                titleContains = notification.title
                bodyContains = notification.body
            }
        }
    }

    private var ruleDescription: String {
        var conditions: [String] = []

        if matchBundleId {
            conditions.append("App is \(notification.bundleId)")
        }
        if matchTitle && !titleContains.isEmpty {
            conditions.append("Title contains \"\(titleContains)\"")
        }
        if matchBody && !bodyContains.isEmpty {
            conditions.append("Body contains \"\(bodyContains)\"")
        }

        if conditions.isEmpty {
            return "No conditions set"
        }

        return conditions.joined(separator: " AND ")
    }

    private func createRule() {
        var conditions: [RuleCondition] = []

        if matchBundleId {
            conditions.append(RuleCondition(
                field: .app,
                matchType: .equals,
                value: notification.bundleId
            ))
        }

        if matchTitle && !titleContains.isEmpty {
            conditions.append(RuleCondition(
                field: .sender,
                matchType: .contains,
                value: titleContains
            ))
        }

        if matchBody && !bodyContains.isEmpty {
            conditions.append(RuleCondition(
                field: .keyword,
                matchType: .contains,
                value: bodyContains
            ))
        }

        let rule = FilterRule(
            name: ruleName,
            conditions: conditions
        )

        ruleStorage.addRule(rule)
    }
}

#if DEBUG
struct RecentNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RecentNotificationsView()
                .environmentObject(AppState.shared)
        }
    }
}
#endif
