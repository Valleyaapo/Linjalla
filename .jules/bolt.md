## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-01-03 - High-Frequency MQTT Topic Parsing
**Learning:** High-frequency MQTT topic parsing in `processMessage` was using `split` (array allocation) and `replacingOccurrences` (string scanning) on every message. This creates significant GC pressure.
**Action:** Implemented a non-allocating `extractRouteId` helper using index manipulation and substring slicing.
