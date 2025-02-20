//
//  EventFetcher.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import Foundation

import EventKit

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    var cnt: Int = 0
    
    @Published var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var events: [EKEvent] = []
    @Published var totalTasks: Int = 0
    @Published var completedTasks: Int = 0
    @Published var todayWakeDate: Date?
    @Published var todaySleepDate: Date?
    
    func requestAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error requesting access: \(error.localizedDescription)")
                } else {
                    print("Access granted: \(granted)")
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        let status = authorizationStatus
        switch status {
        case .notDetermined:
            while cnt < 1 {
                requestAccess()
                checkAuthorizationStatus()
                cnt += 1
                continue
            }
        case .fullAccess:
            print("Full access granted")
        case .writeOnly:
            print("Write-only access granted")
        case .denied, .restricted:
            print("Access denied or restricted")
        @unknown default:
            print("Unknown authorization status")
        }
    }
    
    func updateTaskCounts() {
        let calendar = Calendar.current
        let now = Date()

        // Get today's date components
        var startOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startOfDayComponents.hour = 5
        startOfDayComponents.minute = 0
        let startOfWindow = calendar.date(from: startOfDayComponents)!

        // End of the window (next day's 5 AM)
        let endOfWindow = calendar.date(byAdding: .day, value: 1, to: startOfWindow)!

        // Count all tasks within the window
        let tasksToday = events.filter { event in
            return event.startDate >= startOfWindow && event.startDate < endOfWindow
        }
        
        // Count completed tasks (those that have ended)
        let completedTasks = tasksToday.filter { event in
            event.endDate < now
        }
        
        DispatchQueue.main.async {
            self.totalTasks = tasksToday.count
            self.completedTasks = completedTasks.count
        }
    }
    
    func updateWakeSleepDate(wakeUpTime: Int, sleepTime: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        // set wake up time to dd/MM/YYYY WAKETIME
        var startOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startOfDayComponents.hour = wakeUpTime
        startOfDayComponents.minute = 0
        todayWakeDate = calendar.date(from: startOfDayComponents)!
        
        // if before wake up time show for previous day
        // eg if checking on 02.01.2025 04:00,
        // show events from  01.01.2025 WAKETIME
        if calendar.component(.hour, from: now) <= wakeUpTime {
            todayWakeDate = calendar.date(byAdding: .day, value: -1, to: todayWakeDate!)
        }
 
        print("Wake datetime: \(todayWakeDate!)")
        
        var endOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endOfDayComponents.hour = sleepTime
        endOfDayComponents.minute = 0
        todaySleepDate = calendar.date(from: endOfDayComponents)!

        // set end to sleep time in a day
        let todaySleepDate = calendar.date(byAdding: .day, value: -1, to: todaySleepDate!)
        
        print("Sleep datetime: \(todaySleepDate!)")
    }
    
    func fetchEvents(date: Date) {
        let calendar = Calendar.current
        let now = date
        print("Date: \(now)")

        // get 5AM today
        var startOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startOfDayComponents.hour = 5
        startOfDayComponents.minute = 0
        startOfDayComponents.second = 0
        var startOfDay = calendar.date(from: startOfDayComponents)!
        
        startOfDay = calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        

        // if before 5AM show for previous day
        if calendar.component(.hour, from: now) <= 5 {
            startOfDay = calendar.date(byAdding: .day, value: -1, to: startOfDay)!
        }
 
        print("Start of day: \(startOfDay)")

        // set end to 5AM in a week
        let endOfDay = calendar.date(byAdding: .day, value: 14, to: startOfDay)!
        
        print("End of day: \(endOfDay)")
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let fetchedEvents = eventStore.events(matching: predicate)

        DispatchQueue.main.async {
            self.events = fetchedEvents
            self.updateTaskCounts()
        }
    }
    
    func createEvent(title: String, startDate: Date, endDate: Date) {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("Event saved successfully")
        } catch {
            print("Error saving event: \(error.localizedDescription)")
        }
        fetchEvents(date: Date())
    }
    
    func updateEvent(event: EKEvent, newTitle: String, newStartDate: Date, newEndDate: Date) {
        event.title = newTitle
        event.startDate = newStartDate
        event.endDate = newEndDate
            
        do {
            try eventStore.save(event, span: .thisEvent)
            print("Event updated successfully")
        } catch {
            print("Error updating event: \(error.localizedDescription)")
        }
        fetchEvents(date: Date())
    }
    
    func deleteEvent(event: EKEvent) {
        do {
            try eventStore.remove(event, span: .thisEvent)
            print("Event deleted successfully")
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
        }
        fetchEvents(date: Date())
    }
}
