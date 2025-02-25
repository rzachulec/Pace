class DayPercentageTracker: ObservableObject {
    @State var wakeUpTime: Int = 7
    @State var sleepTime: Int = 25
    
    private var startOfDay: Date
    private var endOfDay: Date
    private var timer: Timer?
     
    @Published var percentageOfDay: Int = 0

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