# OWASP Top 10 (2021)

| # | Category | cpm check | Evidence |
|---|----------|-----------|----------|
| A01 | Broken Access Control | check-strapi (public role) | Detects overly broad permissions |
| A02 | Cryptographic Failures | check-secrets-fast | Detects hardcoded secrets, weak crypto |
| A03 | Injection | check-dangerous-shell, check-sast | SQL injection, command injection |
| A04 | Insecure Design | check-sonar-shift-left | Deep nesting, complexity |
| A05 | Security Misconfiguration | check-gitignore, check-strapi | Env files exposed, debug mode |
| A06 | Vulnerable Components | check-runtime-eol, check-version-pins | Outdated dependencies flagged |
| A07 | Auth Failures | check-strapi (JWT), check-django-security | JWT expiry, auth config |
| A08 | Software/Data Integrity | check-lockfile, check-sbom | Lockfile integrity, SBOM |
| A09 | Logging/Monitoring Failures | check-sast | Missing error handling |
| A10 | Server-Side Request Forgery | check-sast (semgrep) | SSRF patterns |
