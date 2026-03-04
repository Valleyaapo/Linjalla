## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2025-05-15 - Map State Manager Computed Properties
**Learning:** Computed properties returning filtered sets in `@Observable` classes trigger O(N) evaluations upon every access during the hot path of UI rendering via SwiftUI bindings.
**Action:** Calculate filtered arrays atomically during the main update pass (`rebuildItems`) and store them as `private(set) var` instead of re-evaluating on every read.
