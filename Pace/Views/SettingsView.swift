//
//  SettingsView.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import SwiftUI

struct SettingsView: View {

    @State private var searchText = ""

    // Typed enum instead of AnyView-wrapped views stored in a let array.
    // AnyView erases type identity, causing SwiftUI to rebuild the destination
    // view on every SettingsView re-evaluation (e.g. every 10 s from the
    // StateManager timer). Using NavigationLink(value:) + navigationDestination
    // means the destination is only instantiated when the user navigates, and
    // SwiftUI can properly track identity across re-renders.
    private enum Destination: String, Hashable {
        case general, schedule, appearance, notifications, privacy, help
    }

    private struct Item: Identifiable {
        let id: Destination
        let title: String
        let icon: String
    }

    private let items: [Item] = [
        Item(id: .general,       title: "General",        icon: "gear"),
        Item(id: .schedule,      title: "Schedule",       icon: "calendar"),
        Item(id: .appearance,    title: "Appearance",     icon: "paintbrush"),
        Item(id: .notifications, title: "Notifications",  icon: "bell"),
        Item(id: .privacy,       title: "Privacy",        icon: "lock.shield"),
        Item(id: .help,          title: "Help & Support", icon: "questionmark.circle"),
    ]

    private var filteredItems: [Item] {
        searchText.isEmpty
            ? items
            : items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item.id) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .searchable(text: $searchText, prompt: "Search Settings")
            .navigationDestination(for: Destination.self) { dest in
                // Views are created on demand here, not eagerly in a stored array.
                switch dest {
                case .general:       GeneralSettingsView()
                case .schedule:      ScheduleSettingsView()
                case .appearance:    AppearanceSettingsView()
                case .notifications: NotificationSettingsView()
                case .privacy:       PrivacySettingsView()
                case .help:          HelpView()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(StateManager())
}
