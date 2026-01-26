//
//  AnimationStateManager.swift
//  RT Bus
//
//  Centralized manager for all vehicle animation states
//

import Foundation
import MapKit

/// Manages animation states for all vehicles on the map.
/// Provides race condition prevention via generation counters and pending removal tracking.
@MainActor
final class AnimationStateManager {
    
    // MARK: - Properties
    
    /// Active animation states keyed by vehicle ID
    private var states: [String: VehicleAnimationState] = [:]
    
    /// Pending removals: vehicles that are animating out
    /// Key: vehicleId, Value: (annotation, generation when exit started)
    private var pendingRemovals: [String: (annotation: VehicleAnnotation, generation: UInt64)] = [:]
    
    // MARK: - State Access
    
    /// Get or create animation state for a vehicle
    func state(for vehicleId: String) -> VehicleAnimationState {
        if let existing = states[vehicleId] {
            return existing
        }
        let new = VehicleAnimationState(vehicleId: vehicleId)
        states[vehicleId] = new
        return new
    }
    
    /// Check if state exists for a vehicle
    func hasState(for vehicleId: String) -> Bool {
        states[vehicleId] != nil
    }
    
    /// Remove state for a vehicle (after confirmed removal)
    func removeState(for vehicleId: String) {
        states.removeValue(forKey: vehicleId)
    }
    
    // MARK: - Pending Removal Management
    
    /// Mark a vehicle as pending removal (exit animation started)
    func markPendingRemoval(vehicleId: String, annotation: VehicleAnnotation, generation: UInt64) {
        pendingRemovals[vehicleId] = (annotation: annotation, generation: generation)
    }
    
    /// Cancel pending removal if vehicle reappears
    /// Returns the annotation that was pending removal, or nil if not found
    @discardableResult
    func cancelPendingRemoval(vehicleId: String) -> VehicleAnnotation? {
        let removed = pendingRemovals.removeValue(forKey: vehicleId)
        return removed?.annotation
    }
    
    /// Check if vehicle is pending removal
    func isPendingRemoval(vehicleId: String) -> Bool {
        pendingRemovals[vehicleId] != nil
    }
    
    /// Validate pending removal - only returns annotation if generation matches
    /// This ensures stale completions are ignored
    func validatePendingRemoval(vehicleId: String, generation: UInt64) -> VehicleAnnotation? {
        guard let pending = pendingRemovals[vehicleId] else { return nil }
        
        // Check if this completion is still valid
        if pending.generation == generation {
            pendingRemovals.removeValue(forKey: vehicleId)
            return pending.annotation
        }
        
        // Generation mismatch - removal was cancelled and possibly restarted
        return nil
    }
    
    /// Get all pending removal vehicle IDs
    var pendingRemovalIds: Set<String> {
        Set(pendingRemovals.keys)
    }
    
    // MARK: - Cleanup
    
    /// Clear all states (e.g., when map is dismissed)
    func clearAll() {
        states.removeAll()
        pendingRemovals.removeAll()
    }
}
