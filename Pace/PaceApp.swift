//
//  PaceApp.swift
//  Pace
//
//  Created by jan on 11/02/2025.
//

import SwiftUI

@main
struct PaceApp: App {
    @StateObject var calendarManager = CalendarManager.shared
    @StateObject var stateManager = StateManager()
    @StateObject var notificationManager = NotificationManager.shared

    // @AppStorage makes body re-evaluate whenever the user picks a new colour in
    // AppearanceSettingsView (same UserDefaults key → same source of truth).
    @AppStorage("accentColorName") var accentColorName: String = "blue"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarManager)
                .environmentObject(stateManager)
                .tint(Color.fromAccentName(accentColorName))
        }
    }
}
