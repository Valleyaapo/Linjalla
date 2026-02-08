## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-01-04 - Offloading JSON Decoding
**Learning:** High-frequency JSON decoding on `@MainActor` (e.g. MQTT updates) blocks the UI thread.
**Action:** Use a dedicated actor (e.g., `VehicleParser`) with a reused `JSONDecoder` instance, and invoke it via `Task.detached` to offload processing to background threads while maintaining thread safety.
