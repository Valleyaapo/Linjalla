## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-04 - Private Logging for Error Data
**Vulnerability:** The `GraphQLClient` was configured to log error messages and encoding failures using `privacy: .public` in `OSLog`. This exposed potentially sensitive information (e.g., reflected input, PII, or internal error details) to the system console, making it accessible to other applications or crash logs.
**Learning:** Default privacy levels in `OSLog` exist for a reason. Overriding them to `.public` for dynamic strings containing external input or error details undermines privacy protections.
**Prevention:** Remove `privacy: .public` modifiers from log statements involving dynamic data unless the data is guaranteed to be non-sensitive and public. Allow the system to redact sensitive values by default.
