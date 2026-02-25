//
//  VehicleManagerOptimizationTests.swift
//  RT BusTests
//
//  Created by Bolt on 25.01.2026.
//

import Testing
import Foundation
import RTBusCore
@testable import RT_Bus

@MainActor
@Suite("VehicleManagerOptimization")
struct VehicleManagerOptimizationTests {

    @Test("flushUpdates filters vehicles correctly based on active lines")
    func flushUpdatesFiltering() async throws {
        // 1. Setup Manager
        let manager = BaseVehicleManager(connectOnStart: false)
        // Set a shorter update interval for testing if possible, but it's constant.
        // We'll wait > 1.0s.

        // 2. Setup Active Lines
        let line1015 = BusLine(id: "HSL:1015", shortName: "1015", longName: "Line 1015")
        manager.updateSubscriptions(selectedLines: [line1015])

        // 3. Create Vehicles (Simulate processMessage output: normalized routeIds)
        let matchingVehicle = BusModel(
            id: 1,
            lineName: "1015",
            routeId: "1015", // Normalized
            latitude: 60.0,
            longitude: 24.0,
            heading: 0,
            timestamp: Date().timeIntervalSince1970,
            type: .bus
        )

        let nonMatchingVehicle = BusModel(
            id: 2,
            lineName: "1004",
            routeId: "1004", // Normalized
            latitude: 60.1,
            longitude: 24.1,
            heading: 0,
            timestamp: Date().timeIntervalSince1970,
            type: .bus
        )

        // 4. Buffer vehicles
        await manager.stream.buffer(matchingVehicle)
        await manager.stream.buffer(nonMatchingVehicle)

        // 5. Wait for flushUpdates (Interval is 1.0s)
        try await Task.sleep(for: .seconds(1.5))

        // 6. Verify
        let vehicles = manager.vehicles
        #expect(vehicles.count == 1, "Should have exactly one vehicle")
        #expect(vehicles[1] != nil, "Matching vehicle (ID 1) should be present")
        #expect(vehicles[2] == nil, "Non-matching vehicle (ID 2) should NOT be present")

        manager.cleanup()
    }
}
