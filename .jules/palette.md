## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - DepartureRow Accessibility
**Learning:** Time strings like "3 min" need explicit localization keys (e.g., "%d minute", "%d minutes") for screen readers to ensure correct pronunciation and pluralization.
**Action:** Always create separate `.accessible` keys for time durations instead of relying on visual abbreviations.
