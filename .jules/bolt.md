## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-01-03 - String Allocation in MQTT Handlers
**Learning:** High-frequency MQTT topic parsing using `String.split` creates excessive allocation traffic.
**Action:** Implement manual index-based parsing loops to extract components without intermediate arrays or strings.
