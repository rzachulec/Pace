//
//  UpcomingTask.swift
//  Pace
//
//  Created by jan on 14/02/2025.
//

import Foundation
import SwiftUI
import EventKit


struct UpcomingTask: View {
    @EnvironmentObject var calendarManager: CalendarManager
    var event: EventData
    @State private var showingAlert: Bool = false
    // Removed: @State var showEditTask — was a value copy from the parent (not @Binding),
    //          so it was always false and editing was handled by the onEdit callback.
    // Removed: private let material — declared but never used.
    let onEdit: () -> Void

    var body: some View {
        // Hoist now so both startDate comparisons use the identical instant.
        let now = Date()
        let isActive = (event.startDate ?? .distantFuture) < now && (event.endDate ?? .distantPast) > now

        let isDynamic = event.placementType == "Dynamic"
        let accentColor: Color = event.ekEvent?.calendar.cgColor.map { Color(cgColor: $0) } ?? .accentColor

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.title3)
                    .fontWeight(.medium)
                
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let start = event.startDate, let end = event.endDate {
                Text("\(start.formatted(date: .omitted, time: .shortened)) - \(Int(end.timeIntervalSince(start) / 60)) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(isActive ? Color.white.opacity(0.5) : Color.white.opacity(0.01))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.opacity(isDynamic ? 0.45 : 0.9))
                .frame(width: 4)
                .padding(.vertical, 6)
                .padding(.leading, 4)
        }
        .overlay(Rectangle().strokeBorder(.black.opacity(0.01)))
        .onTapGesture { onEdit() }
        .contextMenu {
            if let start = event.startDate {
                Button(action: { calendarManager.openCalendarEvent(startDate: start) }) {
                    Label("View in calendar", systemImage: "calendar")
                }
            }
            Button(action: { onEdit() }) {
                Label("Edit", systemImage: "slider.horizontal.below.rectangle")
            }
            Button(action: { showingAlert = true }) {
                Label("Delete", systemImage: "trash").foregroundStyle(.red)
            }
        }
        .alert(Text("Are you sure you want to delete this task?"), isPresented: $showingAlert, actions: {
            Button("Cancel", role: .cancel) {}
            Button(role: .destructive, action: { calendarManager.deleteEvent(eventID: event.id) }) {
                Text("Delete")
            }
        }, message: {
            Text("This action cannot be undone.")
        })
    }
}
