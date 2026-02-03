## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-01-03 - String Normalization Optimization
**Learning:** High-frequency string manipulation (replacingOccurrences) in tight loops and computed properties caused unnecessary overhead in MQTT message processing.
**Action:** Converted computed properties to stored properties (initialized once) and used `hasPrefix`/`dropFirst` for slicing. Used explicit Codable implementation to preserve JSON contract for derived properties.
