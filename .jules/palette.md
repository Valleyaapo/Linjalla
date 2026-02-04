## 2026-01-22 - Dynamic Accessibility Labels
**Learning:** In SwiftUI, accessibility labels for toggle buttons should explicitly describe the action (e.g., "Add to favorites" vs "Remove from favorites") rather than just the state ("Saved"), especially in list contexts where the user might not see the visual state change immediately.
**Action:** Always use conditional logic in `.accessibilityLabel` for toggle buttons to provide clear, actionable feedback to VoiceOver users.

## 2026-01-22 - Comprehensive Row Labels
**Learning:** Complex list rows often distribute information (like platform numbers or absolute times) across multiple subviews or icons. A simple `.accessibilityElement(children: .combine)` might miss context if the default descriptions aren't sufficient.
**Action:** Use a computed property to construct a comprehensive `accessibilityLabel` that explicitly includes all key data points (e.g., "Platform 5", "14:30") in a natural sentence structure, separated by punctuation for clear VoiceOver pauses.
