//
//  ContentView.swift
//  Pace
//
//  Created by jan on 11/02/2025.
//

import SwiftUI



struct ContentView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager
    
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar.circle")
                }
            
            ScheduleView()
                .tabItem {
                    Label("Week", systemImage: "calendar")
                }
            
            SettingsView()
                .environmentObject(stateManager)
                .tabItem {
                    Label("Edit", systemImage: "calendar.badge.plus")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            switch calendarManager.authorizationStatus {
            case .fullAccess:
                calendarManager.fetchEvents(date: Date())
            case .notDetermined:
                calendarManager.requestAccess()
            default:
                break
            }
        }
        .onChange(of: calendarManager.authorizationStatus) { _, newStatus in
            if newStatus == .fullAccess {
                calendarManager.fetchEvents(date: Date())
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
    }
