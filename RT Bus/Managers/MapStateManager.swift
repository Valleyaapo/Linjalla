//
//  MapStateManager.swift
//  RT Bus
//
//  Created by Aapo Laakso on 07.01.2026.
//

import Foundation
import Observation
import QuartzCore
import RTBusCore

/// Central state manager that aggregates data from BusManager, TramManager, and StopManager
/// into optimized lists for BusMapView. This eliminates race conditions
/// caused by independent updates triggering separate view re-renders.
@MainActor
@Observable
final class MapStateManager {
    /// Vehicles only (buses and trams) for use by BusMapView
    private(set) var vehicles: [MapItem] = []

    /// Stops only for use by BusMapView
    private(set) var stopsList: [BusStop] = []
    
    // Internal caches - stored as Arrays to preserve order from Managers and avoid Dictionary overhead
    @ObservationIgnored private var buses: [BusModel] = []
    @ObservationIgnored private var trams: [BusModel] = []
    @ObservationIgnored private var stops: [BusStop] = []
    
    // CADisplayLink for display-synced coalescing
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var needsRebuild: Bool = false
    
    init() {}

    // MARK: - Public Update Methods
    
    /// Updates stops. Usually called when line selection changes.
    /// - Parameter list: A list of BusStop objects, expected to be sorted by ID.
    func updateStops(_ list: [BusStop]) {
        if list != stops {
            stops = list
            scheduleRebuild()
        }
    }
    
    /// Updates the bus list.
    /// - Parameter list: A list of BusModel objects, expected to be sorted by ID.
    func updateBuses(_ list: [BusModel]) {
        if list != buses {
            buses = list
            scheduleRebuild()
        }
    }
    
    /// Updates the tram list.
    /// - Parameter list: A list of BusModel objects, expected to be sorted by ID.
    func updateTrams(_ list: [BusModel]) {
        if list != trams {
            trams = list
            scheduleRebuild()
        }
    }
    
    // MARK: - CADisplayLink Coalescing
    
    private func scheduleRebuild() {
        needsRebuild = true
        
        guard displayLink == nil else { return }
        
        // Create display link synced with screen refresh
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkFired() {
        // Process on next display refresh
        flushRebuild()
    }
    
    private func flushRebuild() {
        displayLink?.invalidate()
        displayLink = nil
        
        guard needsRebuild else { return }
        needsRebuild = false
        
        rebuildItems()
    }
    
    private func rebuildItems() {
        // 1. VEHICLES
        // Buses and Trams are already sorted by ID from Managers.
        // We map them to MapItem and concatenate.
        // Since BusMapView separates them anyway, we just provide the list.
        var newVehicles: [MapItem] = []
        newVehicles.reserveCapacity(buses.count + trams.count)
        
        // Append buses (sorted by ID)
        newVehicles.append(contentsOf: buses.map { .bus($0) })
        
        // Append trams (sorted by ID)
        newVehicles.append(contentsOf: trams.map { .tram($0) })
        
        // 2. STOPS
        // Stops are already sorted by ID from StopManager.
        let newStops = stops
        
        // Atomic update
        if newVehicles != vehicles {
            vehicles = newVehicles
        }

        if newStops != stopsList {
            stopsList = newStops
        }
    }
}
