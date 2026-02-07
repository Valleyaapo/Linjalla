## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-04 - OSLog Privacy Regression
**Vulnerability:** The `GraphQLClient` was found to be logging full error details and encoding failures with `privacy: .public`, explicitly bypassing the default redaction of sensitive dynamic data in the Unified Logging System.
**Learning:** Even with clear guidelines stating a security practice, code can regress. Explicit `privacy: .public` modifiers are dangerous when logging error objects that may contain PII or internal state.
**Prevention:** Audit all `Logger` calls for `privacy: .public` usage and question any usage of `.public` for error objects.
