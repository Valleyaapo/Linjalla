//
//  VehicleAnnotation.swift
//  RT Bus
//
//  Created by Automation on 12.01.2026.
//

import MapKit
import UIKit

/// MKAnnotation wrapper for bus/tram vehicles
final class VehicleAnnotation: NSObject, MKAnnotation {

    enum VehicleType {
        case bus
        case tram
        
        var color: UIColor {
            switch self {
            case .bus: return UIColor(red: 0/255, green: 122/255, blue: 201/255, alpha: 1)
            case .tram: return UIColor(red: 0/255, green: 152/255, blue: 95/255, alpha: 1)
            }
        }
    }
    
    // MARK: - MKAnnotation (KVO-compliant for animation)
    
    // Using @objc dynamic allows MapKit to observe changes and animate automatically
    @objc dynamic var coordinate: CLLocationCoordinate2D
    
    // MARK: - Vehicle Properties
    
    private(set) var vehicleId: Int
    private(set) var lineName: String
    
    // Using @objc dynamic to allow KVO observation in the View
    // Using Double for easier CoreGraphics rotation conversion
    // -1.0 indicates no heading
    @objc dynamic var headingDegrees: Double
    
    private(set) var vehicleType: VehicleType
    
    // MARK: - Initialization
    
    init(model: BusModel, type: VehicleType) {
        self.coordinate = model.coordinate
        self.vehicleId = model.id
        self.lineName = model.lineName
        self.headingDegrees = Double(model.heading ?? -1)
        self.vehicleType = type
        super.init()
    }
    
    // MARK: - Updates
    
    /// Update annotation in-place with smooth animation
    func update(from model: BusModel) {
        // Animate coordinate change for smooth movement
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveLinear) {
            self.coordinate = model.coordinate
        }
        lineName = model.lineName
        headingDegrees = Double(model.heading ?? -1)
    }
    
    // MARK: - Identity
    
    var identifier: String {
        "\(vehicleType)_\(vehicleId)"
    }
}
