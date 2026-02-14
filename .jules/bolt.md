## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2025-05-15 - Actor Isolation and `nonisolated`
**Learning:** Using `nonisolated` properties on `@MainActor` classes can be flagged as syntax errors or unsafe depending on Swift version and context, even for `Sendable` types.
**Action:** Prefer omitting `nonisolated` on properties unless strictly necessary for performance and verified against the project's Swift version. Rely on `await` for access or use `nonisolated` methods.
