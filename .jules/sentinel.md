## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-04 - Information Disclosure
**Vulnerability:** Excessive public logging of GraphQL errors and encoding errors in `GraphQLClient.swift` using `privacy: .public` was found. This could expose sensitive error details (such as API keys, internal server paths, or partial query data) in system logs.
**Learning:** `OSLog`'s `privacy: .public` explicitly overrides the default redaction of dynamic strings. Developers often use it for easier debugging during development but forget to remove it for production, leading to information leakage.
**Prevention:** Audit all `Logger` calls for `privacy: .public` and remove it unless the logged data is strictly non-sensitive. Rely on the default privacy (private/redacted) for dynamic strings in production code.
