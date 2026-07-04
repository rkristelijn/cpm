# ADR-142: OWASP Top 10 Coverage Analysis

*Status*: Draft · *Date*: 2026-05-20 · *Author*: kiro

## Context

OWASP Top 10 is the industry standard for web application security risks. The 2025 edition is the latest. cpm should cover as many categories as possible through static analysis.

## OWASP Top 10 (2025) vs cpm Coverage

| # | Category (2025) | cpm coverage | How | Gap |
|---|----------------|-------------|-----|-----|
| A01 | **Broken Access Control** | Partial | semgrep rules, SSRF patterns | Missing: path traversal patterns, IDOR detection |
| A02 | **Security Misconfiguration** | Good | Framework misuse checks (Next.js headers, debug mode), .env detection | Missing: CORS misconfig, default credentials |
| A03 | **Software Supply Chain Failures** | Good | audit checks (all langs), lockfile, unpinned-deps, pinned-actions, EOL | Missing: typosquatting, maintainer takeover |
| A04 | **Cryptographic Failures** | Partial | semgrep (weak crypto), native secrets detection | Missing: weak TLS config, insufficient key length |
| A05 | **Injection** | Good | semgrep (SQL injection, XSS, command injection), eval() detection | Missing: template injection, LDAP injection |
| A06 | **Insecure Design** | Partial | Architecture checks (complexity, coupling, fan-out) | Missing: threat modeling validation |
| A07 | **Authentication Failures** | Minimal | Hardcoded secrets, no-security-policy | Missing: session management, password policy |
| A08 | **Data Integrity Failures** | Good | Lockfile integrity, pinned actions, SBOM | Missing: CI/CD pipeline integrity |
| A09 | **Logging & Alerting Failures** | Minimal | — | Missing: logging presence check, PII in logs |
| A10 | **Mishandling Exceptional Conditions** | Minimal | — | Missing: empty catch blocks, swallowed errors |

## OWASP Top 10 (2021) — Additional Categories

| Category (2021) | Status in 2025 | cpm coverage |
|----------------|---------------|-------------|
| Vulnerable & Outdated Components | → Supply Chain (A03) | ✅ Covered |
| SSRF | → Broken Access Control (A01) | Partial (semgrep) |

## Coverage Score

- **Well covered (native + tools)**: A03, A05, A08 = 3/10
- **Partially covered**: A01, A02, A04, A06 = 4/10
- **Minimal/missing**: A07, A09, A10 = 3/10

## Current OWASP coverage: ~55%

## Decision: Native Checks to Add

### A01: Broken Access Control

```text
- Path traversal: detect `../` in file operations without sanitization
- IDOR: detect direct DB ID usage in routes without auth middleware
- CORS: detect `Access-Control-Allow-Origin: *` in config
```

### A02: Security Misconfiguration

```text
- DEBUG=True / APP_DEBUG=true in non-test files
- Default credentials (admin/admin, root/root patterns)
- CORS wildcard in production configs
- Exposed actuator/admin endpoints
```

### A04: Cryptographic Failures

```text
- MD5/SHA1 usage for security purposes
- Hardcoded encryption keys
- HTTP URLs in production config (not HTTPS)
```

### A07: Authentication Failures

```text
- No auth middleware in route definitions
- Session timeout not configured
- No rate limiting on auth endpoints
```

### A09: Logging & Alerting Failures

```text
- No logging framework detected
- PII in log statements (email, SSN patterns in log calls)
- Empty catch blocks (swallowed errors)
```

### A10: Mishandling Exceptional Conditions

```text
- Empty catch/except blocks
- Generic catch-all without logging
- process.exit() / os.exit() without cleanup
```

## Implementation Priority

| Check | OWASP | Effort | Impact |
|-------|-------|--------|--------|
| Empty catch blocks | A10 | Low | High (universal) |
| DEBUG=True detection | A02 | Low | High |
| CORS wildcard | A02 | Low | Medium |
| MD5/SHA1 for security | A04 | Low | Medium |
| PII in logs | A09 | Medium | High |
| Path traversal patterns | A01 | Medium | High |
| No auth middleware | A07 | High | Medium (framework-specific) |

## Consequences

- Add ~10 native checks targeting OWASP gaps
- Target: 80% OWASP coverage (8/10 categories well-covered)
- All checks work via pattern matching (no runtime needed)
- Framework-specific checks expand over time
