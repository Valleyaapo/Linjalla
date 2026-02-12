## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-08 - Sensitive Data Leakage via OSLog
**Vulnerability:** The `GraphQLClient` was explicitly configured to log error messages and backend responses with `privacy: .public`. This bypassed the operating system's default privacy protections, potentially exposing sensitive backend error details (e.g., stack traces, database schema info) to the system console where other applications or physical attackers could view them.
**Learning:** Overriding default privacy settings in `OSLog` (e.g., using `.public`) should only be done for static, non-sensitive strings. Dynamic error messages from external systems must be treated as untrusted and potentially sensitive.
**Prevention:** Rely on the default `OSLog` behavior (which redacts dynamic interpolations in release builds) or explicitly use `privacy: .private` for any variable content derived from external sources or user input.
