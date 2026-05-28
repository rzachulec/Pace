//
//  UpcomingTasks.swift
//  Pace
//
//  Created by jan on 14/02/2025.
//

import SwiftUI

struct UpcomingTasksList: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager

    // .sheet(item:) drives presentation — selectedTask being non-nil is the
    // single source of truth; no separate showEditTask Bool needed.
    // The old pattern used `if let selectedTask { EditTask(...) }` which
    // conditionally inserted the sheet anchor at the same frame showEditTask
    // became true, causing SwiftUI to miss the presentation.
    @State private var selectedTask: EventData?

    let date: Date
    var upcomingOnly: Bool = true

    private var filterWindowStart: Date {
        Calendar.current.date(
            bySettingHour: stateManager.wakeUpTime,
            minute: 0,
            second: 0,
            of: date
        ) ?? date
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                VStack(spacing: 0) {
                    let now = Date()
                    let windowEnd = filterWindowStart.addingTimeInterval(86_400)
                    let filteredEvents = calendarManager.events.filter {
                        guard let start = $0.startDate, let end = $0.endDate else { return false }
                        return start >= filterWindowStart && end < windowEnd && (!upcomingOnly || start > now) && !$0.isAllDay
                    }.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }

                    if filteredEvents.isEmpty {
                        Text("No tasks.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(filteredEvents, id: \.self) { event in
                            UpcomingTask(event: event) {
                                selectedTask = event   // sheet(item:) presents automatically
                            }
                        }
                    }
                    AddTask()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // Sheet lives here — always in the hierarchy — so SwiftUI sees the modifier
        // before selectedTask becomes non-nil and can reliably present it.
        // EventData is Identifiable so sheet(item:) handles the optional lifecycle.
        .sheet(item: $selectedTask) { task in
            EditTask(event: task)
                .environmentObject(calendarManager)
                .environmentObject(stateManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
        }
    }
}

#Preview {
    UpcomingTasksList(date: Date())
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
}
