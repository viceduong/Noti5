//
//  SettingsView.swift
//  NotifyFilter
//
//  App settings and configuration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var ruleStorage = RuleStorage.shared

    @State private var notificationAuthorized = false
    @State private var criticalAlertAuthorized = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            List {
                // Status Section
                Section(header: Text("Status")) {
                    StatusRow(
                        title: "Notifications",
                        isEnabled: notificationAuthorized,
                        icon: "bell.badge"
                    )

                    StatusRow(
                        title: "Critical Alerts",
                        isEnabled: criticalAlertAuthorized,
                        icon: "bell.badge.fill"
                    )

                    StatusRow(
                        title: "Root Helper",
                        isEnabled: appState.helperRunning,
                        icon: "terminal"
                    )

                    if !notificationAuthorized || !criticalAlertAuthorized {
                        Button("Open Settings") {
                            openSettings()
                        }
                    }
                }

                // Monitoring Section
                Section(header: Text("Monitoring")) {
                    HStack {
                        Text("Monitor Status")
                        Spacer()
                        Text(appState.isMonitoring ? "Active" : "Inactive")
                            .foregroundColor(appState.isMonitoring ? .green : .secondary)
                    }

                    Button(action: restartHelper) {
                        Label("Restart Helper", systemImage: "arrow.clockwise")
                    }

                    Button(action: stopHelper) {
                        Label("Stop Helper", systemImage: "stop.circle")
                    }
                    .foregroundColor(.red)
                }

                // Data Section
                Section(header: Text("Data")) {
                    HStack {
                        Text("Rules")
                        Spacer()
                        Text("\(ruleStorage.rules.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Processed Notifications")
                        Spacer()
                        Text("\(appState.processedCount)")
                            .foregroundColor(.secondary)
                    }

                    Button(action: { showingExportSheet = true }) {
                        Label("Export Rules", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { showingImportPicker = true }) {
                        Label("Import Rules", systemImage: "square.and.arrow.down")
                    }
                }

                // Danger Zone
                Section(header: Text("Danger Zone")) {
                    Button(role: .destructive, action: { showingResetAlert = true }) {
                        Label("Reset All Data", systemImage: "trash")
                    }
                }

                // About Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("TrollStore")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .onAppear {
                checkPermissions()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportRulesView()
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                onCompletion: handleImport
            )
            .alert("Reset All Data?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will delete all rules and notification history. This cannot be undone.")
            }
        }
    }

    private func checkPermissions() {
        CriticalAlertSender.shared.checkAuthorization { authorized, criticalAuthorized in
            self.notificationAuthorized = authorized
            self.criticalAlertAuthorized = criticalAuthorized
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func restartHelper() {
        HelperManager.shared.stopHelper()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            HelperManager.shared.spawnRootHelper()
        }
    }

    private func stopHelper() {
        HelperManager.shared.stopHelper()
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: url) {
                _ = ruleStorage.importRules(from: data)
            }

        case .failure(let error):
            print("Import failed: \(error)")
        }
    }

    private func resetAllData() {
        // Clear rules
        for rule in ruleStorage.rules {
            ruleStorage.deleteRule(rule)
        }

        // Clear app state
        appState.matchedNotifications.removeAll()
        appState.processedCount = 0
        appState.matchedCount = 0
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let title: String
    let isEnabled: Bool
    let icon: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)

            Spacer()

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .red)
        }
    }
}

// MARK: - Export Rules View

struct ExportRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ruleStorage = RuleStorage.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Export Rules")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Export \(ruleStorage.rules.count) rules as JSON")
                    .foregroundColor(.secondary)

                if let data = ruleStorage.exportRules(),
                   let jsonString = String(data: data, encoding: .utf8) {
                    ScrollView {
                        Text(jsonString)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                    }
                    .frame(maxHeight: 300)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()

                    ShareLink(item: jsonString) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
