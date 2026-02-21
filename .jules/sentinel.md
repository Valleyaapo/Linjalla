## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-05 - MQTT Client ID Collision DoS
**Vulnerability:** `BaseVehicleManager` generated MQTT client identifiers using a small integer range (`0...10000`), leading to high collision probability. In MQTT, duplicate client IDs cause the broker to disconnect existing sessions, resulting in a Denial of Service (DoS) where users inadvertently kick each other offline.
**Learning:** Random integers with small ranges are insufficient for session identifiers in distributed applications. The Birthday Paradox makes collisions likely even with a small user base.
**Prevention:** Use `UUID` or other high-entropy generators for unique client identifiers to ensure global uniqueness and prevent session conflicts.
