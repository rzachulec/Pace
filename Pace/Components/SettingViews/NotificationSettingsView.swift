//
//  NotificationSettingsView.swift
//  Pace
//
//  Created by jan on 21/02/2025.
//

import SwiftUI

public struct NotificationSettingsView: View {
    @EnvironmentObject var stateManager: StateManager

    public var body: some View {
        Form {
            Toggle("Enable notifications", isOn: $stateManager.notificationsEnabled)
            Section(header: Text("Notification time").font(.caption)) {
                Picker("How many minutes before task starts", selection: $stateManager.notificationInterval) {
                    ForEach([15*60, 30*60, 45*60, 60*60], id: \ .self) { minutes in
                        Text("\(minutes/60) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
