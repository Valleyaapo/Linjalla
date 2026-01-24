//
//  MapItem.swift
//  RT Bus
//
//  Created by Refactor on 07.01.2026.
//

import Foundation
import CoreLocation

/// Unified enum representing all items that can be displayed on the map.
/// Used by MapStateManager to build a single, atomically-updated list for BusMapView.
nonisolated enum MapItem: Identifiable, Equatable, Sendable {
    case stop(BusStop)
    case bus(BusModel)
    case tram(BusModel)
    
    var id: String {
        switch self {
        case .stop(let s): return "stop_\(s.id)"
        case .bus(let b): return "bus_\(b.id)"
        case .tram(let t): return "tram_\(t.id)"
        }
    }
    
    static func == (lhs: MapItem, rhs: MapItem) -> Bool {
        switch (lhs, rhs) {
        case (.stop(let a), .stop(let b)): return a == b
        case (.bus(let a), .bus(let b)): return a == b
        case (.tram(let a), .tram(let b)): return a == b
        default: return false
        }
    }
}
