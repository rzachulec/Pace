//
//  GeneralSettingsView.swift
//  Pace
//
//  Created by jan on 21/02/2025.
//

import SwiftUI
import EventKit

public struct GeneralSettingsView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared

    @State private var calendarToImport: EKCalendar? = nil
    @State private var showingConfirmation = false
    @State private var importingCalendarID: String? = nil
    @State private var importResult: ImportResult? = nil
    @State private var showingResult = false

    private enum ImportResult {
        case success(calendarName: String, eventCount: Int)
        case partialSuccess(calendarName: String, eventCount: Int)
        case failure(calendarName: String, message: String)
    }

    public var body: some View {
        Form {
            subscribedCalendarsSection
        }
        .navigationTitle("General")
        .onAppear {
            calendarManager.loadSubscribedCalendars()
        }
        .confirmationDialog(
            calendarToImport.map { "Import \"\($0.title)\"?" } ?? "Import Calendar?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Import & Unsubscribe", role: .destructive) {
                guard let calendar = calendarToImport else { return }
                performImport(calendar)
            }
            Button("Cancel", role: .cancel) {
                calendarToImport = nil
            }
        } message: {
            if let name = calendarToImport?.title {
                Text("All events from \"\(name)\" within an 8-year window will be copied to a new personal calendar. The subscription will then be removed — future updates from the source will no longer sync automatically. This cannot be undone.")
            }
        }
        .alert(resultAlertTitle, isPresented: $showingResult) {
            Button("OK") { importResult = nil }
        } message: {
            Text(resultAlertMessage)
        }
    }

    @ViewBuilder
    private var subscribedCalendarsSection: some View {
        Section {
            if calendarManager.authorizationStatus != .fullAccess {
                Label("Calendar access is required to manage subscribed calendars.", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else if calendarManager.subscribedCalendars.isEmpty {
                Text("No subscribed calendars found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(calendarManager.subscribedCalendars, id: \.calendarIdentifier) { calendar in
                    calendarRow(for: calendar)
                }
            }
        } header: {
            Text("Subscribed Calendars")
        } footer: {
            Text("Events in subscribed calendars are read-only and cannot be rescheduled or edited. Import a copy to your own calendar to make them actionable in Pace. The original subscription is removed after import to avoid duplicates.")
        }
    }

    @ViewBuilder
    private func calendarRow(for calendar: EKCalendar) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(calendar.cgColor.map { Color($0) } ?? Color.secondary)
                .frame(width: 12, height: 12)
            Text(calendar.title)
            Spacer()
            if importingCalendarID == calendar.calendarIdentifier {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Import") {
                    calendarToImport = calendar
                    showingConfirmation = true
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
                .disabled(importingCalendarID != nil)
            }
        }
    }

    private var resultAlertTitle: String {
        switch importResult {
        case .success:        return "Import Complete"
        case .partialSuccess: return "Partially Imported"
        case .failure:        return "Import Failed"
        case nil:             return ""
        }
    }

    private var resultAlertMessage: String {
        switch importResult {
        case .success(let name, let count):
            let noun = count == 1 ? "1 event" : "\(count) events"
            return "\(noun) from \"\(name)\" have been copied to your calendar and the subscription has been removed."
        case .partialSuccess(let name, let count):
            let noun = count == 1 ? "1 event" : "\(count) events"
            return "\(noun) from \"\(name)\" were copied, but the subscription could not be removed automatically. Please delete it manually in the Calendar app to avoid duplicates."
        case .failure(let name, let message):
            return "Could not import \"\(name)\": \(message)"
        case nil:
            return ""
        }
    }

    private func performImport(_ calendar: EKCalendar) {
        let id = calendar.calendarIdentifier
        let name = calendar.title
        importingCalendarID = id

        calendarManager.cloneAndUnsubscribe(calendar) { result in
            importingCalendarID = nil
            switch result {
            case .success(let count):
                importResult = .success(calendarName: name, eventCount: count)
            case .partialSuccess(let count):
                importResult = .partialSuccess(calendarName: name, eventCount: count)
            case .failure(let error):
                importResult = .failure(calendarName: name, message: error.localizedDescription)
            }
            showingResult = true
        }
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
    }
    .environmentObject(StateManager())
}
