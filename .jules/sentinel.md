## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-05 - Prevention of Sensitive Data Leakage in System Logs
**Vulnerability:** The `GraphQLClient` was explicitly logging error messages and descriptions with `privacy: .public` in `OSLog`. This could expose internal API details, query parameters, or potentially PII in system logs (sysdiagnose), which are accessible to other apps or crash reporters.
**Learning:** `OSLog` defaults to `.private` for interpolated strings to protect user privacy. Explicitly overriding this with `privacy: .public` for error reporting is a dangerous pattern unless the data is guaranteed to be safe.
**Prevention:** Rely on the default `.private` privacy for dynamic strings in logs. Avoid `.public` for any data that might contain variable content.
