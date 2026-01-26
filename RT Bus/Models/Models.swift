//
//  Models.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import Foundation
import CoreLocation

// Shared models used across Managers

struct BusStop: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Departure Model
struct Departure: Identifiable, Sendable {
    let id = UUID()
    let lineName: String
    let routeId: String?
    let headsign: String
    let scheduledTime: Int // Seconds since midnight
    let realtimeTime: Int
    let serviceDay: Int
    let platform: String?
    
    var departureDate: Date {
        Date(timeIntervalSince1970: TimeInterval(serviceDay + realtimeTime))
    }
}
