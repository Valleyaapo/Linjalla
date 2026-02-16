## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Accessible Time Formatting
**Learning:** Screen readers often mispronounce abbreviations like "min" (as "minimum"). For time durations, it is critical to provide full words (e.g., "minutes") in accessibility labels while keeping the visual UI compact.
**Action:** Implement a dedicated `timeUntilAccessible` method alongside `timeUntil` in formatting helpers. Use separate keys in `Localizable.xcstrings` (e.g., `ui.time.minute.accessible`) to handle singular/plural forms explicitly via code logic if native pluralization is not used.
