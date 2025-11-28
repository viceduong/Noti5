//
//  ContentView.swift
//  NotifyFilter
//
//  Main tab view container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Activity", systemImage: "bell.badge")
                }

            RulesListView()
                .tabItem {
                    Label("Rules", systemImage: "checklist")
                }

            AppsListView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
}
