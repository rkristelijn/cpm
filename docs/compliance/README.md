# Compliance Matrix

Automated compliance verification for cpm. Each framework has:
- **Requirements**: what the standard demands
- **Evidence**: which cpm check satisfies it
- **Verification**: script output proving compliance

## Status

Run `cpm compliance` or `bash scripts/verify-compliance.sh` to check.

| Framework | Controls mapped | Covered | Gaps | Status |
|-----------|----------------|---------|------|--------|
| [ISO 27001](iso-27001.md) | 14 | — | — | 🔄 |
| [OWASP Top 10](owasp-top10.md) | 10 | — | — | 🔄 |
| [GDPR](gdpr.md) | 6 | — | — | 🔄 |
| [DORA](dora.md) | 8 | — | — | 🔄 |
| [NIST 800-53](nist-800-53.md) | 10 | — | — | 🔄 |
| [NIS2](nis2.md) | 7 | — | — | 🔄 |
| [WCAG 2.1](wcag.md) | 4 | — | — | 🔄 |
| [SOC 2](soc2.md) | 8 | — | — | 🔄 |
| [PCI DSS](pci-dss.md) | 5 | — | — | 🔄 |
| [CMMI](cmmi.md) | 5 | — | — | 🔄 |
| [CE+](ce-plus.md) | 4 | — | — | 🔄 |

🔄 = awaiting automated verification
