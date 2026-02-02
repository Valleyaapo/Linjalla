
## 2026-01-24 - Punctuality Accessibility
**Learning:** Departure rows visually showed time but hid delay status (late/early) from screen readers, missing a critical context for transit users.
**Action:** Always include computed status (e.g., "Late 2 min") in `accessibilityLabel` for time-sensitive data, not just the raw timestamp.
