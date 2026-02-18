## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-23 - Visual vs. Accessible Localization
**Learning:** Accessibility labels for time durations must use full words (e.g., "minutes") rather than abbreviations (e.g., "min") to ensure natural pronunciation and avoid ambiguity (e.g., "minimum") in screen readers.
**Action:** Create separate localization keys with an `.accessible` suffix (e.g., `ui.time.min.accessible`) for screen reader content, distinct from the visual UI strings.
