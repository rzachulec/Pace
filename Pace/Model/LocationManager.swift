//
//  LocationManager.swift
//  Pace
//
//  Created by jan on 25/05/2026.
//

import Foundation
import CoreLocation
import MapKit

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // Continuations for async/await bridging
    private var locationContinuation: CheckedContinuation<MKMapItem?, Never>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    @Published var authorizationStatus: CLAuthorizationStatus

    /// Populated by `prefetch()` once the background fetch completes.
    /// `nil` while fetching, if the fetch failed, or before `prefetch()` is called.
    @Published var prefetchedLocation: MKMapItem?
    /// `true` while `prefetch()` is running so callers can show a spinner.
    @Published var isPrefetching = false

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Starts a background location fetch and caches the result in `prefetchedLocation`.
    /// Call this as soon as the user triggers a flow that may need the current location
    /// (e.g. tapping "Add Task") so the result is ready before they actually tap
    /// "Use Current Location" in the sheet.
    ///
    /// - Does nothing when permission has not been granted yet — won't prompt proactively.
    /// - Safe to call multiple times; each call resets any previous cached result.
    func prefetch() {
        guard authorizationStatus == .authorizedWhenInUse
           || authorizationStatus == .authorizedAlways else { return }
        prefetchedLocation = nil
        isPrefetching = true
        Task { [weak self] in
            guard let self else { return }
            let item = await requestCurrentLocation()
            prefetchedLocation = item
            isPrefetching = false
        }
    }
    
    func requestCurrentLocation() async -> MKMapItem? {
        // 1. Check/Request Authorization
        if manager.authorizationStatus == .notDetermined {
            // Ensure any previous auth continuation is cleared
            authContinuation?.resume(returning: .notDetermined)
            authContinuation = nil
            
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<CLAuthorizationStatus, Never>) in
                self.authContinuation = continuation
                #if os(macOS)
                // On macOS Sandboxed apps, sometimes requestAlwaysAuthorization is more reliable for triggering the prompt
                manager.requestAlwaysAuthorization()
                #else
                manager.requestWhenInUseAuthorization()
                #endif
            }
        }
        
        // 2. Re-check status
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            print("Location access denied or restricted: \(status.rawValue)")
            return nil
        }
        
        // 3. Request Location
        // Ensure any previous location continuation is cleared before starting a new one
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<MKMapItem?, Never>) in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }
    
    // MARK: - CLLocationManagerDelegate Methods

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            Task { @MainActor [weak self] in self?.resumeLocation(with: nil) }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let mapItem: MKMapItem
            if let request = MKReverseGeocodingRequest(location: location),
               let items = try? await request.mapItems,
               let first = items.first {
                mapItem = first
            } else {
                mapItem = MKMapItem(location: location, address: nil)
                mapItem.name = "Current Location"
            }
            resumeLocation(with: mapItem)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
        Task { @MainActor [weak self] in self?.resumeLocation(with: nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus != .notDetermined {
                authContinuation?.resume(returning: manager.authorizationStatus)
                authContinuation = nil
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resumeLocation(with item: MKMapItem?) {
        locationContinuation?.resume(returning: item)
        locationContinuation = nil
    }
}
