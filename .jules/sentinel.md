## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-04 - Parameterized GraphQL Queries (Implementation)
**Vulnerability:** The `DigitransitService` used string interpolation to inject `transportMode.rawValue` into the GraphQL query string. While the input was an enum (reducing immediate risk), this violates the principle of separating code and data.
**Learning:** Documenting a vulnerability is not enough; the code must actually be updated to use parameterized queries.
**Prevention:** Always use GraphQL variables for any data passed to a query. I have now implemented the fix by making `TransportMode` encodable and updating the query to use `$modes`.
