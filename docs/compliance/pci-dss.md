# PCI DSS v4.0 — Payment Card Industry Data Security Standard

| Requirement | Description | cpm check | Evidence |
|-------------|-------------|-----------|----------|
| 6.2.3 | Code review before release | cpm check (pre-push) | Automated quality gate |
| 6.2.4 | Protection against common attacks | check-sast, check-dangerous-shell | Injection prevention |
| 6.3.1 | Identify security vulnerabilities | check-outdated, check-sast | Dependency + code scanning |
| 6.3.2 | Software inventory | check-sbom | SBOM generation |
| 8.3.6 | No hardcoded passwords | check-secrets-fast, gitleaks | Secret detection |
