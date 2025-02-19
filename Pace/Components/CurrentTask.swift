//
//  CurrentTask.swift
//  Pace
//
//  Created by jan on 14/02/2025.
//

import SwiftUI
import EventKit


struct CurrentTask: View {
    @EnvironmentObject var calendarManager: CalendarManager
    
    @State var minutesRemaining: Int = 0
    @State var fillProgress: Double = 0.0
    @State private var showEditTask = false
    @State private var selectedTask: EKEvent? = nil
    
    var offsetY: CGFloat = -50
    var material: Material = .ultraThinMaterial
    
    var currentEvent: EKEvent? {
        let now = Date()
        return calendarManager.events.first { event in
            // all day events are not taken into account...
            // TODO: Handle all day events?
            guard !event.isAllDay else { return false }
            
            return now >= event.startDate && now <= event.endDate
        }
    }
    
    var nextEvent: EKEvent? {
        let now = Date()
        return calendarManager.events
            .filter { $0.startDate > now  && $0.startDate < now.addingTimeInterval(60 * 60 * 24)}
            .sorted { $0.startDate < $1.startDate }
            .first
    }
    
    func updateRemainingTime() {
        if let event = currentEvent {
            let now = Date()
            let remaining = Int(event.endDate.timeIntervalSince(now) / 60)
            minutesRemaining = max(remaining, 0) // Prevent negative values
        } else {
            minutesRemaining = 0
        }
    }
    
    func formattedTime(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
    }
    
    var body: some View {
        GeometryReader { geometry in
            
            if let event = currentEvent {
                if let startDate = event.startDate, let endDate = event.endDate {
                    let eventDuration = endDate.timeIntervalSince(startDate) / 60
                    let fillProgress = Double(eventDuration - Double(minutesRemaining)) / Double(eventDuration)
                    HStack{
                        VStack(alignment: .leading) {
                            Text("Current Task:")
                            Text("\(event.title ?? "Untitled Event")")
                                .font(.title)
                                .fontWeight(.semibold)
                            Text("\(minutesRemaining) min remaining")
                        }
                        
                        Spacer()
                        
                        Text("Hold for \n details")
                            .font(.caption)
                    }
                    .onAppear {
                        updateRemainingTime()
                        
                        // update value every 30 seconds
                        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                            updateRemainingTime()
                        }
                    }
                    .padding()
                    .background(
                        Image("Background")
                            .resizable()
                            .scaledToFill()
                            .clipShape(Rectangle())
                            .frame(height: 130)
                            .offset(y: offsetY-80)
                            .padding(-10)
                            .blur(radius: 15)
                            .brightness(0.1)
                            .contrast(0.7)
                            .saturation(1.2)
                            .mask(
                                HStack {
                                    RoundedRectangle(cornerRadius: 25)
                                        .frame(width: geometry.size.width * fillProgress)
                                        .foregroundColor(Color(red: 0.476471, green: 0.927451, blue: 0.678431))
                                        .opacity(0.6)
                                    
                                    Spacer()
                                }
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.gray, lineWidth: 1)
                    )
                    .contextMenu {
                        VStack {
                            Button(action: { print("Cut") }) {
                                Label("View in calendar", systemImage: "calendar")
                            }
                            Button(action: {
                                selectedTask = event
                                showEditTask = true
                            }) {
                                Label("Edit", systemImage: "slider.horizontal.below.rectangle")
                            }
                            Button(action: { print("Paste") }) {
                                Label("Mark done", systemImage: "checkmark")
                            }
                        }
                    }
                }
            } else if let event = nextEvent, let startDate = nextEvent?.startDate {
                HStack{
                    VStack(alignment: .leading) {
                        Text("Next Task:")
                        Text("\(event.title ?? "Untitled Event")")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Starts at \(formattedTime(from: startDate))")
                    }
                    
                    Spacer()
                    
                    Text("Hold for \n details")
                        .font(.caption)
                }
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.gray, lineWidth: 1)
                )
                .contextMenu {
                    VStack {
                        Button(action: { print("Cut") }) {
                            Label("View in calendar", systemImage: "calendar")
                        }
                        Button(action: {
                            selectedTask = event
                            showEditTask = true
                        }) {
                            Label("Edit", systemImage: "slider.horizontal.below.rectangle")
                        }
                        Button(action: { print("Paste") }) {
                            Label("Mark done", systemImage: "checkmark")
                        }
                    }
                }
            } else {
                HStack{
                    VStack(alignment: .leading) {
                        Text("")
                        Text("No upcoming tasks.")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Check back tomorrow or add a new one.")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text("")
                        .font(.caption)
                }
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.gray, lineWidth: 1)
                )
            }
        }
        .frame(height: 100)
        if let event = currentEvent{
            EditTask(showEditTask: $showEditTask, event: event)
        }
        else if let event = nextEvent {
            EditTask(showEditTask: $showEditTask, event: event)
        }
    }
}

#Preview {
    CurrentTask()
        .environmentObject(CalendarManager())
}
