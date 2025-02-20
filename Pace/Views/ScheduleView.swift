//
//  CalendarView.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import SwiftUI
import EventKit

struct ScheduleView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var animationHandler: AnimationHandler
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var currentDate = Date()
    
    @State private var showDayView: Bool = false
    @State private var selectedDate: Date?
    
    @State private var showEditTask: Bool = false
    @State private var selectedTask: EKEvent?
            
    struct dayData: Identifiable, Hashable {
        var id: Int
        
        var day: String
        var tasks: CGFloat
    }
    
    @State private var days: [dayData] = [ dayData.init(id: 1, day: "Monday", tasks: 170), dayData.init(id: 2, day: "Tuesday", tasks: 150), dayData.init(id: 3, day: "Wednesday", tasks: 140), dayData.init(id: 4, day: "Thursday", tasks: 90), dayData.init(id: 5, day: "Friday", tasks: 180), dayData.init(id: 6, day: "Saturday", tasks: 70), dayData.init(id: 7, day: "Sunday", tasks: 80)]
        
    
    @State private var dayLength: Int = 0
    
    var currentWeekRange: String {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return "This week: \n \(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek)) \n"
    }
    
    var filteredEvents: [EKEvent] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        return calendarManager.events.filter { event in
            return (event.startDate >= startOfWeek && event.startDate <= endOfWeek) ||
            (event.endDate >= startOfWeek && event.endDate <= endOfWeek)
        }
    }
    
    func shiftWeek(by weeks: Int) {
            currentDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: currentDate) ?? currentDate
    }
    
    func groupEventsByDay() -> [(key: String, date: Date, value: [EKEvent])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!
        
        let daysOfWeek = (0...6).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        let dayNames = daysOfWeek.map { formatter.string(from: $0) }
        
        var groupedEvents = Dictionary(grouping: filteredEvents, by: { formatter.string(from: $0.startDate) })
        
        return zip(dayNames, daysOfWeek).map { (dayName, date) in
            (key: dayName, date: date, value: groupedEvents[dayName] ?? [])
        }
    }
    
    private func getDayLength() -> Int {
        return animationHandler.sleepTime - animationHandler.wakeUpTime
    }
    
    var body: some View {
//        if horizontalSizeClass == .compact && verticalSizeClass == .regular {
            VStack {
                // top overview with week switch buttons
                ZStack {
                    Image("Background")
                        .resizable()
                        .scaledToFill()
                        .clipShape(Rectangle())
                        .frame(height: 130)
                        .offset(y: animationHandler.offsetY)
                        .padding(-10)
                        .blur(radius: 15)
                        .brightness(-0.1)
                        .mask(
                            HStack {
                                Text(currentWeekRange)
                                    .font(.title)
                                    .fontWeight(.semibold)
                                Spacer()
                                HStack(spacing: 5) {
                                    Rectangle()
                                        .frame(width: 55, height: 100)
                                        .background(Color.primary)
                                    Rectangle()
                                        .frame(width: 55, height: 100)
                                        .background(Color.primary)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                        )
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Button(action: { shiftWeek(by: -1) }) {
                                Image(systemName: "chevron.left")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 55, height: 100)
                                    .background(Color.white.opacity(0.1))
                            }
                            Button(action: { shiftWeek(by: 1) }) {
                                Image(systemName: "chevron.right")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 55, height: 100)
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                
                HStack {
                    Text("0")
                    Spacer()
                    Text("\(getDayLength()/2)")
                    Spacer()
                    Text("\(getDayLength())")
                }
                .padding(.horizontal)
                .padding(.top)
                
                // day of week bars
                ForEach(groupEventsByDay(), id: \.key) { day, date, events in
                    let totalDuration = events.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600
                    
                    Button(action: {
                        selectedDate = date
                        showDayView = true
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.gray.opacity(0), lineWidth: 4)
                                .frame(height: 55)
                                .overlay(
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(Color.indigo.opacity(0.7))
                                            .frame(width: CGFloat(totalDuration) * 20)
                                        Spacer()
                                    }
                                )
                            HStack {
                                Text(day)
                                    .font(.title3)
                                Spacer()
                                Text("\(events.count) tasks, \(String(format: "%.0f", totalDuration)) h")
                            }
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(.gray, lineWidth: 1)
                            )
                            .foregroundColor(.primary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                if let selectedDate = selectedDate {
                    DayDetailView(showDayView: $showDayView, date: selectedDate)
                }
                Spacer()
            }
            .padding()
//        }
    }
}

#Preview {
    ScheduleView()
        .environmentObject(CalendarManager())
        .environmentObject(AnimationHandler())
}
