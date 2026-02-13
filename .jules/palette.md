## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Accessible Time Durations
**Learning:** Abbreviations like 'min' are often read literally by screen readers (e.g., 'minimum' or 'min'), causing confusion.
**Action:** Use separate localization keys for accessibility (e.g., 'ui.time.minute.accessible') that use full words ('minute', 'minutes') while keeping visual UI compact.
