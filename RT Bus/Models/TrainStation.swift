//
//  TrainStation.swift
//  RT Bus
//
//  Lightweight station model for map annotations
//

import CoreLocation

struct TrainStation: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
