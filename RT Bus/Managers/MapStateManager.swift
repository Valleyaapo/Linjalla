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
/// into a single, atomically-updated mapItems array. This eliminates race conditions
/// caused by independent updates triggering separate view re-renders.
@MainActor
@Observable
final class MapStateManager {
    /// The source of truth for dynamic vehicle annotations (Buses & Trams).
    /// Updated via CADisplayLink to ensure atomic rendering synced with display.
    /// The atomically-updated list of all items (Stops, then Vehicles)
    /// This ensures they are rendered in the correct order every frame.
    private(set) var mapItems: [MapItem] = []
    
    /// Vehicles only (buses and trams) for use by BusMapView
    /// Cached to avoid O(N) filtering during high-frequency UI access.
    private(set) var vehicles: [MapItem] = []

    /// Stops only for use by BusMapView
    /// Cached to avoid O(N) compactMapping during high-frequency UI access.
    private(set) var stopsList: [BusStop] = []
    
    // Internal caches
    @ObservationIgnored private var buses: [Int: BusModel] = [:]
    @ObservationIgnored private var trams: [Int: BusModel] = [:]
    @ObservationIgnored private var stops: [String: BusStop] = [:]
    
    // CADisplayLink for display-synced coalescing
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var needsRebuild: Bool = false
    
    init() {}

    // MARK: - Public Update Methods
    
    /// Updates stops. Usually called when line selection changes.
    func updateStops(_ list: [BusStop]) {
        var newStops: [String: BusStop] = [:]
        for stop in list {
            newStops[stop.id] = stop
        }

        if newStops != stops {
            stops = newStops
            scheduleRebuild()
        }
    }
    
    /// Updates the bus list.
    func updateBuses(_ list: [BusModel]) {
        var newBuses: [Int: BusModel] = [:]
        for bus in list {
            newBuses[bus.id] = bus
        }
        
        if newBuses != buses {
            buses = newBuses
            scheduleRebuild()
        }
    }
    
    /// Updates the tram list.
    func updateTrams(_ list: [BusModel]) {
        var newTrams: [Int: BusModel] = [:]
        for tram in list {
            newTrams[tram.id] = tram
        }
        
        if newTrams != trams {
            trams = newTrams
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
        var items: [MapItem] = []
        var vehicleItems: [MapItem] = []
        
        // 1. BUSES
        let sortedBuses = buses.values.sorted { $0.id < $1.id }
        let busItems = sortedBuses.map { MapItem.bus($0) }
        items.append(contentsOf: busItems)
        vehicleItems.append(contentsOf: busItems)
        
        // 2. TRAMS
        let sortedTrams = trams.values.sorted { $0.id < $1.id }
        let tramItems = sortedTrams.map { MapItem.tram($0) }
        items.append(contentsOf: tramItems)
        vehicleItems.append(contentsOf: tramItems)
        
        // 3. STOPS (Rendered last = at the bottom visually)
        let sortedStops = stops.values.sorted { $0.id < $1.id }
        let stopItems = sortedStops.map { MapItem.stop($0) }
        items.append(contentsOf: stopItems)
        
        // Atomic update
        if items != mapItems {
            mapItems = items
            vehicles = vehicleItems
            stopsList = sortedStops
        }
    }
}
