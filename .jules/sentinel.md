## 2026-01-04 - [Enhancement] GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-08 - [Enhancement] Default to Private for Unified Logging
**Vulnerability:** Explicit use of `privacy: .public` in `OSLog` interpolations exposed sensitive GraphQL error details and request variables in system logs, risking PII leakage.
**Learning:** `OSLog`'s privacy defaults are secure (`.private` for dynamic strings), but developers might override this for debugging convenience, inadvertently creating production risks.
**Prevention:** Remove explicit `privacy: .public` for error messages unless the data is strictly non-sensitive (e.g., static configuration errors). Prefer `.private` or default behavior for dynamic runtime errors.
