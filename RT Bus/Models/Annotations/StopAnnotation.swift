//
//  StopAnnotation.swift
//  RT Bus
//
//  Created by Automation on 12.01.2026.
//

import MapKit

/// MKAnnotation wrapper for bus/tram stops
final class StopAnnotation: NSObject, MKAnnotation {
    
    // MARK: - MKAnnotation
    
    @objc dynamic var coordinate: CLLocationCoordinate2D
    
    var title: String? {
        showName ? stop.name : nil
    }
    
    // MARK: - Clustering
    
    /// Enable clustering for performance with many stops
    var clusteringIdentifier: String? = "stops"
    
    // MARK: - Stop Properties
    
    let stop: BusStop
    var showName: Bool
    
    // MARK: - Initialization
    
    init(stop: BusStop, showName: Bool) {
        self.stop = stop
        self.coordinate = stop.coordinate
        self.showName = showName
        super.init()
    }
    
    // MARK: - Identity
    
    var identifier: String {
        stop.id
    }
}
