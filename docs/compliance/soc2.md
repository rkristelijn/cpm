# SOC 2 — Trust Services Criteria

| Criteria | Requirement | cpm check | Evidence |
|----------|-------------|-----------|----------|
| CC1.2 | Security policies | SECURITY.md (cpm init) | Generated on init |
| CC3.2 | Risk identification | check-sast, check-outdated | Automated scanning |
| CC6.1 | Logical access controls | check-secrets-fast | No hardcoded credentials |
| CC6.5 | Data protection | check-pii | PII detection + vault |
| CC7.1 | System monitoring | gitleaks pre-commit | Real-time secret scanning |
| CC7.2 | Anomaly detection | check-regex-safety | ReDoS patterns |
| CC8.1 | Change management | cpm hooks + enforcement | Quality gates per commit |
| A1.2 | Recovery mechanisms | check-sbom, paranoia-backup | SBOM + encrypted backups |
