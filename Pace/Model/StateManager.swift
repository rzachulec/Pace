//
//  DayPercentageTracker.swift
//  Pace
//
//  Created by jan on 18/02/2025.
//

import Foundation
import SwiftUI

class StateManager: ObservableObject {
    
    static let shared = StateManager()

    @AppStorage("wakeUpTime") var wakeUpTime: Int = 8 {
        didSet { updateDayBoundaries() }
    }
    @AppStorage("sleepTime") var sleepTime: Int = 24 {
        didSet { updateDayBoundaries() }
    }
    @AppStorage("workStartTime") var workStartTime: Int = 9
    @AppStorage("workEndTime") var workEndTime: Int = 20
    @Published var workingDays: [Bool] = Array(repeating: true, count: 7) {
        didSet {
            workingDaysString = workingDays.map { $0 ? "1" : "0"}.joined()
            print("workingDayString: " + workingDaysString)
        }
    }
    @AppStorage("workingDaysString") var workingDaysString: String = "1111111"
    @AppStorage("breakDuration") var breakDuration: Int = 30
    @AppStorage("maxWorkingHours") var maxWorkingHours: Int = 8
    @AppStorage("dayLength") var dayLength: Int = 16
    
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("notificationInterval") var notificationInterval: TimeInterval = 3600/4
    
    @Published var wakeUpDate: Date = Date()
    @Published var sleepDate: Date = Date()
    @Published var weekViewMode: String = "split"
    
    private var startOfDay: Date = Date()
    private var endOfDay: Date = Date()
    private var timer: Timer?
     
    @Published var percentageOfDay: Int = 0
    @Published var offsetY: CGFloat = -50
    
    
    enum DayOfWeek: Int, CaseIterable {
        case sunday, monday, tuesday, wednesday, thursday, friday, saturday
        
        var description: String {
            switch self {
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            case .sunday: return "Sunday"
            }
        }
    }

    init() {
        updateDayBoundaries()
        updatePercentage()
        startTimer()
        self.workingDays = self.workingDaysString.map { $0 == "1" }
    }
    
    
    
    private func updateDayBoundaries() {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        // Set start of day to wakeUpTime
        components.hour = wakeUpTime
        components.minute = 0
        components.second = 0
        startOfDay = calendar.date(from: components)!

        if sleepTime <= 24 {
            // Sleep on same day
            components.hour = sleepTime
            endOfDay = calendar.date(from: components)!
        } else if sleepTime > 24 && sleepTime <= 48 {
            // Sleep on next day
            components.hour = sleepTime - 24
            // Create a temporary date from these components
            let tempDate = calendar.date(from: components)!
            endOfDay = calendar.date(byAdding: .day, value: 1, to: tempDate)!
        } else {
            endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        }
        
        dayLength = sleepTime - wakeUpTime
        updateDates()
        updatePercentage() // recalculate immediately when boundaries change, not just on next timer tick
    }
    
    private func updateDates() {
        wakeUpDate = startOfDay
        sleepDate = endOfDay
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(updatePercentage), userInfo: nil, repeats: true)
    }
    
    @objc func updatePercentage() {
        let currentDate = Date()
        let secondsInDay: TimeInterval = endOfDay.timeIntervalSince(startOfDay)
        
        if currentDate < startOfDay {
            percentageOfDay = 0
        } else if currentDate > endOfDay {
            percentageOfDay = 100
        } else {
            percentageOfDay = Int((currentDate.timeIntervalSince(startOfDay) / secondsInDay) * 100)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
}
