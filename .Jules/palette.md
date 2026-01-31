## 2026-01-26 - Dynamic Type Layouts
**Learning:** Views like SelectionOverlay split layouts based on dynamicTypeSize. The accessibility-optimized layout naturally includes text labels, but the standard icon-only layout often lacks accessibility labels.
**Action:** When reviewing views with dynamic type branching, explicitly check the standard (icon-only) branch for missing .accessibilityLabel modifiers.
