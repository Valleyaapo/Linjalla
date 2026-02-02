## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-04 - OSLog Privacy Leakage
**Vulnerability:** Explicit use of `privacy: .public` in `Logger` calls exposed internal error details and potential PII in system logs.
**Learning:** Developers might override default privacy settings for convenience, inadvertently leaking sensitive data.
**Prevention:** Remove `privacy: .public` unless the data is static or explicitly classified as public. Rely on the default `.private` redaction for dynamic strings.
