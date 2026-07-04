# GDPR — General Data Protection Regulation

| Article | Requirement | cpm check | Evidence |
|---------|-------------|-----------|----------|
| Art. 5(1)(f) | Integrity and confidentiality | check-pii + check-secrets-fast | PII detection + secrets scanning |
| Art. 25 | Data protection by design | pii-vault | Centralized PII outside repos |
| Art. 30 | Records of processing | check-pii (--staged) | Prevents PII in commits |
| Art. 32 | Security of processing | global-hooks (gitleaks+semgrep) | Automated security gates |
| Art. 33 | Breach notification | check-pii warning | Warns when PII found in code |
| Art. 35 | Data protection impact assessment | paranoia-mode | Encrypted storage for sensitive data |
