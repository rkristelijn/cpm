---
title: no-pii-literals: detect hardcoded names, addresses, emails in code via per-repo wordlist
type: feat
created: 2026-08-31T14:23:10+00:00
labels: [feat, hooks, pii]
remote:
---

## What

A new pre-commit check (`no-pii-literals`) that scans staged diffs for hardcoded PII literals from a per-repo wordlist. Unlike `no-pii` (which uses regex patterns to catch structured data like BSNs, IBANs, SSNs), this check uses **exact string matching** against a curated list of known PII values specific to the project.

### Config

Per-repo wordlist at `.config/pii-literals.txt`, one entry per line:

```text
# Real names (team members, clients, test data leaks)
Jan de Vries
Mohammed Al-Rashid
Sarah Johnson

# Email addresses
jan.devries@company.nl
sarah.johnson@client.com

# Physical addresses
Keizersgracht 555, 1017DR Amsterdam
221B Baker Street, London

# Phone numbers (exact, not regex)
+31612345678
+442079460958
```

Lines starting with `#` are comments. Empty lines are ignored. Matching is case-insensitive.

### Integration with PII vault

The check also reads patterns from the central PII vault (`~/.local/share/pii/patterns.d/`). Vault `.pii` files contain regex patterns; this check's `.config/pii-literals.txt` contains exact strings. Both sources are checked:

1. `.config/pii-literals.txt` → exact (case-insensitive) string match
2. `~/.local/share/pii/patterns.d/*.pii` → regex match (existing vault integration)

### How it differs from `no-pii`

| | `no-pii` | `no-pii-literals` |
|---|----------|-------------------|
| **Method** | Regex patterns | Exact string matching |
| **Scope** | Universal (BSN, IBAN, SSN, etc.) | Per-repo wordlist |
| **False positives** | Higher (patterns are broad) | Lower (exact match) |
| **Catches** | Structured data formats | Actual names, addresses, emails |
| **Config** | `.config/.pii-config` | `.config/pii-literals.txt` |

### Example wordlist entries

- Real names of team members, clients, or test subjects
- Email addresses (personal or work)
- Physical addresses (offices, homes, test data)
- Phone numbers in exact format
- Any other string that constitutes PII in the project's context

## Why

Regex-based PII detection (`no-pii`) catches structured formats but misses actual names like "Jan de Vries" or addresses like "Keizersgracht 555". These are the most common PII leaks in test data, seed scripts, and documentation. A wordlist approach catches what regex cannot.

## Value

- Quality characteristic: Security
- Stakeholder benefit: Prevents GDPR violations from hardcoded PII in test data, config, and docs

## Acceptance criteria

- [ ] AC1: `no-pii-literals` check exists as a lib script in global hooks → test: `test_e2e_hook_pii_literals_exists`
- [ ] AC2: Check reads from `.config/pii-literals.txt` and flags exact matches in staged diffs → test: `test_e2e_hook_pii_literals_wordlist`
- [ ] AC3: Check integrates with PII vault (`~/.local/share/pii/patterns.d/`) → test: `test_e2e_hook_pii_literals_vault`
- [ ] AC4: `cpm:ignore pii-literal` suppresses on individual lines → test: `test_e2e_hook_pii_literals_suppress`
- [ ] AC5: Check is independently toggleable via hooks.conf and cpm.toml → test: `test_e2e_hook_pii_literals_toggle`
- [ ] AC6: Empty or missing wordlist = skip gracefully (exit 0) → test: `test_e2e_hook_pii_literals_no_wordlist`

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (hook-no-pii-literals.md created)
- [ ] Added to ALL_CHECKS, hooks.conf template, orchestrator, and health check

## References

- @see hook-no-pii.md (existing regex-based PII check)
- @see pii-vault.md (central PII vault design)
