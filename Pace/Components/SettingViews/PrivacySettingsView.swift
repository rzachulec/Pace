//
//  PrivacySettingsView.swift
//  Pace
//
//  Created by jan on 21/02/2025.
//

import SwiftUI
import EventKit
import UserNotifications

public struct PrivacySettingsView: View {
    @EnvironmentObject private var calendarManager: CalendarManager
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    public var body: some View {
        List {
            Section("Permissions") {
                HStack {
                    Label("Calendar", systemImage: "calendar")
                    Spacer()
                    Text(calendarStatusText)
                        .foregroundStyle(calendarStatusColor)
                        .font(.subheadline)
                }

                Button(calendarActionTitle) {
                    if calendarManager.authorizationStatus == .notDetermined {
                        calendarManager.requestAccess()
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }

                HStack {
                    Label("Notifications", systemImage: "bell")
                    Spacer()
                    Text(notificationStatusText)
                        .foregroundStyle(notificationStatusColor)
                        .font(.subheadline)
                }

                Button(notificationActionTitle) {
                    if notificationStatus == .notDetermined {
                        Task { await requestNotificationAccess() }
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Privacy")
        .task { await refreshNotificationStatus() }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func requestNotificationAccess() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshNotificationStatus()
    }

    private var calendarStatusText: String {
        switch calendarManager.authorizationStatus {
        case .fullAccess:    return "Allowed"
        case .notDetermined: return "Not Set"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        default:             return "Unknown"
        }
    }

    private var calendarStatusColor: Color {
        calendarManager.authorizationStatus == .fullAccess ? .green : .secondary
    }

    private var calendarActionTitle: String {
        calendarManager.authorizationStatus == .notDetermined ? "Allow Calendar Access" : "Go to Settings"
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized:    return "Allowed"
        case .notDetermined: return "Not Set"
        case .denied:        return "Denied"
        case .provisional:   return "Provisional"
        case .ephemeral:     return "Ephemeral"
        default:             return "Unknown"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .green
        default:                                     return .secondary
        }
    }

    private var notificationActionTitle: String {
        notificationStatus == .notDetermined ? "Allow Notifications" : "Go to Settings"
    }
}
