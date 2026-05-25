//
//  ScheduleSettingsView.swift
//  Pace
//
//  Created by jan on 21/02/2025.
//

import SwiftUI

struct ScheduleSettingsView: View {
    @EnvironmentObject var stateManager: StateManager
    
    var body: some View {
        VStack(alignment: .leading) {
            
            
            Form {
                Section(header: Text("Preferred Break Intervals").font(.caption)) {
                    Picker("Break Duration", selection: $stateManager.breakDuration) {
                        ForEach([15, 30, 45, 60], id: \ .self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Maximum Daily Workload").font(.caption)) {
                    Picker("Max Hours", selection: $stateManager.maxWorkingHours) {
                        ForEach(1...18, id: \ .self) { hours in
                            Text("\(hours) hours").tag(hours)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(MenuPickerStyle())
                    #else
                    .pickerStyle(WheelPickerStyle())
                    #endif
                }
                
                Section(header: Text("Wake Up and Sleep Time").font(.caption)) {
                    HStack {
                        Spacer()
                        Text("Wake up       ")
                        Spacer()
                        Text("       Sleep  ")
                        Spacer()
                    }
                    HStack {
                        
                        Picker("Wake Up", selection: $stateManager.wakeUpTime) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text("\(hour):00")
                                    .tag(hour)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(MenuPickerStyle())
                        #else
                        .pickerStyle(WheelPickerStyle())
                        #endif
                        let wake = stateManager.wakeUpTime
                        Picker("Sleep", selection: $stateManager.sleepTime) {
                            // Allowed sleep times: from wake+1 to wake+24
                            ForEach((wake + 1)...(wake + 24), id: \.self) { candidate in
                                // Compute the display hour (0-23) using modulo arithmetic
                                let displayHour = candidate % 24
                                // Optionally indicate if this time is on the next day
                                let nextDayIndicator = candidate >= 24 ? " (next day)" : ""
                                
                                Text("\(displayHour):00" + nextDayIndicator)
                                    .tag(candidate)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(MenuPickerStyle())
                        #else
                        .pickerStyle(WheelPickerStyle())
                        #endif
                    }
                }
                
                Section(header: Text("Preferred task completion hours").font(.caption)) {
                    HStack {
                        Picker("Start", selection: $stateManager.workStartTime) {
                            ForEach(0..<24, id: \ .self) { hour in
                                Text("\(hour):00").tag(hour)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(MenuPickerStyle())
                        #else
                        .pickerStyle(WheelPickerStyle())
                        #endif
                        
                        Text("to")
                        
                        Picker("End", selection: $stateManager.workEndTime) {
                            ForEach((stateManager.workStartTime + 1)...24, id: \ .self) { hour in
                                Text("\(hour):00").tag(hour)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(MenuPickerStyle())
                        #else
                        .pickerStyle(WheelPickerStyle())
                        #endif
                    }
                }
                
                Section(header: Text("Working days").font(.caption)) {
                    ForEach(0..<7, id: \ .self) { index in
                        Toggle(StateManager.DayOfWeek(rawValue: index)!.description, isOn: $stateManager.workingDays[index])
                    }
                }
            }
            .navigationTitle("Schedule Settings")
        }
    }
}

#Preview {
    ScheduleSettingsView()
        .environmentObject(StateManager())
}
