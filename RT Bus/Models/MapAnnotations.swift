//
//  MapAnnotations.swift
//  RT Bus
//
//  Created by Assistant on 11.01.2026.
//

import MapKit

/// Annotation for a Bus Stop
class StopAnnotation: MKPointAnnotation {
    let stop: BusStop
    
    init(stop: BusStop) {
        self.stop = stop
        super.init()
        self.coordinate = stop.coordinate
        self.title = stop.name
    }
}

/// Annotation for a Vehicle (Bus or Tram)
class VehicleAnnotation: MKPointAnnotation {
    let vehicle: BusModel
    let isBus: Bool
    
    init(vehicle: BusModel, isBus: Bool) {
        self.vehicle = vehicle
        self.isBus = isBus
        super.init()
        self.coordinate = vehicle.coordinate
        self.title = vehicle.lineName
    }
    
    func update(with newVehicle: BusModel) {
        // Animate coordinate changes if needed, or just set
        // UIView animation in the view delegate is usually better
        self.coordinate = newVehicle.coordinate
    }
}
