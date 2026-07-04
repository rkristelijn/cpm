# NIS2 — Network and Information Security Directive (EU 2022/2555)

| Article | Requirement | cpm check | Evidence |
|---------|-------------|-----------|----------|
| Art. 21(2)(a) | Risk analysis and policies | cpm maturity + enforcement | Quantified posture |
| Art. 21(2)(b) | Incident handling | check-sbom | SBOM for rapid triage |
| Art. 21(2)(d) | Supply chain security | check-lockfile, check-runtime-eol | Dependency monitoring |
| Art. 21(2)(e) | Security in development | check-sast, global-hooks | Shift-left security |
| Art. 21(2)(g) | Cyber hygiene practices | cpm check (full suite) | 136 automated checks |
| Art. 21(2)(h) | Cryptography | check-secrets-fast, paranoia-mode | No plaintext secrets |
| Art. 21(2)(i) | Access control | check-pii, pii-vault | PII separation |
