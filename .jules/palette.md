## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-26 - Alphanumeric Input for Transit Lines
**Learning:** Transit line identifiers often contain letters (e.g., "550B", "N"), so restricting input fields to `.numberPad` prevents users from searching for these variants.
**Action:** Always use `.keyboardType(.default)` or `.asciiCapable` for transit line search inputs to support alphanumeric identifiers.
