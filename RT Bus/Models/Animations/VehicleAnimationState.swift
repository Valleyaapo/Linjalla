//
//  VehicleAnimationState.swift
//  RT Bus
//
//  Tracks animation lifecycle for a single vehicle annotation.
//

import CoreLocation
import CoreGraphics
import QuartzCore

/// Animation lifecycle phases for a vehicle
enum VehicleAnimationPhase: Equatable {
    case idle
    case entering
    case updating(targetCoordinate: CLLocationCoordinate2D, targetHeading: Double)
    case exiting

    static func == (lhs: VehicleAnimationPhase, rhs: VehicleAnimationPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.entering, .entering), (.exiting, .exiting):
            return true
        case let (.updating(lCoord, lHead), .updating(rCoord, rHead)):
            return lCoord.latitude == rCoord.latitude &&
                   lCoord.longitude == rCoord.longitude &&
                   lHead == rHead
        default:
            return false
        }
    }
}

/// Single source of truth for a vehicle's animation state.
/// Used to coordinate animations and validate completion handlers.
@MainActor
final class VehicleAnimationState {
    let vehicleId: String

    /// Current animation phase
    private(set) var phase: VehicleAnimationPhase = .idle

    /// Generation counter - increments on each animation start.
    /// Completion handlers check this to ensure they're still valid.
    private(set) var generation: UInt64 = 0

    /// Captured velocity for smooth animation interruption
    private(set) var headingVelocity: CGFloat = 0

    /// Timestamp of last animation start (for debugging/metrics)
    private(set) var lastUpdateTime: TimeInterval = 0

    init(vehicleId: String) {
        self.vehicleId = vehicleId
    }

    /// Begin entry animation - returns generation for completion validation
    @discardableResult
    func beginEntering() -> UInt64 {
        generation += 1
        phase = .entering
        lastUpdateTime = CACurrentMediaTime()
        return generation
    }

    /// Begin update animation with target values - returns generation for completion validation
    @discardableResult
    func beginUpdating(to coordinate: CLLocationCoordinate2D, heading: Double) -> UInt64 {
        generation += 1
        phase = .updating(targetCoordinate: coordinate, targetHeading: heading)
        lastUpdateTime = CACurrentMediaTime()
        return generation
    }

    /// Begin exit animation - returns generation for completion validation
    @discardableResult
    func beginExiting() -> UInt64 {
        generation += 1
        phase = .exiting
        lastUpdateTime = CACurrentMediaTime()
        return generation
    }

    /// Complete animation if generation matches.
    /// Returns true if transition to idle occurred.
    @discardableResult
    func complete(generation expectedGeneration: UInt64) -> Bool {
        guard generation == expectedGeneration else { return false }
        phase = .idle
        return true
    }

    /// Record velocity for next animation's smooth start
    func recordHeadingVelocity(_ velocity: CGFloat) {
        headingVelocity = velocity
    }

    /// Clear velocity after use
    func clearVelocity() {
        headingVelocity = 0
    }
}
