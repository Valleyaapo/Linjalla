//
//  TrainStationAnnotation.swift
//  RT Bus
//
//  Train station annotation for map
//

import MapKit

@MainActor
final class TrainStationAnnotation: NSObject, MKAnnotation {
    let stationId: String
    let stationName: String
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(station: TrainStation) {
        self.stationId = station.id
        self.stationName = station.name
        self.coordinate = station.coordinate
        super.init()
    }
}
