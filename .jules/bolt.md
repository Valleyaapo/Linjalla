## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2026-01-03 - Offloading MQTT Parsing
**Learning:** High-frequency MQTT message processing (parsing JSON + String manipulation) on the Main Actor can cause significant UI jank, even if individual operations are fast.
**Action:** Use `Task.detached` to offload parsing logic to a background thread, then yield the result to the Main Actor via `await`. Use `static` methods for the parsing logic to ensure thread safety and avoid capturing `self` unnecessarily.
