## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Transit Accessibility Details
**Learning:** In transit apps, visual information like platform numbers is critical for navigation but often missed in default accessibility labels.
**Action:** Always verify that auxiliary information (platform, track, delay status) displayed in a row is explicitly included in the `.accessibilityLabel`.
