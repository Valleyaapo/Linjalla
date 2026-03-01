## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-03-01 - Weak MQTT Client Identifier Generation
**Vulnerability:** The MQTT client identifier used `Int.random(in: 0...10000)` which provides a very small collision space (10,000 possibilities). If two clients generated the same ID, the MQTT broker would forcefully disconnect one of them, leading to connection instability and potential denial of service.
**Learning:** Always use cryptographically secure random identifiers or true UUIDs for client IDs to guarantee uniqueness and prevent broker-level connection conflicts.
**Prevention:** Use `UUID().uuidString` for generating unique client identifiers.
