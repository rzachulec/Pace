//
//  AddTask.swift
//  Pace
//
//  Created by jan on 15/02/2025.
//

import SwiftUI

struct AddTask: View {
    @EnvironmentObject var calendarManager: CalendarManager

    @State private var showAddTask: Bool = false
    @State private var title: String = ""
    @State var startDate = Date()
    @State var startTime = Date()
    @State private var durationIndex = 0
    @State private var isDatePressed = false
    @State private var isTimePressed = false
    let durations = [30, 60, 90, 120]
    
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
            VStack(spacing: 20) {
                
                Text("Add Task")
                    .font(.headline)
                
                TextField("Event Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    Button(action: autoSelectDate) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.blue)
                            .padding(8.5)
                            .padding(.horizontal)
                            .scaleEffect(isDatePressed ? 1.2 : 1.0)
                            .background(isDatePressed ? Color.blue.opacity(0.7) : Color.gray.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in isDatePressed = true }
                        .onEnded { _ in isDatePressed = false }
                    )
                    .animation(.easeInOut(duration: 0.7), value: isDatePressed)
                }
                .padding(.horizontal)
                
                
                HStack {
                    DatePicker("Start time", selection: $startTime,
                               displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    Button(action: autoSelectTime) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.blue)
                            .padding(8.5)
                            .padding(.horizontal)
                            .scaleEffect(isTimePressed ? 1.2 : 1.0)
                            .background(isTimePressed ? Color.blue.opacity(0.7) : Color.gray.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in isTimePressed = true }
                        .onEnded { _ in isTimePressed = false }
                    )
                    .animation(.easeInOut(duration: 0.7), value: isTimePressed)
                }
                .padding(.horizontal)
                
                Picker("Duration", selection: $durationIndex) {
                    ForEach(0..<durations.count, id: \.self) { index in
                        Text("\(durations[index]) min").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Button(action: {
                    addEvent()
                    showAddTask.toggle()
                }) {
                    Text("Add Task")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showAddTask = false
                        }) {
                            Text("Done")
                                .font(.title3)
                        }
                    }
                    Spacer()
                }
            )
            .padding()
            .padding(.top)
            .presentationDetents([.medium, .large])
            .presentationBackground(.thinMaterial)
        }
    }
    
    func autoSelectDate() {
        let calendar = Calendar.current
        if let nextWeekday = calendar.nextDate(after: Date(), matching: DateComponents(hour: 9), matchingPolicy: .nextTime) {
            startDate = nextWeekday
        }
        autoSelectTime()
    }
    
    func autoSelectTime() {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        startTime = calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? Date()
    }

    func addEvent() {
        let selectedDuration = durations[durationIndex]
        
        // combine date and time
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        
        if let fullStartDate = calendar.date(from: dateComponents) {
            if let endDate = calendar.date(byAdding: .minute, value: selectedDuration, to: fullStartDate) {
                    print("Adding event: '\(title)' on \(fullStartDate) for \(selectedDuration) minutes")
                    calendarManager.createEvent(title: title, startDate: fullStartDate, endDate: endDate)
            }
        }
    }
}

#Preview {
    AddTask()
}
