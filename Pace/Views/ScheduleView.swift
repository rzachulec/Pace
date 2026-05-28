//
//  CalendarView.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import SwiftUI

// Single state that drives both sheet presentation and its content,
// eliminating the showDayView + selectedDate race that blanked the first open.
struct SelectedDay: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
}

struct ScheduleView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State private var currentDate = Date()
    @State private var selectedDay: SelectedDay?

    // MARK: - Shared date helpers

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

    private var weekLabel: String {
        switch weekOffset {
        case 0:  return "This week"
        case 1:  return "Next week"
        case -1: return "Last week"
        case let n where n > 1:  return "In \(n) weeks"
        case let n where n < -1: return "\(-n) weeks back"
        default: return "This week"
        }
    }

    private var weekDateRange: String {
        let f = Self.weekRangeFormatter
        return "\(f.string(from: startOfWeek)) – \(f.string(from: endOfWeek))"
    }

    var filteredEvents: [EventData] {
        let start = startOfWeek
        let end = endOfWeek
        return calendarManager.events.filter { event in
            guard let evStart = event.startDate, let evEnd = event.endDate else { return false }
            return (evStart >= start && evStart <= end) || (evEnd >= start && evEnd <= end)
        }
    }

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
        let grouped = Dictionary(grouping: filteredEvents, by: { formatter.string(from: $0.startDate!) })
        return zip(names, days).map { DayGroup(day: $0, date: $1, events: grouped[$0] ?? []) }
    }

    func shiftWeek(by weeks: Int) {
        currentDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: currentDate) ?? currentDate
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - Sizing helpers

    // Rows shrink in landscape so 7 days fit without overlap.
    private var rowHeight: CGFloat { verticalSizeClass == .compact ? 37 : 65 }

    // Nav buttons scale down proportionally in landscape.
    private var navButtonHeight: CGFloat { verticalSizeClass == .compact ? 100 : 100 }
	
	private var rowSpacing: CGFloat { verticalSizeClass == .compact ? 5 : 10 }

    // MARK: - Sub-views

    private var navButtons: some View {
        HStack(spacing: 5) {
            Button(action: { shiftWeek(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.title)
                    .foregroundColor(.primary)
                    .frame(width: 55, height: navButtonHeight)
                    .background(Color.gray.opacity(0.5))
            }
            Button(action: { shiftWeek(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.title)
                    .foregroundColor(.primary)
                    .frame(width: 55, height: navButtonHeight)
                    .background(Color.gray.opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var scheduleGrid: some View {
        let rh = rowHeight
		let rs = rowSpacing
        if stateManager.weekViewMode == "summary" {
            VStack(spacing: rs) {
                HStack {
                    Text("0")
                    Spacer()
                    Text("\(stateManager.dayLength / 2)")
                    Spacer()
                    Text("\(stateManager.dayLength)")
                }
                .padding(.horizontal)
                .padding(.top, 4)

                ForEach(groupEventsByDay(), id: \.day) { group in
                    WeekSummaryComponent(
                        day: group.day,
                        date: group.date,
                        events: group.events,
                        selectedDay: $selectedDay,
                        rowHeight: rh
                    )
                }
            }
        } else {
            VStack(spacing: rs) {
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
                .padding(.top, 4)

                ForEach(groupEventsByDay(), id: \.day) { group in
                    WeekSplitComponent(
                        day: group.day,
                        date: group.date,
                        events: group.events,
                        selectedDay: $selectedDay,
                        isToday: isToday(group.date),
                        rowHeight: rh
                    )
                }
            }
        }
    }

    // MARK: - Layout variants

    private var portraitLayout: some View {
        VStack {
            HStack {
                Text(currentWeekRange)
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                navButtons
            }
            scheduleGrid
            Spacer()
        }
        .padding()
    }

    // Left quarter: week label + nav buttons pinned to bottom of the schedule.
    // Right three-quarters: time axis + day rows.
    // No Spacer in right panel so HStack height = schedule content height,
    // which lets the Spacer in the left panel push buttons to schedule's bottom.
    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(weekLabel)
                    .font(.title)
                    .fontWeight(.semibold)
                Text(weekDateRange)
                    .font(.title2)
					.fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                navButtons
            }
//            .padding(.vertical)
            .containerRelativeFrame(.horizontal, count: 4, span: 1, spacing: 0)

            scheduleGrid
                .padding(.leading)
                .containerRelativeFrame(.horizontal, count: 4, span: 3, spacing: 0)
//			Spacer()
        }
        // Without fixedSize the HStack expands to fill available screen height and
        // Spacer pushes the buttons to the screen bottom rather than the schedule bottom.
        // fixedSize(vertical: true) locks HStack height to its content (= schedule grid),
        // so Spacer fills exactly to the last row.
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .onAppear {
            guard calendarManager.authorizationStatus == .fullAccess else { return }
            calendarManager.fetchEvents(date: currentDate)
        }
        .onChange(of: currentDate) { _, newDate in
            guard calendarManager.authorizationStatus == .fullAccess else { return }
            calendarManager.fetchEvents(date: newDate)
        }
        .sheet(item: $selectedDay) { selection in
            DayDetailView(date: selection.date)
                .environmentObject(calendarManager)
                .environmentObject(stateManager)
                .presentationDetents([.medium, .large])
                .presentationBackground(.thinMaterial)
        }
    }
}

#Preview {
    ScheduleView()
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
}
