//
//  AddTask.swift
//  Pace
//
//  Created by jan on 15/02/2025.
//

import SwiftUI
import MapKit

struct AddTask: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager
    @AppStorage("accentColorName") private var accentColorName: String = "blue"

    /// Owned here so `prefetch()` can be called the moment the button is tapped,
    /// giving GPS + reverse-geocode time to complete before the user reaches the
    /// location sheet.
    @StateObject private var locationManager = LocationManager()

    @State private var showAddTask: Bool = false
    
    // Form State
    @State private var title: String = ""
    @State private var startDate = Date()
    @State private var durationIndex = 0
    @State private var placementIndex = 0
    @State private var priorityIndex = 1
    @State private var locationItem: MKMapItem? = nil
    
    // UI State
    @State private var isAutoSelecting = false
    @State private var lastScheduledDate: Date? = nil

    let durations      = TaskDefaults.durations
    let placementTypes = TaskDefaults.placementTypes
    let priorities     = TaskDefaults.priorities
    
    var body: some View {
        Button(action: {
            // Start fetching the current location immediately so it's ready if the
            // user taps "Use Current Location" inside the sheet.
            locationManager.prefetch()
            showAddTask.toggle()
        }) {
            Text("Add Task")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .sheet(isPresented: $showAddTask) {
            NavigationStack {
                Form {
                    Section("Details") {
                        TextField("Event Title", text: $title)
                            .submitLabel(.done)
                        
                        Picker("Priority", selection: $priorityIndex) {
                            ForEach(0..<priorities.count, id: \.self) { index in
                                Text(priorities[index]).tag(index)
                            }
                        }
                        
                        Picker("Placement", selection: $placementIndex) {
                            ForEach(0..<placementTypes.count, id: \.self) { index in
                                Text(placementTypes[index]).tag(index)
                            }
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
                            ForEach(0..<durations.count, id: \.self) { index in
                                Text("\(durations[index]) min").tag(index)
                            }
                        }
                        
                        Button(action: autoSelectDate) {
                            Label("Auto-Schedule", systemImage: "wand.and.stars")
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                        }
                    } header: {
                        Text("Timing")
                    } footer: {
                        if let lastScheduledDate {
                            Text("Last suggested: \(lastScheduledDate.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                    
                    Section("Location") {
                        LocationSearchField(selection: $locationItem,
                                            sharedLocationManager: locationManager)
                    }
                    
                    Section {
                        Button(action: {
                            addEvent()
                            showAddTask = false
                        }) {
                            Text("Create Task")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color.fromAccentName(accentColorName))
                    }
                }
                .navigationTitle("New Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button(role: .close) { showAddTask = false }
                }
                .alert(Text("\(calendarManager.alertTitle)"), isPresented: $calendarManager.showAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Continue") { calendarManager.includeNonWorkingDays = false }
                } message: {
                    Text("\(calendarManager.alertMessage)")
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.thinMaterial)
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
                    lastScheduledDate = scheduledDate
                }
            }
        }
    }
    
    private func addEvent() {
        let selectedDuration = durations[durationIndex]
        let resolvedTitle = title.isEmpty ? "Untitled Task" : title
        
        if let endDate = Calendar.current.date(byAdding: .minute, value: selectedDuration, to: startDate) {
            calendarManager.createEvent(
                title: resolvedTitle,
                startDate: startDate,
                endDate: endDate,
                placementType: placementTypes[placementIndex],
                priority: priorities[priorityIndex],
                location: locationItem?.name
            )
        }
    }
}

#Preview {
    AddTask()
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
}
