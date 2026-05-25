//
//  EventFetcher.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import Foundation
import SwiftUI
import EventKit

#if os(macOS)
import AppKit
#endif

// MARK: - Task constants (single source of truth shared by AddTask and EditTask)

enum TaskDefaults {
    static let durations      = [30, 60, 90, 120]   // minutes
    static let placementTypes = ["Static", "Dynamic"]
    static let priorities     = ["Low", "Regular", "High"]
}

// MARK: - EventData

struct EventData: Hashable, Identifiable, Codable {
    var id: String
    var title: String
    var startDate: Date?
    var endDate: Date?
    var placementType: String = "Dynamic"
    var priority: String = "Regular"
    var isAllDay: Bool

    var ekEvent: EKEvent? // Optional EKEvent reference (not saved in JSON)

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, placementType, priority, isAllDay
    }
}

// MARK: - CalendarProviding

/// Abstracts EKEventStore so CalendarManager can be tested without a real calendar.
protocol CalendarProviding: AnyObject {
    func requestFullAccessToEvents(completion: @escaping (Bool, Error?) -> Void)
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate
    func events(matching predicate: NSPredicate) -> [EKEvent]
    /// Creates a new blank EKEvent backed by this store — needed because EKEvent(eventStore:) takes a concrete EKEventStore.
    func makeEvent() -> EKEvent
    var defaultCalendarForNewEvents: EKCalendar? { get }
    func save(_ event: EKEvent, span: EKSpan) throws
    func remove(_ event: EKEvent, span: EKSpan) throws
    func event(withIdentifier identifier: String) -> EKEvent?
}

extension EKEventStore: CalendarProviding {
    func makeEvent() -> EKEvent { EKEvent(eventStore: self) }
}

// MARK: - EventPersisting

/// Abstracts JSON persistence so CalendarManager can be tested with an in-memory store.
protocol EventPersisting {
    func save(_ events: [EventData])
    func load() -> [EventData]
}

struct JSONEventStore: EventPersisting {
    private let fileName: String

    init(fileName: String = "calendar.json") {
        self.fileName = fileName
    }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(fileName)
    }

    func save(_ events: [EventData]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(events)
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: fileURL, options: .atomic)
            print("✅ Events saved to JSON at: \(fileURL.path)")
        } catch {
            print("❌ Error saving events to JSON: \(error.localizedDescription)")
        }
    }

    func load() -> [EventData] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([EventData].self, from: data)
        } catch {
            print("⚠️ Error loading events from JSON: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - CalendarManager

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    private let store: CalendarProviding
    private let persistence: EventPersisting

    /// Designated init — internal access so tests can inject mock dependencies.
    init(store: CalendarProviding, persistence: EventPersisting) {
        self.store = store
        self.persistence = persistence
    }

    /// Convenience init used exclusively by the production singleton.
    private convenience init() {
        self.init(store: EKEventStore(), persistence: JSONEventStore())
    }

    @Published var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var totalTasks: Int = 0
    @Published var completedTasks: Int = 0
    @Published var events: [EventData] = [] {
        didSet {
            if StateManager.shared.notificationsEnabled {
                NotificationManager.shared.scheduleNotifications(from: self, with: StateManager.shared)
            }
        }
    }

    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var alertID = -1
    @Published var includeNonWorkingDays: Bool = false
    @Published var placeByRescheduling: Bool = false

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error requesting access: \(error.localizedDescription)")
                }
                // Always re-read the real status so onChange fires in ContentView,
                // whether the user granted, denied, or an error occurred.
                self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
        }
    }

    func fetchEvents(date: Date) {
        let calendar = Calendar.current
        let now = date

        // Date arithmetic is fast — keep it on the calling thread.
        var startOfDayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startOfDayComponents.hour = 5
        startOfDayComponents.minute = 0
        startOfDayComponents.second = 0
        var startOfDay = calendar.date(from: startOfDayComponents)!
        startOfDay = calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        if calendar.component(.hour, from: now) <= 5 {
            startOfDay = calendar.date(byAdding: .day, value: -1, to: startOfDay)!
        }
        let endOfDay = calendar.date(byAdding: .day, value: 14, to: startOfDay)!

        // EventKit queries and file I/O are synchronous and can block for hundreds of
        // milliseconds.  Running them on the main thread freezes the UI long enough for
        // the system gesture gate to time out, which is why taps on day rows (and context
        // menus on the current-task card) stop registering.  Move both off-thread.
        let store = self.store
        let persistence = self.persistence
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
            let fetchedEKEvents = store.events(matching: predicate)
            let existingEvents = persistence.load()

            let eventDataArray = fetchedEKEvents.map { event -> EventData in
                if let existing = existingEvents.first(where: { $0.id == event.eventIdentifier }) {
                    return EventData(
                        id: event.eventIdentifier,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        placementType: existing.placementType,
                        priority: existing.priority,
                        isAllDay: event.isAllDay,
                        ekEvent: event
                    )
                } else {
                    return EventData(
                        id: event.eventIdentifier,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay,
                        ekEvent: event
                    )
                }
            }

            persistence.save(eventDataArray)

            DispatchQueue.main.async {
                self.events = eventDataArray
            }
        }
    }

    func loadEventsFromJSON() -> [EventData] {
        let loaded = persistence.load()
        DispatchQueue.main.async {
            self.events = loaded
            print("✅ Events loaded successfully")
        }
        return loaded
    }

    func createEvent(title: String, startDate: Date, endDate: Date, placementType: String, priority: String) {
        guard let defaultCalendar = store.defaultCalendarForNewEvents else {
            print("❌ Cannot create event: no default calendar (is calendar access granted?)")
            return
        }

        let ekEvent = store.makeEvent()
        ekEvent.title = title
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate
        ekEvent.calendar = defaultCalendar

        do {
            try store.save(ekEvent, span: .thisEvent)
            print("Event saved successfully")
        } catch {
            print("Error saving event: \(error.localizedDescription)")
            return  // ekEvent.eventIdentifier is nil if save failed — must not continue
        }

        guard let eventID = ekEvent.eventIdentifier else {
            print("❌ Event saved but returned no identifier")
            return
        }

        let newEventData = EventData(
            id: eventID,
            title: title,
            startDate: startDate,
            endDate: endDate,
            placementType: placementType,
            priority: priority,
            isAllDay: false,
            ekEvent: ekEvent
        )

        self.events.append(newEventData)
        persistence.save(self.events)
        // events.append already publishes the change — no need to re-fetch from disk + EventKit
    }

    func updateEvent(eventID: String, newTitle: String, newStartDate: Date, newEndDate: Date, placementType: String, priority: String) {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            print("Error: Event with ID \(eventID) not found")
            return
        }

        var updatedEvent = events[index]
        updatedEvent.title = newTitle
        updatedEvent.startDate = newStartDate
        updatedEvent.endDate = newEndDate
        updatedEvent.placementType = placementType
        updatedEvent.priority = priority

        events[index] = updatedEvent
        persistence.save(events)

        if let ekEvent = updatedEvent.ekEvent {
            ekEvent.title = newTitle
            ekEvent.startDate = newStartDate
            ekEvent.endDate = newEndDate

            do {
                try store.save(ekEvent, span: .thisEvent)
                print("Event updated successfully in EventKit")
            } catch {
                print("Error updating event in EventKit: \(error.localizedDescription)")
            }
        }
        // events[index] assignment already publishes — no need to re-fetch from disk + EventKit
    }

    func deleteEvent(eventID: String) {
        guard let ekEvent = store.event(withIdentifier: eventID) else {
            print("Event not found in EventStore")
            return
        }

        do {
            try store.remove(ekEvent, span: .thisEvent)
            print("Event deleted successfully")
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
        }

        self.events.removeAll { $0.id == eventID }
        persistence.save(self.events)
    }

    func updateTaskCounts() {
        // Called from TodayView's .task loop, which runs on the MainActor.
        // DispatchQueue.main.async inside a Swift Concurrency context is the
        // unsafeForcedSync pattern the compiler warns about — it re-enters the
        // main thread from within a structured task, causing the gesture gate to
        // time out every 3 s.  Since we are already on the main thread, assign directly.
        let now = Date()
        let calendar = Calendar.current

        let startOfWindow = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: now)!
        let endOfWindow   = calendar.date(byAdding: .day, value: 1, to: startOfWindow)!

        // Force-unwrapping optional dates would crash if any event has nil start/end;
        // use guard-let filters instead.
        let tasksToday = events.filter { event in
            guard let start = event.startDate else { return false }
            return start >= startOfWindow && start < endOfWindow
        }

        totalTasks     = tasksToday.count
        completedTasks = tasksToday.filter { event in
            guard let end = event.endDate else { return false }
            return end < now
        }.count
    }

    func openCalendarEvent(startDate: Date) {
#if os(macOS)
        if let url = URL(string: "ical://") {
            NSWorkspace.shared.open(url)
        }
#else
        if let url = URL(string: "calshow:\(startDate.timeIntervalSinceReferenceDate)") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
#endif
    }

    func placeTask(duration: TimeInterval, workingDays: [Bool], wakeUpTime: Int, sleepTime: Int, workStartTime: Int, workEndTime: Int, breakDuration: Int, priority: String, completion: @escaping (Result<Date, Error>) -> Void) {
        let calendar = Calendar.current
        var searchDate = Date()
        var weeksSearched = 0
        var includeNonWorkingDays = false
        let now = Calendar.current

        while weeksSearched < 4 {
            for dayOffset in 0..<7 {
                let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: searchDate)!
                let weekdayIndex = calendar.component(.weekday, from: candidateDay) % 7

                print(weekdayIndex)

                if !includeNonWorkingDays && !workingDays[weekdayIndex] {
                    continue
                }

                let midnight = calendar.startOfDay(for: candidateDay)
                guard let startOfDay = calendar.date(byAdding: .hour, value: wakeUpTime, to: midnight),
                      let endOfDay = calendar.date(byAdding: .hour, value: sleepTime, to: midnight) else {
                    continue
                }

                let dailyEvents = events.filter {
                    guard let eventStart = $0.startDate else { return false }
                    guard !$0.isAllDay else { return false }
                    return calendar.isDate(eventStart, inSameDayAs: candidateDay)
                }.sorted { $0.startDate ?? .distantFuture < $1.startDate ?? .distantFuture }

                var candidateStart = startOfDay

                print("candidateStart: \(candidateStart)")
                print("endOfDay: \(endOfDay)")
                print("searchDate: \(searchDate)")

                while candidateStart < searchDate {
                    candidateStart = calendar.date(byAdding: .minute, value: 15, to: candidateStart)!
                }

                print(candidateStart)
                while candidateStart.addingTimeInterval(duration) <= endOfDay {
                    let candidateEnd = candidateStart.addingTimeInterval(duration)

                    print(candidateEnd)

                    let candidateHour = calendar.component(.hour, from: candidateStart)
                    let isWorkTime = candidateHour >= workStartTime && candidateHour < workEndTime

                    if !isWorkTime {
                        candidateStart = calendar.date(byAdding: .minute, value: 15, to: candidateStart)!
                        continue
                    }

                    let hasConflict = dailyEvents.contains { event in
                        guard let eventStart = event.startDate, let eventEnd = event.endDate else { return false }
                        return candidateStart - Double(breakDuration) * 60 < eventEnd && candidateEnd + Double(breakDuration) * 60 > eventStart
                    }

                    if !hasConflict {
                        completion(.success(candidateStart))
                        return
                    }

                    print("now: \(now), proposition:  \(candidateStart)")

                    candidateStart = calendar.date(byAdding: .minute, value: 15, to: candidateStart)!
                }
            }

            if weeksSearched == 0 && workingDays.contains(false) {
                DispatchQueue.main.async {
                    self.alertTitle = "No Free Time Found"
                    self.alertMessage = "No available time was found in the current week. Would you like to schedule this task on non-working days?"
                    self.showAlert = true
                }
                return
            } else if weeksSearched == 0 {
                DispatchQueue.main.async {
                    self.alertTitle = "No Free Time Found"
                    self.alertMessage = "No available time was found in the current week. Would you like to re-schedule lower priority tasks to make space?"
                    self.showAlert = true
                }
                return
            }

            searchDate = calendar.date(byAdding: .weekOfYear, value: 1, to: searchDate)!
            weeksSearched += 1
        }

        DispatchQueue.main.async {
            self.alertTitle = "No Time Available"
            self.alertMessage = "No available time slot was found within the next 4 weeks. Consider adjusting your preferred working hours."
            self.showAlert = true
        }
        completion(.failure(NSError(domain: "No Time Available", code: 2, userInfo: nil)))
    }
}
