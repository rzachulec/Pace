//
//  EventFetcher.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import Foundation

import EventKit

class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()
    
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                completion(granted, error)
            }
        }
    }
    
    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .notDetermined:
            requestAccess { granted, error in
                if granted {
                    print("Access granted")
                } else {
                    print("Access denied: \(error?.localizedDescription ?? "Unknown error")")
                }
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
    
    func fetchEvents(startDate: Date, endDate: Date) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        return events
    }
}
