---
summary: Attack surface exposure checks based on Intruder 2026 ASM Index — exposed databases, admin panels, risky ports, public files.
status: implemented
---

# ADR-149: Attack Surface Exposure Checks

## Context

The 2026 Attack Surface Management Index (Intruder, published 17 June 2026, via The Hacker News) analysed 3,000 attack surfaces and found:

- 60% of organisations had at least one exposed HTTP admin panel
- 49% had a risky port or service exposed
- 42% had a database reachable directly from the internet
- 30% had files or information publicly accessible that shouldn't be

### Top 10 exposures (2026)

| # | Exposure | % affected |
|---|----------|-----------|
| 1 | MySQL Database Exposed | 26% |
| 2 | Postgres Database Exposed | 16% |
| 3 | API Documentation Exposed | 15% |
| 4 | WordPress Admin Panel Exposed | 15% |
| 5 | Remote Desktop Service Exposed | 11% |
| 6 | SNMP Service Exposed | 9% |
| 7 | phpMyAdmin Admin Panel Exposed | 8% |
| 8 | UPnP Service Exposed | 8% |
| 9 | NTP Service Exposed | 7% |
| 10 | RPC Portmapper Service Exposed | 7% |

### What cpm already covers (partial)

- `checks/universal/check-secrets.sh` — leaked credentials in code (gitleaks)
- `checks/javascript/check-env-files.sh` — exposed .env files
- `checks/universal/check-gitignore.sh` — sensitive files not ignored
- Docker/compose checks — port exposure in docker-compose.yml

### Gaps in cpm

cpm currently does **not** check for:

1. **Database port exposure** in Docker/compose/Kubernetes configs (3306, 5432, 27017, 6379 bound to 0.0.0.0)
2. **Admin panel exposure** — config files that expose admin routes without auth (Django admin, phpMyAdmin, WordPress wp-admin without IP restriction)
3. **API documentation exposure** — Swagger/OpenAPI docs served in production without auth
4. **Risky service ports** in Docker/Kubernetes (RDP 3389, SNMP 161, NTP 123, RPC 111, UPnP 1900)
5. **Public file exposure** — index listings enabled, `.git` directory served, backup files (.sql, .bak) in webroot

## Decision

Add attack surface exposure checks as a new check category: `checks/universal/attack-surface/`.

## Proposed checks

```text
checks/universal/attack-surface/
├── check-database-exposure.sh        # Ports 3306/5432/27017/6379 bound to 0.0.0.0
├── check-admin-panel-exposure.sh     # Admin routes without IP/auth restriction
├── check-api-docs-exposure.sh        # Swagger/OpenAPI served in prod configs
├── check-risky-ports.sh              # RDP/SNMP/NTP/RPC/UPnP in Docker/K8s
└── check-public-files.sh             # .git, .sql, .bak, directory listing configs
```

### Detection approach

| Check | Where to look | Signal |
|-------|--------------|--------|
| Database exposure | `docker-compose.yml`, `kubernetes/*.yaml`, Dockerfile | `ports: "0.0.0.0:3306:3306"` or `hostPort: 3306` |
| Admin panel | Django `urls.py`, Laravel `routes/`, nginx/apache conf | Admin routes without IP allowlist or middleware |
| API docs | OpenAPI/Swagger config, Spring/FastAPI/Express routes | Swagger UI enabled without `production: false` gate |
| Risky ports | Docker/K8s manifests | Ports 3389, 161, 123, 111, 1900 exposed externally |
| Public files | `.htaccess`, nginx conf, Dockerfile COPY | `autoindex on`, COPY of `.git` or `*.sql` into webroot |

### Enforcement level

- **learn**: informational findings (non-blocking)
- **guide**: warning before push
- **guard**: block push if HIGH severity (database/RDP exposure)
- **enforce**: block commit

Default: `guide` — warn developers about potential attack surface before they ship.

## Consequences

### Positive

- Catches infrastructure misconfigurations at code level, before deployment
- Aligns with real-world attack patterns (Intruder 2026 data)
- Complements existing secrets/env-file checks
- Supports "shift-left" approach to attack surface management

### Negative

- May produce false positives for intentional dev-environment port bindings
- Needs allowlist mechanism for known-safe configurations (e.g., `# cpm:allow database-exposure reason="dev-only"`)

### Future

- Integration with `scripts/discover/` for runtime validation (actually probe ports)
- Correlation with Docker/K8s labels (`environment: production` vs `development`)
- Report output as attack surface score component

## References

- [The Top 10 Attack Surface Exposures in 2026](https://thehackernews.com/) — Intruder / The Hacker News, 17 June 2026
- [Intruder 2026 Attack Surface Management Index](https://www.intruder.io/) — full report
- OWASP ASVS v4.0 — Architecture, Design and Threat Modeling Requirements
- CIS Benchmarks — Docker, Kubernetes
