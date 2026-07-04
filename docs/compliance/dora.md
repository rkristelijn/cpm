# DORA — Digital Operational Resilience Act (EU 2022/2554)

| Article | Requirement | cpm check | Evidence |
|---------|-------------|-----------|----------|
| Art. 6 | ICT risk management framework | cpm maturity scoring | Quantified quality level |
| Art. 7 | ICT systems, protocols and tools | check-runtime-eol, check-runtime-eol | No EOL dependencies |
| Art. 8 | Identification of ICT risks | check-sast, check-secrets-fast | Automated vulnerability detection |
| Art. 9 | Protection and prevention | global-hooks (pre-commit) | Shift-left prevention |
| Art. 10 | Detection | check-pii, gitleaks | Real-time scanning on commit |
| Art. 11 | Response and recovery | check-sbom | SBOM for incident response |
| Art. 12 | ICT change management | cpm hooks + enforcement levels | Change validation at commit/push |
| Art. 16 | ICT third-party risk | check-lockfile, check-runtime-eol | Supply chain monitoring |
