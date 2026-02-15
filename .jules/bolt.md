## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-05-16 - SwiftUI List Performance
**Learning:** Initializing `Identifiable` structs with `UUID()` (e.g., `id: UUID = UUID()`) causes stable data to be perceived as new by SwiftUI on every fetch, triggering full list re-renders and destroying view state.
**Action:** Use stable identifiers derived from data properties (e.g., `routeId + time`) for list models to enable SwiftUI diffing and prevent unnecessary updates.
