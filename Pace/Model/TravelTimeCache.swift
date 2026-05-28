//
//  TravelTimeCache.swift
//  Pace
//

import Foundation
import MapKit
import CoreLocation

extension TransportMode {
    var mkType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking:    return .walking
        case .transit:    return .transit
		case .bike:
					// MapKit has no bike support. Fall back to walking to avoid highways.
					return .walking
        }
    }
}

// Pre-computes travel times between a new task's location and surrounding event locations.
// Must be built on a background thread — MKGeocodingRequest and MKDirections are bridged
// synchronously via DispatchSemaphore / DispatchGroup.
struct TravelTimeCache {
    private let fromEventToTask: [String: TimeInterval]
    private let fromTaskToEvent: [String: TimeInterval]
    private let padding: TimeInterval

    // Buffer needed after a preceding event ends (travel time to reach the new task's location).
    // Falls back to `fallback` if the event has no location or geocoding/routing failed.
    func bufferAfterEvent(location: String?, fallback: TimeInterval) -> TimeInterval {
        guard let loc = location, !loc.isEmpty, let t = fromEventToTask[loc] else { return fallback }
        return max(t + padding, fallback)
    }

    // Buffer needed before a following event starts (travel time from the new task to that event).
    func bufferBeforeEvent(location: String?, fallback: TimeInterval) -> TimeInterval {
        guard let loc = location, !loc.isEmpty, let t = fromTaskToEvent[loc] else { return fallback }
        return max(t + padding, fallback)
    }

    // Geocodes event location strings then fires concurrent routing requests.
    // The new task's coordinate is passed in directly (already known from MapKit search),
    // so only surrounding event locations need geocoding.
    // Blocks the calling thread until all network calls complete.
    static func build(
        newTaskCoordinate: CLLocationCoordinate2D,
        eventLocations: Set<String>,
        transportType: MKDirectionsTransportType,
        padding: TimeInterval
    ) -> TravelTimeCache {
        var coordCache: [String: CLLocationCoordinate2D] = [:]

        // MKGeocodingRequest only permits one active request at a time — geocode sequentially.
        for locString in eventLocations {
            guard let request = MKGeocodingRequest(addressString: locString) else { continue }
            let sem = DispatchSemaphore(value: 0)
            request.getMapItems { mapItems, _ in
                if let location = mapItems?.first?.location {
                    coordCache[locString] = location.coordinate
                }
                sem.signal()
            }
            sem.wait()
        }

        let newTaskCoord = newTaskCoordinate

        var fromEventToTask: [String: TimeInterval] = [:]
        var fromTaskToEvent: [String: TimeInterval] = [:]
        let group = DispatchGroup()
        let lock = NSLock()

        for eventLoc in eventLocations {
            guard let eventCoord = coordCache[eventLoc] else { continue }

            group.enter()
            route(from: eventCoord, to: newTaskCoord, transport: transportType) { t in
                if let t { lock.withLock { fromEventToTask[eventLoc] = t } }
                group.leave()
            }

            group.enter()
            route(from: newTaskCoord, to: eventCoord, transport: transportType) { t in
                if let t { lock.withLock { fromTaskToEvent[eventLoc] = t } }
                group.leave()
            }
        }

        group.wait()
        return TravelTimeCache(
            fromEventToTask: fromEventToTask,
            fromTaskToEvent: fromTaskToEvent,
            padding: padding
        )
    }

    private static func route(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: source.latitude, longitude: source.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: destination.latitude, longitude: destination.longitude), address: nil)
        request.transportType = transport
        MKDirections(request: request).calculateETA { response, error in
            completion(error == nil ? response?.expectedTravelTime : nil)
        }
    }
}
