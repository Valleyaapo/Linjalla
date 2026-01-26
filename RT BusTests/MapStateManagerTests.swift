//
//  MapStateManagerTests.swift
//  RTBusTests
//
//  Created by Automation on 10.01.2026.
//

import Testing
import Foundation
import RTBusCore
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct MapStateManagerTests {
    
    @Test
    func updateBuses() async throws {
        let manager = MapStateManager()
        let bus1 = BusModel(id: 1, lineName: "1", routeId: "1", latitude: 60, longitude: 25, heading: 0, timestamp: 0, type: .bus)
        
        // Initial Update
        manager.updateBuses([bus1])
        
        // Wait for coalescing (32ms interval + buffer)
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(manager.vehicles.count == 1)
        if case .bus(let b) = manager.vehicles.first {
            #expect(b.id == 1)
        } else {
            #expect(Bool(false), "Expected bus")
        }
    }
    
    @Test
    func updateTrams() async throws {
        let manager = MapStateManager()
        let tram1 = BusModel(id: 2, lineName: "4", routeId: "2", latitude: 60, longitude: 25, heading: 0, timestamp: 0, type: .tram)
        
        // Initial Update
        manager.updateTrams([tram1])
        
        // Wait for coalescing
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(manager.vehicles.count == 1)
        if case .tram(let t) = manager.vehicles.first {
            #expect(t.id == 2)
        } else {
            #expect(Bool(false), "Expected tram")
        }
    }
    
    @Test
    func coalescingUpdates() async throws {
        let manager = MapStateManager()
        let bus1 = BusModel(id: 1, lineName: "1", routeId: "1", latitude: 60, longitude: 25, heading: 0, timestamp: 0, type: .bus)
        let bus2 = BusModel(id: 1, lineName: "1", routeId: "1", latitude: 61, longitude: 25, heading: 0, timestamp: 1, type: .bus) // Moved
        
        // Rapid updates
        manager.updateBuses([bus1])
        manager.updateBuses([bus2])
        
        // Wait for coalescing
        try await Task.sleep(for: .milliseconds(50))
        
        // Should only have the latest state
        #expect(manager.vehicles.count == 1)
        if case .bus(let b) = manager.vehicles.first {
            #expect(b.latitude == 61) // Should have the second update's position
        }
    }
    
    @Test
    func mixedUpdates() async throws {
        let manager = MapStateManager()
        let bus = BusModel(id: 1, lineName: "1", routeId: "1", latitude: 60, longitude: 25, heading: 0, timestamp: 0, type: .bus)
        let tram = BusModel(id: 2, lineName: "4", routeId: "2", latitude: 60, longitude: 25, heading: 0, timestamp: 0, type: .tram)
        
        manager.updateBuses([bus])
        manager.updateTrams([tram])
        
        // Wait for coalescing
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(manager.vehicles.count == 2)
    }

    @Test
    func mapItemsOrdering() async throws {
        let manager = MapStateManager()
        let bus = BusModel(id: 1, lineName: "1", routeId: "1", latitude: 60, longitude: 25, heading: 0, timestamp: 0, type: .bus)
        let tram = BusModel(id: 2, lineName: "4", routeId: "2", latitude: 60, longitude: 25, heading: 0, timestamp: 0, type: .tram)
        let stop = BusStop(id: "STOP1", name: "Stop 1", latitude: 60.1, longitude: 24.9)

        manager.updateBuses([bus])
        manager.updateTrams([tram])
        manager.updateStops([stop])

        try await Task.sleep(for: .milliseconds(50))

        #expect(manager.mapItems.count == 3)
        if case .bus = manager.mapItems.first {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected bus first")
        }
        if case .tram = manager.mapItems[1] {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected tram second")
        }
        if case .stop = manager.mapItems[2] {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected stop third")
        }
    }
}
