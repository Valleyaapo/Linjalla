## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-05 - Sensitive Data Leak in Logs
**Vulnerability:** The `GraphQLClient` was explicitly logging error details with `privacy: .public`, overriding the system's default redaction. This could expose sensitive data (like PII in query variables or internal error structures) to system logs.
**Learning:** Developers often use `privacy: .public` for convenience during debugging, but forget to remove it. This creates a permanent leak of potentially sensitive information in production.
**Prevention:** Rely on the default `privacy: .private` (or `.auto`) for interpolated strings in `OSLog`. Only use `.public` for static strings or data known to be safe and necessary for production diagnostics.
