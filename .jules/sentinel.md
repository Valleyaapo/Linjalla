## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2023-10-25 - Information Leakage via Raw Error Propagation
**Vulnerability:** The `GraphQLClient` threw raw backend errors from GraphQL payloads directly to the UI layer via `AppError.apiError`, which could expose sensitive backend details or schema information.
**Learning:** Raw API or server errors should never be passed transparently to the client interface, as backend error messages are not guaranteed to be sanitized.
**Prevention:** Catch external API errors and map them to generic, user-friendly messages (e.g., "Invalid request or server error") while continuing to log the detailed raw errors internally for debugging.
