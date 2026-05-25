//
//  AddTask.swift
//  Pace
//
//  Created by jan on 15/02/2025.
//

import SwiftUI

struct AddTask: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager

    @State private var showAddTask: Bool = false
    @State private var title: String = ""
    @State var startDate = Date()
    @State var prevStartDate = Date()
    @State private var durationIndex = 0
    @State private var placementIndex = 0
    @State private var priorityIndex = 1
    @State private var isDatePressed = false
    @AppStorage("accentColorName") private var accentColorName: String = "blue"
    let durations      = TaskDefaults.durations
    let placementTypes = TaskDefaults.placementTypes
    let priorities     = TaskDefaults.priorities
    
    var body: some View {
        Button(action: {
            showAddTask.toggle()
        }) {
            Text("Add Task")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .sheet(isPresented: $showAddTask) {
            NavigationStack {
            VStack(spacing: 20) {

                Picker("Priority", selection: $priorityIndex) {
                    ForEach(0..<priorities.count, id: \.self) { index in
                        Text("\(priorities[index])").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Picker("Placement Type", selection: $placementIndex) {
                    ForEach(0..<placementTypes.count, id: \.self) { index in
                        Text("\(placementTypes[index])").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                DatePicker("Start at", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                    .shadow(color:  Color.white.opacity(0.6), radius: (startDate != prevStartDate) ? (isDatePressed ? 20 : 0) : 0)
                    .shadow(color:  Color.white.opacity(0.5), radius: (startDate != prevStartDate) ? (isDatePressed ? 50 : 0) : 0 )
                    .shadow(color:  Color.white.opacity(0.4), radius: (startDate != prevStartDate) ? (isDatePressed ? 70 : 0) : 0 )
                    .animation(.easeInOut(duration: 1), value: isDatePressed)
//                    .onChange(of: startDate) { oldValue, newValue in
//                        if newValue != oldValue {
//                            prevStartDate = newValue
//                        }
//                    }
    
                
                TextField("Event Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Picker("Duration", selection: $durationIndex) {
                    ForEach(0..<durations.count, id: \.self) { index in
                        Text("\(durations[index]) min").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Button(action: autoSelectDate) {
                        Image(systemName: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .padding(.horizontal)
                            .scaleEffect(isDatePressed ? 1.2 : 1.0)
                            .background(Color.fromAccentName(accentColorName))
                            .shadow(color:  Color.white.opacity(1), radius: isDatePressed ? 20 : 0)
                            .shadow(color:  Color.white.opacity(0.7), radius: isDatePressed ? 50 : 0)
                            .shadow(color:  Color.white.opacity(0.5), radius: isDatePressed ? 70 : 0)
                            .cornerRadius(8)
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in isDatePressed = true }
                        .onEnded { _ in isDatePressed = false }
                    )
                    .animation(.easeInOut(duration: 1), value: isDatePressed)
                    .padding(.horizontal)
                    .onChange(of: startDate) { oldValue, newValue in
                        prevStartDate = oldValue
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            prevStartDate = newValue
                        }
                    }
                
                
                Button(action: {
                    addEvent()
                    showAddTask.toggle()
                }) {
                    Text("Add Task")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.fromAccentName(accentColorName))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) { showAddTask = false }
            }
            .alert(Text("\(calendarManager.alertTitle)"), isPresented: $calendarManager.showAlert, actions: {
                Button("Cancel", role: .cancel) {}
                Button(action: { calendarManager.includeNonWorkingDays = false }) { Text("Continue") }
            }, message: {
                Text("\(calendarManager.alertMessage)")
            })
            } // NavigationStack
            .presentationDetents([.fraction(0.7)])
            .presentationBackground(.thinMaterial)
        }
    }
    
    func autoSelectDate() {
//        let calendar = Calendar.current
//        if let nextWeekday = calendar.nextDate(after: Date(), matching: DateComponents(hour: 9), matchingPolicy: .nextTime) {
//            startDate = nextWeekday
//        }
//        autoSelectTime()
        
        calendarManager.placeTask(duration: Double(durations[durationIndex]) * 60, workingDays: stateManager.workingDays, wakeUpTime: stateManager.wakeUpTime, sleepTime: stateManager.sleepTime, workStartTime: stateManager.workStartTime, workEndTime: stateManager.workEndTime, breakDuration: stateManager.breakDuration, priority: priorities[priorityIndex]) { result in
            switch result {
                case .success(let scheduledDate):
                startDate = scheduledDate
//                prevStartDate = startDate
                    print("Task scheduled at: \(scheduledDate)")
                case .failure(let error):
                    print("Error: \(error.localizedDescription)")
                    }
        }
    }
    

    func addEvent() {
        let selectedDuration = durations[durationIndex]
        
        let calendar = Calendar.current
        
        if title.isEmpty {
            title = "Untitled"
        }
        
        if let endDate = calendar.date(byAdding: .minute, value: selectedDuration, to: startDate) {
            print("Adding event: '\(title)' on \(startDate) for \(selectedDuration) minutes")
                calendarManager.createEvent(title: title, startDate: startDate, endDate: endDate, placementType: placementTypes[placementIndex], priority: priorities[priorityIndex])
        }
    }
}

#Preview {
    AddTask()
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
}
