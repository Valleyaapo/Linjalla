//
//  Models.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import Foundation
import CoreLocation

// Shared models used across Managers

public struct BusStop: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double

    public init(id: String, name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Departure Model
public struct Departure: Identifiable, Sendable {
    public let id: UUID
    public let lineName: String
    public let routeId: String?
    public let headsign: String
    public let scheduledTime: Int // Seconds since midnight
    public let realtimeTime: Int
    public let serviceDay: Int
    public let platform: String?

    public init(
        id: UUID = UUID(),
        lineName: String,
        routeId: String?,
        headsign: String,
        scheduledTime: Int,
        realtimeTime: Int,
        serviceDay: Int,
        platform: String?
    ) {
        self.id = id
        self.lineName = lineName
        self.routeId = routeId
        self.headsign = headsign
        self.scheduledTime = scheduledTime
        self.realtimeTime = realtimeTime
        self.serviceDay = serviceDay
        self.platform = platform
    }
    
    public var departureDate: Date {
        Date(timeIntervalSince1970: TimeInterval(serviceDay + realtimeTime))
    }
}
