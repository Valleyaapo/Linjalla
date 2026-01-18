//
//  AnimationStateManagerTests.swift
//  RTBusTests
//
//  Pure unit tests for animation state logic - no simulator required
//

import Testing
import Foundation
import CoreLocation
@testable import RT_Bus

// MARK: - VehicleAnimationState Tests

@MainActor
@Suite(.serialized)
struct VehicleAnimationStateTests {
    
    @Test
    func initialState() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        
        #expect(state.vehicleId == "bus_1")
        #expect(state.phase == .idle)
        #expect(state.generation == 0)
        #expect(state.headingVelocity == 0)
    }
    
    @Test
    func beginEnteringIncrementsGeneration() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        
        let gen1 = state.beginEntering()
        #expect(gen1 == 1)
        #expect(state.phase == .entering)
        
        let gen2 = state.beginEntering()
        #expect(gen2 == 2)
        #expect(state.generation == 2)
    }
    
    @Test
    func beginUpdatingTracksTarget() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        let coord = CLLocationCoordinate2D(latitude: 60.0, longitude: 25.0)
        
        let gen = state.beginUpdating(to: coord, heading: 45.0)
        #expect(gen == 1)
        
        if case .updating(let targetCoord, let targetHeading) = state.phase {
            #expect(targetCoord.latitude == 60.0)
            #expect(targetCoord.longitude == 25.0)
            #expect(targetHeading == 45.0)
        } else {
            Issue.record("Expected .updating phase")
        }
    }
    
    @Test
    func beginExitingIncrementsGeneration() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        
        let gen = state.beginExiting()
        #expect(gen == 1)
        #expect(state.phase == .exiting)
    }
    
    @Test
    func completeWithMatchingGeneration() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        
        let gen = state.beginEntering()
        #expect(state.phase == .entering)
        
        let result = state.complete(generation: gen)
        #expect(result == true)
        #expect(state.phase == .idle)
    }
    
    @Test
    func completeWithStaleGenerationDoesNotTransition() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        
        let gen1 = state.beginEntering()
        let _ = state.beginExiting() // Increments generation to 2
        
        // Try to complete with stale generation (1)
        let result = state.complete(generation: gen1)
        #expect(result == false)
        #expect(state.phase == .exiting) // Still exiting, not idle
    }
    
    @Test
    func multiplePhaseTransitions() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        
        // Entry
        let gen1 = state.beginEntering()
        #expect(state.phase == .entering)
        state.complete(generation: gen1)
        #expect(state.phase == .idle)
        
        // Update
        let coord = CLLocationCoordinate2D(latitude: 60, longitude: 25)
        let gen2 = state.beginUpdating(to: coord, heading: 90)
        #expect(state.generation == 2)
        state.complete(generation: gen2)
        
        // Exit
        let gen3 = state.beginExiting()
        #expect(state.generation == 3)
        #expect(state.phase == .exiting)
        state.complete(generation: gen3)
        #expect(state.phase == .idle)
    }
    
    @Test
    func headingVelocityTracking() {
        let state = VehicleAnimationState(vehicleId: "bus_1")
        
        state.recordHeadingVelocity(2.5)
        #expect(state.headingVelocity == 2.5)
        
        state.clearVelocity()
        #expect(state.headingVelocity == 0)
    }
    
    @Test
    func phaseEquality() {
        let coord1 = CLLocationCoordinate2D(latitude: 60, longitude: 25)
        let coord2 = CLLocationCoordinate2D(latitude: 60, longitude: 25)
        let coord3 = CLLocationCoordinate2D(latitude: 61, longitude: 25)
        
        #expect(VehicleAnimationPhase.idle == VehicleAnimationPhase.idle)
        #expect(VehicleAnimationPhase.entering == VehicleAnimationPhase.entering)
        #expect(VehicleAnimationPhase.exiting == VehicleAnimationPhase.exiting)
        #expect(VehicleAnimationPhase.updating(targetCoordinate: coord1, targetHeading: 45) ==
                VehicleAnimationPhase.updating(targetCoordinate: coord2, targetHeading: 45))
        #expect(VehicleAnimationPhase.updating(targetCoordinate: coord1, targetHeading: 45) !=
                VehicleAnimationPhase.updating(targetCoordinate: coord3, targetHeading: 45))
        #expect(VehicleAnimationPhase.idle != VehicleAnimationPhase.entering)
    }
}

// MARK: - AnimationStateManager Tests (Pure State Logic)

@MainActor
@Suite(.serialized)
struct AnimationStateManagerPureTests {
    
    @Test
    func stateCreationAndReuse() {
        let manager = AnimationStateManager()
        
        let state1 = manager.state(for: "bus_1")
        let state2 = manager.state(for: "bus_1")
        
        #expect(state1 === state2) // Same instance returned
    }
    
    @Test
    func differentVehiclesGetDifferentStates() {
        let manager = AnimationStateManager()
        
        let state1 = manager.state(for: "bus_1")
        let state2 = manager.state(for: "bus_2")
        
        #expect(state1 !== state2)
        #expect(state1.vehicleId == "bus_1")
        #expect(state2.vehicleId == "bus_2")
    }
    
    @Test
    func hasStateCheck() {
        let manager = AnimationStateManager()
        
        #expect(manager.hasState(for: "bus_1") == false)
        
        _ = manager.state(for: "bus_1")
        
        #expect(manager.hasState(for: "bus_1") == true)
        #expect(manager.hasState(for: "bus_2") == false)
    }
    
    @Test
    func removeState() {
        let manager = AnimationStateManager()
        
        _ = manager.state(for: "bus_1")
        #expect(manager.hasState(for: "bus_1") == true)
        
        manager.removeState(for: "bus_1")
        #expect(manager.hasState(for: "bus_1") == false)
    }
    
    @Test
    func removeStateDoesNotAffectOthers() {
        let manager = AnimationStateManager()
        
        _ = manager.state(for: "bus_1")
        _ = manager.state(for: "bus_2")
        
        manager.removeState(for: "bus_1")
        
        #expect(manager.hasState(for: "bus_1") == false)
        #expect(manager.hasState(for: "bus_2") == true)
    }
    
    @Test
    func isPendingRemovalInitiallyFalse() {
        let manager = AnimationStateManager()
        
        #expect(manager.isPendingRemoval(vehicleId: "bus_1") == false)
    }
    
    @Test
    func pendingRemovalIdsInitiallyEmpty() {
        let manager = AnimationStateManager()
        
        #expect(manager.pendingRemovalIds.isEmpty)
    }
    
    @Test
    func clearAllRemovesEverything() {
        let manager = AnimationStateManager()
        
        _ = manager.state(for: "bus_1")
        _ = manager.state(for: "bus_2")
        _ = manager.state(for: "tram_1")
        
        manager.clearAll()
        
        #expect(manager.hasState(for: "bus_1") == false)
        #expect(manager.hasState(for: "bus_2") == false)
        #expect(manager.hasState(for: "tram_1") == false)
    }
    
    @Test
    func stateGenerationIndependence() {
        let manager = AnimationStateManager()
        
        let state1 = manager.state(for: "bus_1")
        let state2 = manager.state(for: "bus_2")
        
        let gen1 = state1.beginEntering()
        let gen2 = state2.beginEntering()
        
        // Both should start at generation 1
        #expect(gen1 == 1)
        #expect(gen2 == 1)
        
        // Incrementing one doesn't affect the other
        let gen1b = state1.beginExiting()
        #expect(gen1b == 2)
        #expect(state2.generation == 1)
    }
}
