# Animation State Management System Plan

## Problem Summary

The current UIKit map implementation has animation state scattered across three places (MapViewCoordinator, VehicleAnnotation, VehicleAnnotationView), causing:
- Coordinate animation conflicts (double-animation from UIView.animate + MapKit KVO)
- No interruption handling for rapid updates
- Race conditions on vehicle removal/reappearance
- Desynchronized heading and position animations

## Solution: Centralized Animation State Manager

### New Files

**1. `RT Bus/Models/Animations/VehicleAnimationState.swift`**
```swift
enum VehicleAnimationPhase {
    case idle
    case entering
    case updating(targetCoordinate:, targetHeading:)
    case exiting
}

final class VehicleAnimationState {
    let vehicleId: String
    private(set) var phase: VehicleAnimationPhase = .idle
    private(set) var generation: UInt64 = 0  // Invalidates stale completions
    private(set) var headingVelocity: CGFloat = 0  // For smooth interruption

    func beginEntering() / beginUpdating() / beginExiting()
    func complete(generation:) -> Bool  // Only transitions if generation matches
}
```

**2. `RT Bus/Models/Animations/AnimationStateManager.swift`**
```swift
final class AnimationStateManager {
    private var states: [String: VehicleAnimationState] = [:]
    private var pendingRemovals: [String: (annotation:, generation:)] = [:]

    func state(for vehicleId:) -> VehicleAnimationState
    func markPendingRemoval() / cancelPendingRemoval() / validatePendingRemoval()
}
```

### Modified Files

**3. `RT Bus/Models/Annotations/VehicleAnnotation.swift`**
- Remove `UIView.animate` wrapper from `update(from:)`
- Let MapKit handle coordinate animation via KVO on `@objc dynamic var coordinate`

**4. `RT Bus/Views/Annotations/VehicleAnnotationView.swift`**
- Remove KVO observer for heading
- Remove `hasAnimatedIn` flag
- Add `UIViewPropertyAnimator`-based methods:
  - `animateEntry(heading:, completion:)` - spring scale 0.3 → 1.0
  - `animateUpdate(toHeading:, headingVelocity:, completion:)` - spring with velocity
  - `animateExit(completion:)` - ease-in scale down + fade

**5. `RT Bus/Views/Map/MapViewCoordinator.swift`**
- Add `AnimationStateManager` instance
- Refactor `updateAnnotations()` to:
  - Detect pending removals and cancel if vehicle reappears
  - Separate vehicle processing from animation triggering
  - Use generation-validated completions for safe removal

## Animation Flow

```
Entry:  addAnnotation → viewFor → configure() → beginEntering() → animateEntry()
Update: annotation.update() → beginUpdating() → animateUpdate(headingVelocity)
Exit:   beginExiting() → markPendingRemoval(gen) → animateExit() → validate(gen) → remove
```

**Race condition fix:** If vehicle reappears during exit animation, `cancelPendingRemoval()` recovers the annotation and the exit completion's generation check fails silently.

## Key Design Decisions

1. **No KVO for heading** - coordinator explicitly triggers coordinated animations
2. **Spring animations with velocity** - enables smooth retargeting mid-animation
3. **Generation counter** - eliminates race conditions without locks
4. **MapKit handles coordinates** - removing UIView.animate avoids double-animation

## Files to Modify

| File | Change |
|------|--------|
| `Models/Animations/VehicleAnimationState.swift` | NEW |
| `Models/Animations/AnimationStateManager.swift` | NEW |
| `Models/Annotations/VehicleAnnotation.swift` | Remove UIView.animate from update() |
| `Views/Annotations/VehicleAnnotationView.swift` | Replace KVO with UIViewPropertyAnimator |
| `Views/Map/MapViewCoordinator.swift` | Integrate AnimationStateManager |

## Verification

1. Build the project - no compiler errors
2. Run the app and add a bus line
3. Verify entry animation (vehicles scale in smoothly)
4. Verify update animation (vehicles move smoothly, heading rotates)
5. Verify exit animation (vehicles scale out when line deselected)
6. Test rapid toggle: select/deselect line quickly - no crashes or visual glitches
7. Test interruption: pan map while vehicles are animating - smooth retargeting
