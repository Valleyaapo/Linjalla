## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-05 - MQTT Client ID Collision (DoS)
**Vulnerability:** The MQTT Client ID was generated using `Int.random(in: 0...10000)`, providing only ~13 bits of entropy. This resulted in a high probability of collision (~40% with just 100 concurrent users), causing the broker to disconnect existing sessions (Denial of Service).
**Learning:** Developers often underestimate the probability of collision in small namespaces (Birthday Paradox). Unique identifiers in distributed systems must have sufficient entropy.
**Prevention:** Use `UUID().uuidString` or similar high-entropy sources (at least 64 bits of randomness) for client identifiers to ensure global uniqueness.
