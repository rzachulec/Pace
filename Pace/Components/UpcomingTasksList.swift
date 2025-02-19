//
//  UpcomingTasks.swift
//  Pace
//
//  Created by jan on 14/02/2025.
//

import SwiftUI
import EventKit

struct UpcomingTasksList: View {
    @EnvironmentObject var calendarManager: CalendarManager
    
    @State private var selectedTask: EKEvent?
    @State var showEditTask: Bool = false
    @State var date: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView() {
                VStack(spacing: 0) {
                    let filteredEvents = calendarManager.events.filter {
                        $0.startDate >= date && $0.endDate < date.addingTimeInterval(60 * 60 * 24)
                    }
                    
                    if filteredEvents.isEmpty {
                        VStack {
                            Text("No tasks.")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding()
                            
                            
                            AddTask(startDate: date)
                        }
                    } else {
                        ForEach(filteredEvents, id: \.self) { event in
                            UpcomingTask(event: event, showEditTask: showEditTask) {
                                selectedTask = event
                                showEditTask = true
                            }
                        }
                        AddTask(startDate: date)
                    }
                }
                .zIndex(-1)
            }
            if let unwrappedSelectedTask = selectedTask {
                EditTask(showEditTask: $showEditTask, event: unwrappedSelectedTask)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    UpcomingTasksList()
        .environmentObject(CalendarManager())
}
