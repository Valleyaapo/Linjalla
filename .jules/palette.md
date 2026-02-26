## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Alphanumeric Input for Line Search
**Learning:** Transport line IDs often contain suffixes (e.g., '550B'), making numeric-only keyboards (`.numberPad`) insufficient for search fields and preventing users from finding specific variants.
**Action:** Always use `.default` or `.asciiCapable` keyboard types for transport line search inputs to support alphanumeric identifiers.
