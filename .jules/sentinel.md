## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-05 - MQTT Client ID Collision DoS
**Vulnerability:** The `BaseVehicleManager` used `Int.random(in: 0...10000)` to generate its MQTT client identifier. This tiny space (10,001 IDs) makes collisions highly likely when multiple clients connect. A collision forces the broker to drop the existing connection, causing continuous reconnection flapping and Denial of Service (DoS) for users sharing IDs.
**Learning:** Hardcoded strings or low-entropy random IDs used for connection identifiers are a vector for unintentional or intentional disruption of service on shared brokers.
**Prevention:** Always use cryptographically secure random values or standard high-entropy identifiers (like `UUID().uuidString`) for transient client IDs to ensure global uniqueness and prevent connection thrashing.
