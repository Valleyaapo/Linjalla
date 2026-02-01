//
//  MapAnchorAnnotation.swift
//  RT Bus
//
//  Map-anchored annotation for action buttons
//

import MapKit

@MainActor
final class MapAnchorAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}
