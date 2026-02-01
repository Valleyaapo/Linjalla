## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-02-05 - Parameterized GraphQL Enums
**Vulnerability:** Interpolating Enum raw values directly into GraphQL queries creates a potential injection vector if the Enum values are ever compromised or changed to unsafe strings, and violates separation of query structure and data.
**Learning:** When using variables for GraphQL Enums, the variable type in the query definition must match the schema's Enum type (e.g., `[Mode]!`), not `[String]!`, even if the values are passed as strings in the JSON variables.
**Prevention:** Always use typed variables for GraphQL arguments. Verify the schema type for Enums.
