## 2026-01-22 - Accessibility formatting separation
**Learning:** Visual UI often needs abbreviated units (e.g. "5 min") for space, but screen readers need full words ("5 minutes") for clarity.
**Action:** Create separate formatting methods (e.g. `timeUntil` vs `timeUntilAccessible`) to serve both needs without compromising either.

## 2026-01-22 - Keyboard Types Constraints
**Learning:** User strictly prefers `.numberPad` for line search inputs, even if it limits alphanumeric entry.
**Action:** Do not suggest changing `keyboardType` from `.numberPad` to `.default` for this view.
