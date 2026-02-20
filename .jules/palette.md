## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-02-20 - Natural Time Durations
**Learning:** Abbreviated time units (e.g., "min") in accessibility labels are often mispronounced or ambiguous (e.g., "minimum") by screen readers.
**Action:** Use a dedicated `timeUntilAccessible` formatter that returns full words (e.g., "5 minutes") and handles pluralization explicitly for accessibility labels.
