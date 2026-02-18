## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-01-04 - Phantom Architecture
**Learning:** Memory indicated `BaseVehicleManager` used `VehicleParser`, but the file did not exist in the codebase.
**Action:** Always verify "known" architecture against actual files before assuming components exist; be prepared to implement "missing" components that are documented but not present.

## 2026-01-04 - Main Actor Bottleneck
**Learning:** High-frequency MQTT JSON decoding was happening on Main Actor in `BaseVehicleManager`, blocking UI updates.
**Action:** Offloaded decoding to a dedicated `VehicleParser` actor using `Task.detached`, only hopping back to Main Actor to yield the result.
