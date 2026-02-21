## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Full Words for Accessibility Time Strings
**Learning:** Abbreviations like "min" in visual UI are often read ambiguously by screen readers (e.g., "minimum" or just the letters).
**Action:** Always provide a dedicated `.accessible` localization key with full words (e.g., "minutes") for time durations in accessibility labels.
