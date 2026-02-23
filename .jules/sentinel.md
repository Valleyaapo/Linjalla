## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-14 - Weak MQTT Client ID Generation
**Vulnerability:** The MQTT client identifier was generated using `Int.random(in: 0...10000)`, leading to a high probability of collisions (~50% at ~118 clients). This causes a Denial of Service (DoS) where users disconnect each other.
**Learning:** Using small ranges for unique identifiers in distributed systems guarantees collisions due to the Birthday Paradox.
**Prevention:** Always use `UUID` or cryptographically secure random values with sufficient entropy (at least 64 bits, preferably 128) for session identifiers in shared environments.
