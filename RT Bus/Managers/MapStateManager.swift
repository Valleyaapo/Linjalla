//
//  MapStateManager.swift
//  RT Bus
//
//  Created by Aapo Laakso on 07.01.2026.
//

import Foundation
import Observation
import OSLog
import QuartzCore

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
    var vehicles: [MapItem] {
        mapItems.filter {
            switch $0 {
            case .bus, .tram: return true
            case .stop: return false
            }
        }
    }

    /// Stops only for use by BusMapView
    var stopsList: [BusStop] {
        mapItems.compactMap {
            switch $0 {
            case .stop(let stop): return stop
            case .bus, .tram: return nil
            }
        }
    }
    
    // Internal caches
    private var buses: [Int: BusModel] = [:]
    private var trams: [Int: BusModel] = [:]
    private var stops: [String: BusStop] = [:]
    
    // CADisplayLink for display-synced coalescing
    private var displayLink: CADisplayLink?
    private var needsRebuild: Bool = false
    
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
        
        // 1. BUSES
        let sortedBuses = buses.values.sorted { $0.id < $1.id }
        items.append(contentsOf: sortedBuses.map { .bus($0) })
        
        // 2. TRAMS
        let sortedTrams = trams.values.sorted { $0.id < $1.id }
        items.append(contentsOf: sortedTrams.map { .tram($0) })
        
        // 3. STOPS (Rendered last = at the bottom visually)
        let sortedStops = stops.values.sorted { $0.id < $1.id }
        items.append(contentsOf: sortedStops.map { .stop($0) })
        
        // Atomic update
        if items != mapItems {
            mapItems = items
        }
    }
}
