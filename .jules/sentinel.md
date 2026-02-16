## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-31 - Externalizing Secrets via Build Settings
**Vulnerability:** Hardcoded configuration (MQTT host/port/username) in `Secrets.swift` exposed internal infrastructure details and made environment switching impossible without code changes.
**Learning:** Using `Info.plist` with build setting injection (`$(VAR)`) combined with a robust fallback mechanism allows for secure, environment-specific configuration without breaking existing builds or requiring immediate project file modifications.
**Prevention:** Always use `Bundle.main.object(forInfoDictionaryKey:)` for configuration, backed by `.xcconfig` files that are git-ignored, ensuring secrets are never committed.
