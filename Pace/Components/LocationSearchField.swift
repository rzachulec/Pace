//
//  LocationSearchField.swift
//  Pace
//

import SwiftUI
import MapKit

/// A tappable row that shows the selected place name and opens a unified
/// location selection sheet (including current location and saved places).
struct LocationSearchField: View {
    @Binding var selection: MKMapItem?

    /// A shared LocationManager that may already hold a pre-fetched location.
    /// When nil, the field creates its own instance (no pre-fetch benefit).
    var sharedLocationManager: LocationManager? = nil

    /// Fallback manager owned by this view, used when no shared one is provided.
    @StateObject private var ownedManager = LocationManager()

    @State private var showingSheet = false

    private var locationManager: LocationManager {
        sharedLocationManager ?? ownedManager
    }

    var body: some View {
        Button { showingSheet = true } label: {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(selection == nil ? .secondary : Color.accentColor)
                    .frame(width: 20)
                Text(selection?.name ?? "Add location")
                    .foregroundStyle(selection == nil ? .secondary : .primary)
                Spacer()
                if selection != nil {
                    Button {
                        selection = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            LocationSelectionSheet(selection: $selection, locationManager: locationManager)
        }
    }
}

// MARK: - Coordinate helper

extension MKMapItem {
    /// The coordinate of this map item, using the non-deprecated API where available.
    var coordinate: CLLocationCoordinate2D {
        if #available(iOS 26.0, macOS 26.0, *) {
            return location.coordinate
        } else {
            return placemark.coordinate
        }
    }
}
