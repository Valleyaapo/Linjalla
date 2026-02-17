## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2025-05-20 - Actor-Isolated Parsing
**Learning:** High-frequency MQTT updates (e.g., vehicle positions) can block the Main Actor if parsed inline, causing UI stutter.
**Action:** Always offload JSON decoding and data normalization to a dedicated actor (e.g., `VehicleParser`) before yielding results to the Main Actor.
