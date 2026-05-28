//
//  File.swift
//  Pace
//
//  Created by jan on 27/03/2025.
//

import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Notification permission granted: \(granted)")
        }
    }
    
    func setupNotificationCategories() {
        print("Setting up notification categories...")
        
        let viewAction = UNNotificationAction(identifier: "VIEW_EVENT",
                                              title: "View in Calendar",
                                              options: .foreground)
        let startNowAction = UNNotificationAction(identifier: "START_NOW",
                                                  title: "Start Now",
                                                  options: .foreground)
        
        let markDoneAction = UNNotificationAction(identifier: "MARK_DONE",
                                                  title: "Mark Done",
                                                  options: .foreground)
        
        let category = UNNotificationCategory(identifier: "EVENT_CATEGORY",
                                              actions: [viewAction, startNowAction, markDoneAction],
                                              intentIdentifiers: [],
                                              options: [])
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        print("Notification categories set.")
    }
    
    func scheduleNotifications(from calendarManager: CalendarManager, with stateManager: StateManager) {
        print("Scheduling notifications...")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("Notification access not granted. Requesting permission...")
                self.requestNotificationPermission()
                return
            }
            
            let timeInterval = stateManager.notificationInterval
            DispatchQueue.main.async {
                self.clearNotifications()
//                print("Cleared existing notifications.")
                for event in calendarManager.events {
                    
                    let eventNotificationTime = event.startDate!.timeIntervalSinceNow - timeInterval
                    if eventNotificationTime > 0 {
//                        print("Scheduling notification for event: \(event.title) with ID: \(event.id) at \(event.startDate! - timeInterval)")
                        self.scheduleNotification(for: event, after: eventNotificationTime)
                    } else if eventNotificationTime + timeInterval - 120 > 0 {
//                        print("Scheduling notification for event: \(event.title) with ID: \(event.id) in 60 seconds")
                        self.scheduleNotification(for: event, after: 60)
                    } else {
//                        print("Skipping notification for event: \(event.title) as it's already past.")
                    }
                }
            }
        }
    }
    
    private func scheduleNotification(for event: EventData, after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        content.title = event.title
        content.body = "Starts at \(formatter.string(from: event.startDate!))"
        content.sound = .default
        content.categoryIdentifier = "EVENT_CATEGORY" //assign the category to enable contextmenu

        content.userInfo = [
                    "eventID": event.id,
                    "eventTitle": event.title,
                    "startDate": event.startDate!,
                    "endDate": event.endDate!,
                    "placementType": event.placementType,
                    "priority": event.priority
                ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func clearNotifications() {
        print("Removing all pending notifications.")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let eventID = userInfo["eventID"] as? String,
              let eventTitle = userInfo["eventTitle"] as? String,
              let eventStartDate = userInfo["startDate"] as? Date,
              let eventEndDate = userInfo["endDate"] as? Date,
              let placementType = userInfo["placementType"] as? String,
              let priority = userInfo["priority"] as? String else {
                  completionHandler()
                  return
              }
        let eventDuration = eventEndDate.timeIntervalSince(eventStartDate)
        
        switch response.actionIdentifier {
        case "VIEW_EVENT":
            CalendarManager.shared.openCalendarEvent(startDate: eventStartDate)
        case "START_NOW":
            print("Before update: \(CalendarManager.shared.events.map { $0.id })")
            if let index = CalendarManager.shared.events.firstIndex(where: { $0.id == eventID }) {
                print("Updating event with ID \(eventID)")
                CalendarManager.shared.updateEvent(eventID: eventID, newTitle: eventTitle, newStartDate: Date(), newEndDate: Date().addingTimeInterval(eventDuration), placementType: placementType, priority: priority)
            } else {
                print("Event with ID \(eventID) not found before update")
            }
        case "MARK_DONE":
            print("Before update: \(CalendarManager.shared.events.map { $0.id })")
            if let index = CalendarManager.shared.events.firstIndex(where: { $0.id == eventID }) {
                print("Updating event with ID \(eventID)")
                CalendarManager.shared.updateEvent(eventID: eventID, newTitle: eventTitle, newStartDate: Date().addingTimeInterval(-60), newEndDate: Date(), placementType: placementType, priority: priority)
            } else {
                print("Event with ID \(eventID) not found before update")
            }
        default:
            break
        }
        completionHandler()
    }
}
