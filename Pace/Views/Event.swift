//
//  EventFetcher.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import Foundation

struct Event: Hashable, Codable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
}
