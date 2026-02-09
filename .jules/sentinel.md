## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-05 - Sensitive Data Exposure in System Logs
**Vulnerability:** The `GraphQLClient` was explicitly configured with `privacy: .public` when logging error messages, which forced the system to bypass its default redaction of dynamic strings. This exposed potentially sensitive GraphQL error details (e.g., internal schema errors, user IDs) to system logs visible to anyone with access to the device.
**Learning:** Developers often disable privacy redaction during debugging and forget to revert it. `privacy: .public` should be strictly scrutinized in code reviews.
**Prevention:** Rely on default `OSLog` behavior (which defaults to `.private` for dynamic strings) in production code. Use conditional compilation if verbose logging is needed for debug builds.
