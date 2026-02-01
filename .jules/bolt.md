## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-01-03 - String Allocation in Hot Paths
**Learning:** Frequent string manipulation (e.g., `replacingOccurrences`) in computed properties and loops can create significant allocation overhead in high-frequency update cycles (MQTT).
**Action:** Convert frequently accessed computed properties to stored properties (computed once at init) and remove redundant normalizations in update loops. Ensure Codable backward compatibility when changing model structure.
