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
    var event: EKEvent
    private let material: Material = .ultraThin
    @State private var showingAlert: Bool = false
    @State var showEditTask: Bool = false
    let onEdit: () -> Void

    
    var body: some View {
        
        HStack {
            Text(event.title)
                .font(.title2)
            
            Spacer()
            
            Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(Int(event.endDate.timeIntervalSince(event.startDate) / 60)) min")
        }

        .padding()
        .background(Color.white.opacity(0.01))
        .overlay(
            Rectangle()
                .strokeBorder(.black.opacity(0.01))
        )
        .contextMenu {
            VStack {
                Button(action: { print("Title: \(event.title ?? "No title")") }) {
                    Label("View in calendar", systemImage: "calendar")
                }
                Button(action: { onEdit() }) {
                    Label("Edit", systemImage: "slider.horizontal.below.rectangle")
                }
                
                Button(action: { print("Mark done") }) {
                    Label("Mark done", systemImage: "checkmark")
                }
                Button(action: { showingAlert = true }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        
        .alert(Text("Are you sure you want to delete this task?"), isPresented: $showingAlert, actions: {
            Button("Cancel", role: .cancel) {}
            Button(role:. destructive, action: { calendarManager.deleteEvent(event: event) }) { Text("Delete")}
        },
               message: {
            Text("This action cannot be undone.")
        }
        )
    }
}
