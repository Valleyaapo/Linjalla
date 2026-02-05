## 2026-01-22 - Accessibility formatting separation
**Learning:** Visual UI often needs abbreviated units (e.g. "5 min") for space, but screen readers need full words ("5 minutes") for clarity.
**Action:** Create separate formatting methods (e.g. `timeUntil` vs `timeUntilAccessible`) to serve both needs without compromising either.

## 2026-01-22 - Keyboard Types for Alphanumeric IDs
**Learning:** `keyboardType(.numberPad)` blocks entry of alphanumeric IDs (e.g., bus lines "550B").
**Action:** Use `.default` or `.asciiCapable` for ID input fields where letters might occur, even if predominantly numeric.
