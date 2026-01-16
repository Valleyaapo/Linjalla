//
//  MapStateManager.swift
//  RT Bus
//
//  Created by Refactor on 07.01.2026.
//

import Foundation
import Observation
import OSLog

/// Central state manager that aggregates data from BusManager, TramManager, and StopManager
/// into a single, atomically-updated mapItems array. This eliminates race conditions
/// caused by independent updates triggering separate view re-renders.
@MainActor
@Observable
final class MapStateManager {
    /// The source of truth for dynamic vehicle annotations (Buses & Trams).
    /// Updated via coalescing timer to ensure atomic rendering.
    /// The atomically-updated list of all items (Stops, then Vehicles)
    /// This ensures they are rendered in the correct order every frame.
    private(set) var mapItems: [MapItem] = []
    
    /// Vehicles only (buses and trams) for use by BusMapView
    var vehicles: [MapItem] {
        mapItems.filter {
            switch $0 {
            case .bus, .tram: return true
            case .stop: return false
            }
        }
    }
    
    // Internal caches
    private var buses: [Int: BusModel] = [:]
    private var trams: [Int: BusModel] = [:]
    private var stops: [String: BusStop] = [:]
    
    // Coalescing mechanism
    private var coalescingTimer: Timer?
    private var needsRebuild: Bool = false
    
    /// Coalescing interval in seconds (~30fps = 33ms, using 32ms)
    private let coalescingInterval: TimeInterval = 0.032
    
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
    
    // MARK: - Coalescing Logic
    
    private func scheduleRebuild() {
        needsRebuild = true
        guard coalescingTimer == nil else { return }
        
        coalescingTimer = Timer.scheduledTimer(withTimeInterval: coalescingInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushRebuild()
            }
        }
    }
    
    private func flushRebuild() {
        coalescingTimer?.invalidate()
        coalescingTimer = nil
        
        guard needsRebuild else { return }
        needsRebuild = false
        
        rebuildItems()
    }
    
    private func rebuildItems() {
        var items: [MapItem] = []
        
        // 1. BUSES (Rendered first = Current User Preference for "Underneath" vs "Top" check)
        // If the user says stops are on top now, and I had stops first, then the Map engine 
        // renders elements in the ForEach from FRONT TO BACK (Top to Bottom).
        let sortedBuses = buses.values.sorted { $0.id < $1.id }
        items.append(contentsOf: sortedBuses.map { .bus($0) })
        
        // 2. TRAMS
        let sortedTrams = trams.values.sorted { $0.id < $1.id }
        items.append(contentsOf: sortedTrams.map { .tram($0) })
        
        // 3. STOPS (Rendered last = Should be at the bottom now)
        let sortedStops = stops.values.sorted { $0.id < $1.id }
        items.append(contentsOf: sortedStops.map { .stop($0) })
        
        // Atomic update
        if items != mapItems {
            mapItems = items
        }
    }
}
