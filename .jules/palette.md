## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Accessible Time Formatting
**Learning:** Visual abbreviations like "min" for minutes are read literally by screen readers, causing ambiguity (e.g., "minimum").
**Action:** Use a dedicated accessibility formatting method (e.g., `timeUntilAccessible`) with a separate localization key (e.g., `ui.time.min.accessible`) that spells out the full word "minutes".
