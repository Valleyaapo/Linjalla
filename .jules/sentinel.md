## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-04 - Prevent Sensitive Data Leaks in Logs
**Vulnerability:** The `GraphQLClient` was using `privacy: .public` when logging error messages from the Digitransit API. This could potentially expose sensitive information (like PII or internal system details) if the API response contained such data, as `.public` logs are written to the system log in cleartext.
**Learning:** Avoid using `privacy: .public` for dynamic strings unless you are certain they are safe. Rely on the default behavior (redaction in release builds) or use `.private` for sensitive data.
**Prevention:** Audit all `OSLog` calls for `privacy: .public` and remove it unless strictly necessary and proven safe.
