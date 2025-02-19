//
//  DayPercentageTracker.swift
//  Pace
//
//  Created by jan on 18/02/2025.
//

import Foundation
import SwiftUI

class AnimationHandler: ObservableObject {
    @Published var wakeUpTime: Int = 7
    @Published var sleepTime: Int = 25
    
    private var startOfDay: Date
    private var endOfDay: Date
    private var timer: Timer?
     
    @Published var percentageOfDay: Int = 0
    @Published var offsetY: CGFloat = -50
    
    func startAnimation() {
        print("Before animation: \(offsetY)")
        objectWillChange.send()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {  // Small delay to allow rendering
            withAnimation(Animation.interpolatingSpring(duration: 5).repeatForever(autoreverses: true)) {
                self.offsetY = 350
            }
        }
        print("After animation: \(offsetY)")
    }



    init(wakeUpTime: Int = 7, sleepTime: Int = 23) {
        let calendar = Calendar.current
        let now = Date()
        
        // TODO: this is straight from calendarManager it should be a separate component
        // as it will be interacted with by settings as well!
        // get 5AM today
        var startOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startOfDayComponents.hour = wakeUpTime
        startOfDayComponents.minute = 0
        startOfDayComponents.second = 0
        startOfDay = calendar.date(from: startOfDayComponents)!

        if sleepTime <= 24 {
            startOfDayComponents.hour = sleepTime
            endOfDay = calendar.date(from: startOfDayComponents)!
        } else if sleepTime > 24 && sleepTime <= 48 {
            startOfDayComponents.hour = sleepTime - 24
            endOfDay = calendar.date(from: startOfDayComponents)!
            endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        } else {
            endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        }
        
        updatePercentage()
        startTimer()
        
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(updatePercentage), userInfo: nil, repeats: true)
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
