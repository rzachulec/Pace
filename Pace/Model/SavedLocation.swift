//
//  SavedLocation.swift
//  Pace
//
//  Created by jan on 25/05/2026.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class SavedLocation {
    var id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, address: String, latitude: Double, longitude: Double, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
