//
//  BusModel.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import Foundation
import CoreLocation

/// Modern, Sendable Bus Model for late 2025 (iOS 26 context)
nonisolated struct BusModel: Identifiable, Codable, Equatable, Sendable {
    enum VehicleType: String, Codable, Sendable {
        case bus
        case tram
    }
    
    let id: Int
    let lineName: String
    let routeId: String?
    let headsign: String?
    let latitude: Double
    let longitude: Double
    let heading: Int?
    let timestamp: TimeInterval
    let type: VehicleType
    
    // Default config for older initializers if needed, though we should update them
    init(id: Int, lineName: String, routeId: String?, headsign: String? = nil, latitude: Double, longitude: Double, heading: Int?, timestamp: TimeInterval, type: VehicleType = .bus) {
        self.id = id
        self.lineName = lineName
        self.routeId = routeId
        self.headsign = headsign
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
        self.timestamp = timestamp
        self.type = type
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    static func == (lhs: BusModel, rhs: BusModel) -> Bool {
        // Strict equality for iOS 26 performance patterns:
        // Skip timestamp to avoid UI jitter for stationary vehicles.
        lhs.id == rhs.id &&
        lhs.lineName == rhs.lineName &&
        lhs.headsign == rhs.headsign &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.heading == rhs.heading &&
        lhs.type == rhs.type
    }
}

// HSL API Response Structures (Sendable)
nonisolated struct HSLResponse: Codable, Sendable {
    let VP: VehiclePosition
}

nonisolated struct VehiclePosition: Codable, Sendable {
    let veh: Int
    let desi: String?
    let lat: Double?
    let long: Double?
    let hdg: Int?
    let tsi: TimeInterval?

    // Map JSON keys exactly as provided by HSL API
    enum CodingKeys: String, CodingKey {
        case veh
        case desi
        case lat
        case long
        case hdg
        case tsi
    }

    func toBusModel(routeId: String? = nil, headsign: String? = nil, type: BusModel.VehicleType = .bus) -> BusModel? {
        guard let lat, let long, let desi else { return nil }
        return BusModel(
            id: veh,
            lineName: desi,
            routeId: routeId,
            headsign: headsign,
            latitude: lat,
            longitude: long,
            heading: hdg,
            timestamp: tsi ?? Date().timeIntervalSince1970,
            type: type
        )
    }
}
