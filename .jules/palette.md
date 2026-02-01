## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Missing Visual Context in Accessibility Labels
**Learning:** Visual elements like platform numbers ("Platform 5") are often displayed in auxiliary views but omitted from the primary `.accessibilityLabel` of a list row, leaving blind users with incomplete wayfinding information.
**Action:** Audit list rows to ensure *all* informational text displayed visually is also included in the constructed accessibility label string.
