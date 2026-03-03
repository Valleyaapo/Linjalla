## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.
## 2026-05-15 - BaseVehicleManager active lines optimization
**Learning:** In BaseVehicleManager, repeatedly calculating Set conversions (from an array of active line models) during the main update/flush loop causes needless allocations. We can optimize this by performing Set calculation and caching only inside a `didSet` property observer on the `activeLines` property.
**Action:** Use `didSet` observers to pre-calculate and cache expensive derivations (like Sets) of frequently-accessed arrays, and avoid redundant string manipulation in high-frequency loops when invariants guarantee normalization upstream.
