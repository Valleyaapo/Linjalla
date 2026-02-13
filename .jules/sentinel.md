## 2026-01-04 - GraphQL Injection Mitigation via Strong Typing
**Vulnerability:** The `DigitransitService` constructed GraphQL queries by interpolating a raw String parameter (`transportMode`) directly into the query template. While currently used with hardcoded internal values, the public API surface allowed for potential injection if called with user input.
**Learning:** GraphQL queries constructed via string interpolation are susceptible to injection attacks similar to SQL injection. Relying on "known good callers" is fragile.
**Prevention:** Use Enums for finite sets of values (like transport modes) to enforce type safety and ensure only valid tokens are interpolated. For variable data, always use GraphQL variables (`$variable`).

## 2026-01-05 - Secure Configuration via Build Injection
**Vulnerability:** `Secrets.swift` contained hardcoded MQTT configuration (host, port, username) and was tracked in git, creating a risk of accidental exposure or misuse if developers modified it with sensitive data. The project lacked a standard mechanism for injecting non-secret configuration securely.
**Learning:** Hardcoding "public" configuration in source files encourages developers to add "private" configuration (like passwords) in the same place. Tracked source files should never contain configuration values that might vary by environment or be sensitive.
**Prevention:** Use `xcconfig` files (git-ignored) to inject configuration into `Info.plist` via build settings. Swift code should then read from `Info.plist`, treating it as the single source of truth. This separates code (tracked) from configuration (untracked/environment-specific).
