//
//  StopAnnotation.swift
//  RT Bus
//
//  Created by Automation on 12.01.2026.
//

import MapKit
import RTBusCore

/// MKAnnotation wrapper for bus/tram stops
@MainActor
final class StopAnnotation: NSObject, MKAnnotation {
    
    // MARK: - MKAnnotation
    
    @objc dynamic var coordinate: CLLocationCoordinate2D
    
    var title: String? {
        showName ? stopName : nil
    }
    
    // MARK: - Clustering
    
    /// Enable clustering for performance with many stops
    var clusteringIdentifier: String? = "stops"
    
    // MARK: - Stop Properties
    
    let stopId: String
    let stopName: String
    var showName: Bool
    
    // MARK: - Initialization
    
    init(stop: BusStop, showName: Bool) {
        self.stopId = stop.id
        self.stopName = stop.name
        self.coordinate = stop.coordinate
        self.showName = showName
        super.init()
    }
    
    // MARK: - Identity
    
    var identifier: String {
        stopId
    }
}
