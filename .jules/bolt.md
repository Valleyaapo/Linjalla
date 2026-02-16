## 2025-05-15 - Environment Constraints
**Learning:** The development environment lacks `swift` and `xcodebuild` executables.
**Action:** Verification must rely on static analysis and code review; cannot run unit tests or builds.

## 2025-05-15 - String Allocations in Hot Loops
**Learning:** `DepartureFiltering` was allocating 4-5 strings per departure check, causing overhead in list filtering.
**Action:** Pre-calculate normalized comparison sets (stripping "HSL:" and suffixes) in the filter input's `init` to allow O(1) lookups without allocation in the hot loop.
