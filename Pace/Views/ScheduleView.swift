//
//  CalendarView.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager

    @State private var currentDate = Date()
    @State private var showDayView: Bool = false
    @State private var selectedDate: Date?
    // Removed: showEditTask, selectedTask (EKEvent — wrong type), dayLength, wakeTime, sleepTime
    //          — all declared but never assigned or read.

    // MARK: - Shared date helpers (were recomputed 3× per render from identical calendar arithmetic)

    private var startOfWeek: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!
    }

    private var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek)!
    }

    // Static formatters — DateFormatter is expensive to allocate; was being recreated on every
    // render in both currentWeekRange and groupEventsByDay().
    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return f
    }()

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    // MARK: - Data

    private var weekOffset: Int {
        let cal = Calendar.current
        let todayWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return cal.dateComponents([.weekOfYear], from: todayWeek, to: startOfWeek).weekOfYear ?? 0
    }

    var currentWeekRange: String {
        let f = Self.weekRangeFormatter
        let range = "\(f.string(from: startOfWeek)) - \(f.string(from: endOfWeek))"
        let label: String
        switch weekOffset {
        case 0:  label = "This week"
        case 1:  label = "Next week"
        case -1: label = "Last week"
        case let n where n > 1:  label = "In \(n) weeks"
        case let n where n < -1: label = "\(-n) weeks back"
        default: label = "This week"
        }
        return "\(label): \n \(range) \n"
    }

    var filteredEvents: [EventData] {
        let start = startOfWeek
        let end = endOfWeek
        return calendarManager.events.filter { event in
            guard let evStart = event.startDate, let evEnd = event.endDate else { return false }
            return (evStart >= start && evStart <= end) || (evEnd >= start && evEnd <= end)
        }
    }

    // Named tuple — replaces Binding.constant() which is a read-only wrapper that silently
    // drops writes; these values are never mutated by child views.
    private struct DayGroup {
        let day: String
        let date: Date
        let events: [EventData]
    }

    private func groupEventsByDay() -> [DayGroup] {
        let cal = Calendar.current
        let formatter = Self.dayNameFormatter
        let days = (0...6).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
        let names = days.map { formatter.string(from: $0) }
        // filteredEvents is a computed var — pass the result in so it runs once, not twice.
        let grouped = Dictionary(grouping: filteredEvents, by: { formatter.string(from: $0.startDate!) })
        return zip(names, days).map { DayGroup(day: $0, date: $1, events: grouped[$0] ?? []) }
    }

    func shiftWeek(by weeks: Int) {
        currentDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: currentDate) ?? currentDate
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - Body

    var body: some View {
        VStack {
            HStack {
                Text(currentWeekRange)
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 5) {
                    Button(action: { shiftWeek(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.primary)
                            .frame(width: 55, height: 100)
                            .background(Color.gray.opacity(0.5))
                    }
                    Button(action: { shiftWeek(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundColor(.primary)
                            .frame(width: 55, height: 100)
                            .background(Color.gray.opacity(0.5))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            if stateManager.weekViewMode == "summary" {
                VStack {
                    HStack {
                        Text("0")
                        Spacer()
                        Text("\(stateManager.dayLength / 2)")
                        Spacer()
                        Text("\(stateManager.dayLength)")
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    ForEach(groupEventsByDay(), id: \.day) { group in
                        WeekSummaryComponent(
                            day: group.day,
                            date: group.date,
                            events: group.events,
                            selectedDate: $selectedDate,
                            showDayView: $showDayView
                        )
                    }
                }
            } else if stateManager.weekViewMode == "split" {
                VStack {
                    HStack {
                        Text("\(stateManager.wakeUpTime)")
                        Spacer()
                        Text("\((stateManager.wakeUpTime + stateManager.dayLength / 4) % 24)")
                        Spacer()
                        Text("\((stateManager.wakeUpTime + stateManager.dayLength / 2) % 24)")
                        Spacer()
                        Text("\((stateManager.sleepTime - stateManager.dayLength / 4) % 24)")
                        Spacer()
                        Text("\(stateManager.sleepTime % 24)")
                    }
                    .padding(.top)

                    ForEach(groupEventsByDay(), id: \.day) { group in
                        WeekSplitComponent(
                            day: group.day,
                            date: group.date,
                            events: group.events,
                            selectedDate: $selectedDate,
                            showDayView: $showDayView,
                            isToday: isToday(group.date)
                        )
                    }
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            guard calendarManager.authorizationStatus == .fullAccess else { return }
            calendarManager.fetchEvents(date: currentDate)
        }
        .onChange(of: currentDate) { _, newDate in
            guard calendarManager.authorizationStatus == .fullAccess else { return }
            calendarManager.fetchEvents(date: newDate)
        }
        // Sheet lives on the ScheduleView body, which is always in the hierarchy.
        // The old pattern conditionally inserted DayDetailView only when selectedDate
        // was non-nil — because showDayView became true in the same frame, SwiftUI saw
        // the .sheet modifier appear at the same instant it was asked to be open and
        // silently dropped the presentation.
        .sheet(isPresented: $showDayView, onDismiss: { selectedDate = nil }) {
            if let date = selectedDate {
                DayDetailView(date: date)
                    .environmentObject(calendarManager)
                    .environmentObject(stateManager)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.thinMaterial)
            }
        }
    }
}

#Preview {
    ScheduleView()
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
}
