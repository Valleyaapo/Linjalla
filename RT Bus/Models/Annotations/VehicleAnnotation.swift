//
//  VehicleAnnotation.swift
//  RT Bus
//
//  Created by Automation on 12.01.2026.
//

import MapKit
import UIKit
import RTBusCore

/// MKAnnotation wrapper for bus/tram vehicles
@MainActor
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
    private(set) var headsign: String?
    private(set) var lastUpdated: TimeInterval
    
    // Using @objc dynamic to allow KVO observation in the View
    // Using Double for easier CoreGraphics rotation conversion
    // -1.0 indicates no heading
    @objc dynamic var headingDegrees: Double
    
    private(set) var vehicleType: VehicleType
    private(set) var needsEntryAnimation: Bool
    
    // MARK: - Initialization
    
    init(model: BusModel, type: VehicleType) {
        self.coordinate = model.coordinate
        self.vehicleId = model.id
        self.lineName = model.lineName
        self.headsign = model.headsign
        self.lastUpdated = model.timestamp
        self.headingDegrees = Double(model.heading ?? -1)
        self.vehicleType = type
        self.needsEntryAnimation = true
        super.init()
    }

    func markEntryAnimationHandled() {
        needsEntryAnimation = false
    }
    
    // MARK: - Updates

    /// Update annotation data with smooth animation to new position.
    func update(from model: BusModel) {
        lineName = model.lineName
        headsign = model.headsign
        lastUpdated = model.timestamp
        headingDegrees = Double(model.heading ?? -1)

        let latDelta = abs(model.coordinate.latitude - coordinate.latitude)
        let lonDelta = abs(model.coordinate.longitude - coordinate.longitude)

        // Skip glitchy data - if movement > 500m, just snap (don't animate)
        let maxDelta = 0.005 // ~500m in degrees
        if latDelta > maxDelta || lonDelta > maxDelta {
            coordinate = model.coordinate
            return
        }

        // Skip tiny movements < ~2m (not visible, wastes CPU)
        let minDelta = 0.00002
        if latDelta < minDelta && lonDelta < minDelta {
            return
        }

        // Animate over update interval - .beginFromCurrentState blends if new update arrives mid-animation
        UIView.animate(withDuration: VehicleManagerConstants.updateInterval, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
            self.coordinate = model.coordinate
        }
    }
    
    // MARK: - Identity
    
    var identifier: String {
        "\(vehicleType)_\(vehicleId)"
    }
}
