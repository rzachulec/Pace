//
//  PrivacySettingsView.swift
//  Pace
//
//  Created by jan on 21/02/2025.
//

import SwiftUI
import EventKit
import UserNotifications
import CoreLocation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct PrivacySettingsView: View {
    @EnvironmentObject private var calendarManager: CalendarManager
    @StateObject private var locationManager = LocationManager()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    public var body: some View {
        List {
            Section {
                permissionRow(
                    title: "Calendar",
                    icon: "calendar",
                    statusText: calendarStatusText,
                    statusColor: calendarStatusColor,
                    actionTitle: calendarActionTitle,
                    action: {
                        if calendarManager.authorizationStatus == .notDetermined {
                            calendarManager.requestAccess()
                        } else {
                            openSettings()
                        }
                    }
                )
                
                permissionRow(
                    title: "Location",
                    icon: "location",
                    statusText: locationStatusText,
                    statusColor: locationStatusColor,
                    actionTitle: locationActionTitle,
                    action: {
                        if locationManager.authorizationStatus == .notDetermined {
                            Task {
                                _ = await locationManager.requestCurrentLocation()
                            }
                        } else {
                            openSettings()
                        }
                    }
                )
                
                permissionRow(
                    title: "Notifications",
                    icon: "bell",
                    statusText: notificationStatusText,
                    statusColor: notificationStatusColor,
                    actionTitle: notificationActionTitle,
                    action: {
                        if notificationStatus == .notDetermined {
                            Task { await requestNotificationAccess() }
                        } else {
                            openSettings()
                        }
                    }
                )
            } header: {
                Text("Permissions")
            } footer: {
                Text("Pace uses these permissions to organize your schedule locally. Your data never leaves your device.")
            }
        }
        .navigationTitle("Privacy")
        .task { await refreshNotificationStatus() }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        icon: String,
        statusText: String,
        statusColor: Color,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(statusText)
                    .foregroundStyle(statusColor)
                    .font(.subheadline)
            }
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        // On macOS, we can open the specific Privacy & Security pane
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_All"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func requestNotificationAccess() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshNotificationStatus()
    }

    // MARK: - Calendar Status Helpers

    private var calendarStatusText: String {
        switch calendarManager.authorizationStatus {
        case .fullAccess:    return "Allowed"
        case .notDetermined: return "Not Set"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .writeOnly:     return "Write Only"
        @unknown default:    return "Unknown"
        }
    }

    private var calendarStatusColor: Color {
        calendarManager.authorizationStatus == .fullAccess ? .green : .secondary
    }

    private var calendarActionTitle: String {
        calendarManager.authorizationStatus == .notDetermined ? "Allow Calendar Access" : "Go to Settings"
    }

    // MARK: - Location Status Helpers

    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "Allowed"
        case .notDetermined: return "Not Set"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        @unknown default:    return "Unknown"
        }
    }

    private var locationStatusColor: Color {
        (locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways) ? .green : .secondary
    }

    private var locationActionTitle: String {
        locationManager.authorizationStatus == .notDetermined ? "Allow Location Access" : "Go to Settings"
    }

    // MARK: - Notification Status Helpers

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized:    return "Allowed"
        case .notDetermined: return "Not Set"
        case .denied:        return "Denied"
        case .provisional:   return "Provisional"
        case .ephemeral:     return "Ephemeral"
        @unknown default:    return "Unknown"
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
