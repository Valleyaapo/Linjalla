## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-04 - Private Logging by Default
**Vulnerability:** The `GraphQLClient` was explicitly using `privacy: .public` when logging error details, potentially exposing sensitive data (like PII or internal schema info) to persistent system logs.
**Learning:** In Swift's `OSLog`, interpolated strings are redacted (`<private>`) by default. Explicitly opting out via `.public` bypasses this protection and should be avoided for dynamic error content.
**Prevention:** Rely on the default privacy level (redacted) for all dynamic content in logs unless there is a specific, safe reason to expose it.
