## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-02-01 - MQTT Session Collisions via Weak Entropy
**Vulnerability:** The MQTT client identifier was generated using `Int.random(in: 0...10000)`, resulting in a high probability of collision (birthday paradox) with a small user base, leading to session termination (DoS).
**Learning:** For globally unique identifiers in distributed systems (like MQTT Client IDs), simple random integers are insufficient. Entropy must be high enough to make collisions negligible.
**Prevention:** Use `UUID` (or a prefix of it) or cryptographically secure random number generators for session identifiers to ensure uniqueness.
