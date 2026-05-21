# ADR-140: Compliance Framework Mapping

*Status*: Draft · *Date*: 2026-05-20 · *Author*: kiro

## Context

cpm checks cover security, quality, accessibility, and process concerns. To position cpm as a compliance springboard, each check should map to one or more industry frameworks so organizations can demonstrate coverage.

## Frameworks

| Framework | Domain | Key for |
|-----------|--------|---------|
| ISO 27001 | Information security | Annex A controls |
| ISO 9126 / 25010 | Software quality | Quality characteristics |
| GDPR | Data protection | PII handling |
| CMMI | Process maturity | Maturity levels |
| OWASP Top 10 | Application security | Vulnerability categories |
| WCAG 2.1 | Accessibility | A/AA/AAA conformance |
| SOC 2 | Trust services | Security, availability, confidentiality |
| PCI DSS | Payment security | Cardholder data protection |

## Decision

Add a `compliance` field to each check's finding output, mapping to relevant framework controls.

## Mapping

### Security checks → ISO 27001 + OWASP + SOC 2

| cpm check | Rule | ISO 27001 | OWASP | SOC 2 |
|-----------|------|-----------|-------|-------|
| secrets | env-committed | A.9.4.3 | A3:Injection | CC6.1 |
| secrets | hardcoded-secret | A.9.4.3 | A3:Injection | CC6.1 |
| security | eval | A.14.2.5 | A3:Injection | CC7.1 |
| pii | pii-detected | A.18.1.4 | — | CC6.5 |
| no-security-policy | — | A.6.1.1 | — | CC1.2 |
| gitlab-ci/hardcoded-secret | — | A.9.2.3 | A7:Auth Failure | CC6.1 |

### Quality checks → ISO 9126/25010 + CMMI

| cpm check | Rule | ISO 25010 | CMMI |
|-----------|------|-----------|------|
| complexity | high-complexity | Maintainability | ML3 |
| comments | low-comment-ratio | Maintainability | ML3 |
| testing | no-tests | Reliability | ML2 |
| dead-code | unused-export | Maintainability | ML3 |
| filesize | large-file | Maintainability | ML2 |
| mock-boundary | mock-boundary-violation | Testability | ML3 |
| antipattern | * | Maintainability | ML3 |

### Process checks → CMMI + ISO 27001

| cpm check | Rule | CMMI | ISO 27001 |
|-----------|------|------|-----------|
| devops | no-ci-pipeline | ML2 | A.14.2.8 |
| devops | no-build-system | ML2 | — |
| devops | no-gitignore | ML1 | — |
| standards | no-editorconfig | ML2 | — |
| standards | no-security-policy | ML2 | A.6.1.1 |
| standards | no-issue-templates | ML3 | — |
| standards | no-pr-template | ML3 | — |
| git-health | lottery-factor-1 | ML2 | A.7.2.2 |
| git-health | high-churn | ML3 | — |
| freshness | stale-repo | ML1 | A.12.6.1 |

### Accessibility checks → WCAG 2.1

| cpm check | Rule | WCAG | Level |
|-----------|------|------|-------|
| a11y | missing-alt | 1.1.1 | A |
| a11y | missing-label | 1.3.1 | A |
| a11y | low-contrast | 1.4.3 | AA |
| a11y | no-focus-visible | 2.4.7 | AA |
| a11y | no-aria-role | 4.1.2 | A |
| a11y | no-lang-attr | 3.1.1 | A |

### Data protection → GDPR

| cpm check | Rule | GDPR Article |
|-----------|------|-------------|
| pii | pii-detected | Art. 25 (data protection by design) |
| pii | pii-in-logs | Art. 5(1)(c) (data minimization) |
| secrets | env-committed | Art. 32 (security of processing) |
| no-security-policy | — | Art. 33 (breach notification) |

### Inclusivity → WCAG + ISO 25010

| cpm check | Rule | Framework |
|-----------|------|-----------|
| inclusivity | non-inclusive-term (error) | WCAG 3.1.4, ISO 25010 Usability |
| inclusivity | non-inclusive-term (warning) | ISO 25010 Usability |
| inclusivity | non-inclusive-term (info) | Best practice |

### Community/Docs → CMMI + ISO 25010

| cpm check | Rule | CMMI | ISO 25010 |
|-----------|------|------|-----------|
| community | missing-license | ML1 | — |
| community | missing-readme | ML1 | Usability |
| readme-audit | low-readme-score | ML2 | Usability |
| ai-ready | no-contributing | ML2 | Maintainability |
| ai-ready | no-agent-config | ML3 | Maintainability |

## Implementation

Add compliance tags to `finding_write()`:

```cpp
finding_write(name, "security", "error", ".env", "env-committed",
              "...", "ISO27001:A.9.4.3,OWASP:A3,SOC2:CC6.1");
```

And expose via `cpm findings --compliance`:

```text
$ cpm findings --compliance iso27001
  error  .env  env-committed  A.9.4.3  .env tracked in git
  warn   .     no-security    A.6.1.1  No SECURITY.md
```

## Consequences

- Every finding carries compliance metadata
- `cpm findings --compliance <framework>` filters by framework
- `cpm report --compliance` generates compliance coverage report
- Organizations can use cpm output as evidence for audits
- Maturity levels align with CMMI (ML1-5)
