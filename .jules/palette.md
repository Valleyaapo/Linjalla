## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Full Words in Accessibility Labels
**Learning:** Abbreviations like "min" (meaning minutes) can be ambiguous or mispronounced by screen readers (e.g., as "minimum"). Using full words ("minutes") in accessibility labels ensures clarity.
**Action:** Create dedicated `.accessible` localization keys for time durations and handle pluralization logic (1 minute vs 5 minutes) explicitly in code when using simple string formats.
