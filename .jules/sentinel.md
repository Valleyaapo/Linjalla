# Sentinel's Journal - Critical Security Learnings

## 2026-01-01 - GraphQL Injection via String Interpolation
**Vulnerability:** A GraphQL Injection vulnerability was identified where user-controlled input (`transportMode`) was directly interpolated into a GraphQL query string (`routes(..., transportModes: [\(transportMode)])`).
**Learning:** Even internal-looking APIs can be vulnerable if they construct queries using string interpolation instead of parameterized variables. The assumption that input like `transportMode` is always "safe" or hardcoded is fragile.
**Prevention:** Always use GraphQL variables (`$variable`) for all dynamic inputs. If string interpolation is unavoidable (e.g. for schema structural changes, though highly discouraged), strictly whitelist the input characters using `CharacterSet` validation before construction.
