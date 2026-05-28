//
//  EventFetcher.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import Foundation
import SwiftUI
import EventKit
import CoreLocation

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
    var placementType: String = "Static"
    var priority: String = "Regular"
    var isAllDay: Bool
    var location: String?
    var createdAt: Date = Date()

    var ekEvent: EKEvent? // Optional EKEvent reference (not saved in JSON)

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, placementType, priority, isAllDay, location, createdAt
    }
}

// MARK: - CalendarProviding

/// Abstracts EKEventStore so CalendarManager can be tested without a real calendar.
protocol CalendarProviding: AnyObject {
    func requestFullAccessToEvents(completion: @escaping @Sendable (Bool, Error?) -> Void)
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate
    func events(matching predicate: NSPredicate) -> [EKEvent]
    /// Creates a new blank EKEvent backed by this store — needed because EKEvent(eventStore:) takes a concrete EKEventStore.
    func makeEvent() -> EKEvent
    /// Creates a new blank EKCalendar backed by this store.
    func makeCalendar() -> EKCalendar
    var defaultCalendarForNewEvents: EKCalendar? { get }
    var availableSources: [EKSource] { get }
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func save(_ event: EKEvent, span: EKSpan) throws
    func remove(_ event: EKEvent, span: EKSpan) throws
    func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws
    func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws
    func event(withIdentifier identifier: String) -> EKEvent?
}

extension EKEventStore: CalendarProviding {
    func makeEvent() -> EKEvent { EKEvent(eventStore: self) }
    func makeCalendar() -> EKCalendar { EKCalendar(for: .event, eventStore: self) }
    var availableSources: [EKSource] { sources }
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
                        location: event.location,
                        createdAt: existing.createdAt,
                        ekEvent: event
                    )
                } else {
                    return EventData(
                        id: event.eventIdentifier,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        placementType: "Static",
                        isAllDay: event.isAllDay,
                        location: event.location,
                        createdAt: event.startDate ?? Date(),
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

    func createEvent(title: String, startDate: Date, endDate: Date, placementType: String, priority: String, location: String? = nil) {
        guard let defaultCalendar = store.defaultCalendarForNewEvents else {
            print("❌ Cannot create event: no default calendar (is calendar access granted?)")
            return
        }

        let ekEvent = store.makeEvent()
        ekEvent.title = title
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate
        ekEvent.calendar = defaultCalendar
        ekEvent.location = location

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
            location: location,
            createdAt: Date(),
            ekEvent: ekEvent
        )

        self.events.append(newEventData)
        persistence.save(self.events)
        // events.append already publishes the change — no need to re-fetch from disk + EventKit
    }

    func updateEvent(eventID: String, newTitle: String, newStartDate: Date, newEndDate: Date, placementType: String, priority: String, location: String? = nil) {
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
        updatedEvent.location = location

        events[index] = updatedEvent
        persistence.save(events)

        if let ekEvent = updatedEvent.ekEvent {
            ekEvent.title = newTitle
            ekEvent.startDate = newStartDate
            ekEvent.endDate = newEndDate
            ekEvent.location = location

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

    func placeTask(
        duration: TimeInterval,
        workingDays: [Bool],
        wakeUpTime: Int,
        sleepTime: Int,
        workStartTime: Int,
        workEndTime: Int,
        breakDuration: Int,
        priority: String,
        newTaskCoordinate: CLLocationCoordinate2D? = nil,
        transportMode: TransportMode = .automobile,
        travelTimePadding: Int = 0,
        completion: @escaping (Result<Date, Error>) -> Void
    ) {
        // Capture published flags before dispatching to background so that a UI
        // retry with updated flags triggers a fresh call rather than mutating a
        // running search.
        let allowNonWorkingDays = self.includeNonWorkingDays
        let allowRescheduling   = self.placeByRescheduling

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let calendar      = Calendar.current
            let now           = Date()
            let breakInterval = Double(breakDuration) * 60

            // Snapshot events once so the array can't change under us mid-search.
            let eventsSnapshot = self.events

            // Pre-compute travel times between the new task's location and all event
            // locations in the search window.
            let eventLocations = Set(eventsSnapshot.compactMap { $0.location }.filter { !$0.isEmpty })
            let travelCache: TravelTimeCache? = newTaskCoordinate.flatMap { coord in
                guard !eventLocations.isEmpty else { return nil }
                return TravelTimeCache.build(
                    newTaskCoordinate: coord,
                    eventLocations: eventLocations,
                    transportType: transportMode.mkType,
                    padding: Double(travelTimePadding) * 60
                )
            }

            // MARK: – findSlot

            /// Scans day-by-day from `searchStart` (inclusive) to `searchEnd`
            /// (exclusive), returning the earliest `(candidateStart, toDisplace)`
            /// pair that satisfies work-hour and conflict constraints, or `nil`.
            ///
            /// `allowDisplacement`: when `true`, a slot blocked only by lower-
            /// priority Dynamic tasks is considered valid; those tasks are returned
            /// so the caller can reschedule them after placing the new event.
            func findSlot(from searchStart: Date,
                          to   searchEnd:   Date,
                          allowDisplacement: Bool) -> (start: Date, toDisplace: [EventData])? {

                let currentPriorityValue = TaskDefaults.priorities.firstIndex(of: priority) ?? 0
                var dayStart = searchStart

                while dayStart < searchEnd {
                    // EKCalendar weekday: Sun=1…Sat=7; %7 maps Sun→1, Mon→2…Sat→0.
                    let weekdayIndex = calendar.component(.weekday, from: dayStart) % 7

                    if !allowNonWorkingDays && !workingDays[weekdayIndex] {
                        dayStart = calendar.startOfDay(
                            for: calendar.date(byAdding: .day, value: 1, to: dayStart)!
                        )
                        continue
                    }

                    let midnight = calendar.startOfDay(for: dayStart)
                    guard
                        let startOfDay = calendar.date(byAdding: .hour, value: wakeUpTime, to: midnight),
                        let endOfDay   = calendar.date(byAdding: .hour, value: sleepTime,  to: midnight)
                    else {
                        dayStart = calendar.date(byAdding: .day, value: 1, to: midnight)!
                        continue
                    }

                    let dailyEvents = eventsSnapshot
                        .filter {
                            guard let s = $0.startDate else { return false }
                            return !$0.isAllDay && calendar.isDate(s, inSameDayAs: dayStart)
                        }
                        .sorted { $0.startDate ?? .distantFuture < $1.startDate ?? .distantFuture }

                    // For today, skip past slots; for future days, start at wakeUpTime.
                    // Round up to the next 15-minute boundary (O(1) vs. the previous loop).
                    var candidateStart = max(startOfDay, dayStart)
                    let rem = calendar.component(.minute, from: candidateStart) % 15
                    if rem != 0 {
                        candidateStart = calendar.date(byAdding: .minute, value: 15 - rem,
                                                       to: candidateStart)!
                    }

                    while candidateStart.addingTimeInterval(duration) <= endOfDay
                            && candidateStart < searchEnd {

                        let candidateEnd  = candidateStart.addingTimeInterval(duration)
                        let candidateHour = calendar.component(.hour, from: candidateStart)

                        guard candidateHour >= workStartTime && candidateHour < workEndTime else {
                            candidateStart = calendar.date(byAdding: .minute, value: 15,
                                                           to: candidateStart)!
                            continue
                        }

                        let conflicts = dailyEvents.filter { event in
                            guard let es = event.startDate, let ee = event.endDate else { return false }
                            let afterBuf  = travelCache?.bufferAfterEvent(location: event.location,
                                                                           fallback: breakInterval) ?? breakInterval
                            let beforeBuf = travelCache?.bufferBeforeEvent(location: event.location,
                                                                            fallback: breakInterval) ?? breakInterval
                            return candidateStart - afterBuf < ee && candidateEnd + beforeBuf > es
                        }

                        // A conflict is displaceable only when ALL three hold:
                        //   1. allowDisplacement — caller has enabled it (user consent or
                        //      automatic forced displacement for high-priority deadlines).
                        //   2. placementType == "Dynamic" — Static events are fixed
                        //      appointments and must never be moved.
                        //   3. The conflict's priority is strictly lower than the new task's.
                        var canPlace   = true
                        var toDisplace = [EventData]()

                        for conflict in conflicts {
                            let cp = TaskDefaults.priorities.firstIndex(of: conflict.priority) ?? 0
                            if allowDisplacement
                                && conflict.placementType == "Dynamic"
                                && cp < currentPriorityValue {
                                toDisplace.append(conflict)
                            } else {
                                canPlace = false
                                break
                            }
                        }

                        if canPlace { return (candidateStart, toDisplace) }

                        candidateStart = calendar.date(byAdding: .minute, value: 15,
                                                       to: candidateStart)!
                    }

                    dayStart = calendar.date(byAdding: .day, value: 1, to: midnight)!
                }
                return nil
            }

            // MARK: – execute

            /// Calls completion on the main thread, then deletes and reschedules
            /// any displaced events (also on the main thread so @Published mutations
            /// are thread-safe).
            ///
            /// Ordering matters: completion is called FIRST so the caller can create
            /// the new event and make its slot visible in self.events before displaced
            /// tasks search for new slots — preventing them from landing in the same slot.
            func execute(slot: Date, displaced: [EventData]) {
                DispatchQueue.main.async {
                    completion(.success(slot))

                    for event in displaced {
                        self.deleteEvent(eventID: event.id)
                        let dur = event.endDate?.timeIntervalSince(event.startDate ?? Date()) ?? 3600
                        self.placeTask(
                            duration: dur,
                            workingDays: workingDays,
                            wakeUpTime: wakeUpTime,
                            sleepTime: sleepTime,
                            workStartTime: workStartTime,
                            workEndTime: workEndTime,
                            breakDuration: breakDuration,
                            priority: event.priority
                        ) { result in
                            if case .success(let newDate) = result {
                                self.createEvent(
                                    title: event.title,
                                    startDate: newDate,
                                    endDate: newDate.addingTimeInterval(dur),
                                    placementType: event.placementType,
                                    priority: event.priority,
                                    location: event.location
                                )
                            } else {
                                print("⚠️ Failed to re-schedule displaced task: \(event.title)")
                            }
                        }
                    }
                }
            }

            // MARK: – Priority-aware placement

            // Each priority tier enforces a deadline window for placement:
            //
            //   High (24 h)
            //     Pass 1 – free slot within 24 h (no displacement).
            //     Pass 2 – forced displacement within 24 h: lower-priority Dynamic
            //              tasks are automatically rescheduled; no user consent needed
            //              because the high-priority deadline overrides them.
            //     Pass 3 – if 24 h is still impossible (e.g. only Static/equal-priority
            //              conflicts), place at the earliest slot beyond 24 h and alert.
            //
            //   Regular (72 h)
            //     Pass 1 – slot within 72 h (with optional user-consented displacement).
            //     Pass 2 – earliest slot beyond 72 h + deadline-miss alert.
            //
            //   Low – no deadline; earliest slot in the full 4-week window.

            let window24h = now.addingTimeInterval(24 * 3600)
            let window72h = now.addingTimeInterval(72 * 3600)
            let window4w  = now.addingTimeInterval(28 * 24 * 3600)

            switch priority {

            case "High":
                // Pass 1: find a completely free slot within 24 h.
                if let r = findSlot(from: now, to: window24h, allowDisplacement: false) {
                    execute(slot: r.start, displaced: [])
                    return
                }
                // Pass 2: 24 h window is fully occupied — forcibly displace lower-
                //         priority Dynamic tasks to honour the high-priority deadline.
                if let r = findSlot(from: now, to: window24h, allowDisplacement: true) {
                    execute(slot: r.start, displaced: r.toDisplace)
                    return
                }
                // Pass 3: forced displacement still couldn't free a 24 h slot (all
                //         conflicts are Static or equal/higher priority). Schedule at
                //         the earliest available time beyond 24 h and warn the user.
                if let r = findSlot(from: window24h, to: window4w, allowDisplacement: allowRescheduling) {
                    DispatchQueue.main.async {
                        self.alertTitle   = "24-Hour Deadline Missed"
                        self.alertMessage = "No slot could be freed within 24 hours even after rescheduling lower-priority tasks. The task has been placed at the earliest available time."
                        self.showAlert    = true
                    }
                    execute(slot: r.start, displaced: r.toDisplace)
                    return
                }

            case "Regular":
                // Pass 1: slot within 72 h with optional user-consented displacement.
                if let r = findSlot(from: now, to: window72h, allowDisplacement: allowRescheduling) {
                    execute(slot: r.start, displaced: r.toDisplace)
                    return
                }
                // Pass 2: 72 h window exhausted — schedule beyond it and warn.
                if let r = findSlot(from: window72h, to: window4w, allowDisplacement: allowRescheduling) {
                    DispatchQueue.main.async {
                        self.alertTitle   = "72-Hour Window Missed"
                        self.alertMessage = "No slot was available within 72 hours. The task has been placed at the earliest available time beyond that window."
                        self.showAlert    = true
                    }
                    execute(slot: r.start, displaced: r.toDisplace)
                    return
                }

            default: // "Low" — no deadline constraint
                if let r = findSlot(from: now, to: window4w, allowDisplacement: allowRescheduling) {
                    execute(slot: r.start, displaced: r.toDisplace)
                    return
                }
            }

            // ── No slot found anywhere in the 4-week window ──────────────────────
            // Surface the most actionable escalation path to the user.
            // Do NOT call completion(.failure) for the first two alerts — the UI is
            // expected to set the corresponding flag and retry placeTask.
            DispatchQueue.main.async {
                if !allowNonWorkingDays && workingDays.contains(false) {
                    self.alertTitle   = "No Free Time Found"
                    self.alertMessage = "No available time was found in the next 4 weeks. Would you like to also search non-working days?"
                    self.showAlert    = true
                } else if !allowRescheduling {
                    self.alertTitle   = "No Free Time Found"
                    self.alertMessage = "No available time was found in the next 4 weeks. Would you like to re-schedule lower-priority tasks to make space?"
                    self.showAlert    = true
                } else {
                    self.alertTitle   = "No Time Available"
                    self.alertMessage = "No available time slot was found within the next 4 weeks even after considering all days and rescheduling. Consider adjusting your preferred working hours."
                    self.showAlert    = true
                    completion(.failure(NSError(domain: "NoTimeAvailable", code: 2, userInfo: nil)))
                }
            }
        }
    }

    // MARK: - Subscribed calendar management

    enum CloneResult {
        case success(eventCount: Int)
        /// Events were copied but the subscription could not be removed — user should delete it manually.
        case partialSuccess(eventCount: Int)
        case failure(Error)
    }

    enum CloneError: LocalizedError {
        case noWritableSource
        case saveCalendarFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noWritableSource:
                return "No writable calendar account found. Please configure iCloud or add a local calendar account in Settings."
            case .saveCalendarFailed(let e):
                return "Failed to create the new calendar: \(e.localizedDescription)"
            }
        }
    }

    @Published var subscribedCalendars: [EKCalendar] = []

    func loadSubscribedCalendars() {
        let all = store.calendars(for: .event)
        DispatchQueue.main.async {
            self.subscribedCalendars = all.filter { $0.isSubscribed }
        }
    }

    func cloneAndUnsubscribe(_ subscribed: EKCalendar, completion: @escaping (CloneResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let source = self.writableSource() else {
                DispatchQueue.main.async { completion(.failure(CloneError.noWritableSource)) }
                return
            }

            let newCalendar = self.store.makeCalendar()
            newCalendar.title = subscribed.title
            newCalendar.cgColor = subscribed.cgColor
            newCalendar.source = source

            do {
                try self.store.saveCalendar(newCalendar, commit: true)
            } catch {
                DispatchQueue.main.async { completion(.failure(CloneError.saveCalendarFailed(error))) }
                return
            }

            // Fetch in two 4-year windows to stay within EventKit's predicate limit.
            let now = Date()
            let cal = Calendar.current
            let past = cal.date(byAdding: .year, value: -4, to: now)!
            let future = cal.date(byAdding: .year, value: 4, to: now)!

            let pastPred = self.store.predicateForEvents(withStart: past, end: now, calendars: [subscribed])
            let futurePred = self.store.predicateForEvents(withStart: now, end: future, calendars: [subscribed])

            // Deduplicate events that fall exactly on the 'now' boundary.
            var seenIDs = Set<String>()
            let allEvents = (self.store.events(matching: pastPred) + self.store.events(matching: futurePred))
                .filter { seenIDs.insert($0.eventIdentifier).inserted }

            var copiedCount = 0
            for sourceEvent in allEvents {
                let newEvent = self.store.makeEvent()
                newEvent.calendar = newCalendar
                newEvent.title = sourceEvent.title
                newEvent.startDate = sourceEvent.startDate
                newEvent.endDate = sourceEvent.endDate
                newEvent.isAllDay = sourceEvent.isAllDay
                newEvent.location = sourceEvent.location
                newEvent.notes = sourceEvent.notes
                newEvent.url = sourceEvent.url
                newEvent.timeZone = sourceEvent.timeZone
                do {
                    try self.store.save(newEvent, span: .thisEvent)
                    copiedCount += 1
                } catch {
                    print("⚠️ Skipped '\(sourceEvent.title ?? "(no title)")': \(error.localizedDescription)")
                }
            }

            do {
                try self.store.removeCalendar(subscribed, commit: true)
            } catch {
                // Events were copied successfully; only the unsubscription step failed.
                // Surface as partial success so the user knows to remove the subscription manually.
                self.loadSubscribedCalendars()
                self.fetchEvents(date: Date())
                DispatchQueue.main.async { completion(.partialSuccess(eventCount: copiedCount)) }
                return
            }

            self.loadSubscribedCalendars()
            self.fetchEvents(date: Date())
            DispatchQueue.main.async { completion(.success(eventCount: copiedCount)) }
        }
    }

    // Returns the best available writable source for creating a new calendar.
    // Prefers the default calendar's source; falls back to any local or CalDAV source.
    private func writableSource() -> EKSource? {
        if let source = store.defaultCalendarForNewEvents?.source,
           source.sourceType != .subscribed,
           source.sourceType != .birthdays {
            return source
        }
        return store.availableSources.first {
            $0.sourceType == .local || $0.sourceType == .calDAV
        }
    }
}
