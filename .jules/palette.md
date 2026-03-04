## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-03-04 - Screen Reader Labels for Time Durations
**Learning:** Screen readers struggle to correctly pronounce abbreviations like "%d min" in time duration labels, potentially reading it as "minimum" instead of "minutes".
**Action:** Use conditionally explicit format strings with the suffix `.accessible.one` and `.accessible.other` to provide unabbreviated terms (like "1 minute" vs "%d minutes") for accessibility labels.
