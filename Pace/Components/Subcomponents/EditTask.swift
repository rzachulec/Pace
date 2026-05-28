//
//  EditTask.swift
//  Pace
//
//  Created by jan on 15/02/2025.
//

import SwiftUI
import MapKit

struct EditTask: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accentColorName") private var accentColorName: String = "blue"

    var event: EventData

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var durationIndex = 0
    @State private var placementIndex = 0
    @State private var priorityIndex = 1
    @State private var locationItem: MKMapItem? = nil
    
    @State private var isAutoSelecting = false

    let durations      = TaskDefaults.durations
    let placementTypes = TaskDefaults.placementTypes
    let priorities     = TaskDefaults.priorities

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Event Title", text: $title)
                        .submitLabel(.done)
                    
                    Picker("Priority", selection: $priorityIndex) {
                        ForEach(0..<priorities.count, id: \.self) { Text(priorities[$0]).tag($0) }
                    }
                    
                    Picker("Placement", selection: $placementIndex) {
                        ForEach(0..<placementTypes.count, id: \.self) { Text(placementTypes[$0]).tag($0) }
                    }
                }
                
                Section {
                    LabeledContent {
                        DatePicker("Start at", selection: $startDate)
                            .labelsHidden()
                    } label: {
                        HStack {
                            Text("Schedule")
                            if isAutoSelecting {
                                ProgressView()
                                    .controlSize(.mini)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    
                    Picker("Duration", selection: $durationIndex) {
                        ForEach(0..<durations.count, id: \.self) { Text("\(durations[$0]) min").tag($0) }
                    }
                    
                    Button(action: autoSelectDate) {
                        Label("Auto-Reschedule", systemImage: "wand.and.stars")
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                } header: {
                    Text("Timing")
                }
                
                Section("Location") {
                    LocationSearchField(selection: $locationItem)
                }
                
                Section {
                    Button(action: {
                        editEvent()
                        dismiss()
                    }) {
                        Text("Update Task")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.fromAccentName(accentColorName))
                }
                
                Section {
                    Button(role: .destructive, action: {
                        calendarManager.deleteEvent(eventID: event.id)
                        dismiss()
                    }) {
                        Text("Delete Task")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) { dismiss() }
            }
            .onAppear { loadEventData() }
            .alert(Text("\(calendarManager.alertTitle)"), isPresented: $calendarManager.showAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Continue") { calendarManager.includeNonWorkingDays = false }
            } message: {
                Text("\(calendarManager.alertMessage)")
            }
        }
    }

    // MARK: - Helpers

    private func loadEventData() {
        title     = event.title
        startDate = event.startDate ?? Date()
        
        if let index = priorities.firstIndex(of: event.priority) {
            priorityIndex = index
        }
        if let index = placementTypes.firstIndex(of: event.placementType) {
            placementIndex = index
        }
        if let start = event.startDate, let end = event.endDate {
            let duration = Int(end.timeIntervalSince(start) / 60)
            durationIndex = durations.firstIndex(of: duration) ?? 0
        }
        
        // Attempt to resolve location string to MKMapItem
        if let locationName = event.location, !locationName.isEmpty {
            resolveLocation(name: locationName)
        }
    }
    
    private func resolveLocation(name: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            if let item = response?.mapItems.first {
                self.locationItem = item
            } else {
                // If search fails, at least set a "dummy" map item so the name shows up
                let item = MKMapItem(location: CLLocation(latitude: 0, longitude: 0), address: nil)
                item.name = name
                self.locationItem = item
            }
        }
    }

    private func autoSelectDate() {
        withAnimation { isAutoSelecting = true }
        calendarManager.placeTask(
            duration: Double(durations[durationIndex]) * 60,
            workingDays: stateManager.workingDays,
            wakeUpTime: stateManager.wakeUpTime,
            sleepTime: stateManager.sleepTime,
            workStartTime: stateManager.workStartTime,
            workEndTime: stateManager.workEndTime,
            breakDuration: stateManager.breakDuration,
            priority: priorities[priorityIndex],
            newTaskCoordinate: locationItem?.location.coordinate,
            transportMode: stateManager.transportMode,
            travelTimePadding: stateManager.travelTimePadding
        ) { result in
            withAnimation {
                isAutoSelecting = false
                if case .success(let scheduledDate) = result {
                    startDate = scheduledDate
                }
            }
        }
    }

    private func editEvent() {
        let resolvedTitle = title.isEmpty ? (event.title.isEmpty ? "Untitled" : event.title) : title
        guard let fullEnd = Calendar.current.date(byAdding: .minute, value: durations[durationIndex], to: startDate)
        else { return }
        
        // Update the event in EventKit and persistence
        calendarManager.updateEvent(
            eventID: event.id,
            newTitle: resolvedTitle,
            newStartDate: startDate,
            newEndDate: fullEnd,
            placementType: placementTypes[placementIndex],
            priority: priorities[priorityIndex],
            location: locationItem?.name
        )
        
        // No longer need manual save since updateEvent handles it
    }
}
