# PII Vault — Centralized PII Pattern Management

> **Standards**: NIST SP 800-122, ISO 27001 A.8.12/A.8.31, ISO 27701 §7.4.5

## Problem

PII detection patterns (colleague names, internal domains, AWS account IDs, etc.) are
sensitive data themselves. Storing them inside git repositories creates:

1. **Duplication** — Same patterns copy-pasted across repos
2. **Drift** — Repos go out of sync when patterns change
3. **Exposure risk** — One misconfigured `.gitignore` and PII is public
4. **Violation** — NIST SP 800-122 mandates data minimization and separation

## Solution: Central PII Vault

```
~/.local/share/pii/              ← chmod 700, out-of-repo
├── README.md
└── patterns.d/                  ← chmod 700
    ├── work-<org>.pii           ← Organization-specific (chmod 600)
    ├── personal.pii             ← Personal identifiers (chmod 600)
    └── generic.pii              ← API keys, IPs, etc. (chmod 600)
```

### Why this location?

| Requirement | Solution |
|---|---|
| Never in git | `~/.local/share/` is never inside a repo |
| XDG compliance | Follows XDG Base Directory Specification |
| Single source | One location, all repos read from it |
| Access control | 700/600 permissions, owner-only |
| Optional encryption | GPG or macOS Keychain can wrap the directory |

## Setup

```bash
cpm setup-pii-vault              # Interactive setup
cpm setup-pii-vault --check      # Verify vault health
cpm setup-pii-vault --migrate .  # Migrate current repo's .pii to vault
```

## How check-pii.sh resolves patterns

Priority order:

1. `$PII_FILE` (env var override for CI/testing)
2. `$PII_VAULT/patterns.d/*.pii` (default: `~/.local/share/pii`)
3. `.config/.pii` in repo (fallback — **deprecated**, emits warning)

### Warning on local .pii files

If a physical `.config/.pii` or `.pii` file exists in the repo with >3 patterns,
check-pii.sh emits:

```
⚠ [pii] WARNING: .config/.pii contains 247 PII patterns
  PII data should NOT live inside repositories (NIST SP 800-122, ISO 27001 A.8.12)
  Run: cpm setup-pii-vault (or move manually to ~/.local/share/pii/patterns.d/)
```

## Pattern file format

```bash
# Lines starting with # are comments
# One grep-E compatible regex per line

# Organization domains
theapsgroup\.com
gitlab\.internal\.example\.com

# Colleague names
John Smith
jane\.doe@

# Infrastructure
SERVERNAME-[0-9]+
10\.0\.0\.[0-9]+

# Financial
NL[0-9]{2}\s?[A-Z]{4}\s?[0-9]{10}
```

## Comparison: check-pii vs gitleaks

These tools have **complementary** goals, not overlapping ones:

| Aspect | gitleaks | check-pii (cpm) |
|---|---|---|
| **Purpose** | Detect **secrets** (keys, tokens, passwords) | Detect **PII & org-specific data** (names, domains, internal refs) |
| **Pattern source** | 100+ built-in rules for known secret formats | **Your own** custom patterns (names, domains, IPs) |
| **What it finds** | `AKIA...`, `ghp_...`, `sk-...`, passwords | "Marco Schriek", "gitlab.internal.com", AWS account IDs |
| **Detection method** | Regex + entropy + keyword anchors | Plain grep -E against custom pattern list |
| **Config** | `.gitleaks.toml` (in repo, safe — contains regex only) | Central vault (out-of-repo — contains actual PII data) |
| **Scope** | Universal — works for any project | Personal/organizational — your specific PII |
| **False positives** | Low (entropy-checked, allowlists) | Higher (simple grep, needs `.piiignore`) |
| **Git history** | Scans full git history | Scans working tree or staged changes only |
| **Speed** | Very fast (Go binary, parallel) | Fast enough for hooks (bash, single-pass) |

### Where they overlap

Only in generic regex patterns like API keys:

| Pattern | gitleaks | check-pii |
|---|---|---|
| AWS Access Key (`AKIA...`) | ✅ Built-in | ⚠️ Optional in generic.pii |
| GitHub PAT (`ghp_...`) | ✅ Built-in | ⚠️ Optional in generic.pii |
| Generic passwords | ✅ Built-in + entropy | ❌ Not designed for this |
| Colleague names | ❌ Cannot do this | ✅ Primary purpose |
| Internal domains | ❌ Not aware of your org | ✅ Primary purpose |
| AWS Account IDs | ❌ (not secrets per se) | ✅ Detects context leaks |
| Client names | ❌ | ✅ |
| Internal hostnames | ❌ | ✅ |

### Recommendation: Minimize overlap

Remove generic API key patterns from your `generic.pii` if gitleaks is active in
the same pipeline. Keep check-pii focused on what gitleaks **cannot** do:

```bash
# generic.pii — only keep patterns gitleaks doesn't cover
# REMOVE these (gitleaks handles them better):
# AKIA[0-9A-Z]{16}
# ghp_[a-zA-Z0-9]{36}
# sk-[a-zA-Z0-9]{48}

# KEEP these (gitleaks doesn't know about your infra):
10\.0\.0\.[0-9]+
friday\.local
NL[0-9]{2}[A-Z]{4}[0-9]{10}
```

### Decision matrix

| Scenario | Use |
|---|---|
| Detect leaked API keys/tokens | **gitleaks** |
| Detect colleague names in code | **check-pii** |
| Detect internal domains/URLs | **check-pii** |
| Detect hardcoded passwords | **gitleaks** |
| Detect BSN/IBAN in staged code | **check-pii** (--staged) |
| Scan git history for old leaks | **gitleaks** |
| Scan working tree for org references | **check-pii** |

## Standards Reference

### NIST SP 800-122 — Guide to Protecting PII

- **§4.1 Data Minimization**: Limit PII to what is directly relevant and necessary
- **§4.2 Access Control**: Restrict access to PII based on need-to-know
- **§4.3 Encryption**: Encrypt PII at rest when feasible
- **§4.4 Separation**: Store PII separately from application logic

### ISO 27001:2022

- **A.8.12 Data Leakage Prevention**: Prevent unauthorized disclosure of sensitive data
- **A.8.31 Separation of Environments**: Don't mix PII with dev/test environments
- **A.5.33 Protection of Records**: Protect records from loss, destruction, falsification

### ISO 27701:2025

- **§7.4.5 PII Minimization**: Only retain what is strictly necessary
- **§7.4.9 Collection Limitation**: Minimize copies and collection points

## Migration checklist

- [ ] Run `cpm setup-pii-vault` to create the vault
- [ ] Run `cpm setup-pii-vault --migrate` in each repo with a `.config/.pii`
- [ ] Verify: `cpm setup-pii-vault --check`
- [ ] Remove `.config/.pii` from repos (or reduce to <3 patterns)
- [ ] Update `.gitignore` (keep `.config/.pii` ignored as safety net)
- [ ] Confirm check-pii still works: `cpm check pii`
- [ ] (Optional) Remove API key patterns from `generic.pii` if gitleaks is active

## Future: Encrypted vault mount

**Status**: Planned (not yet implemented)

For environments where OS admins have root/sudo access (MDM-managed machines),
the vault can be wrapped in an encrypted disk image:

```bash
# Create encrypted sparse image
hdiutil create -size 10m -encryption AES-256 -type SPARSE \
  -fs APFS -volname "pii-vault" ~/.local/share/pii-vault.sparseimage

# Mount (at login)
hdiutil attach ~/.local/share/pii-vault.sparseimage -mountpoint ~/.local/share/pii

# Unmount (at screen lock / logout)
hdiutil detach ~/.local/share/pii
```

This ensures patterns are unreadable when the session is locked, even for root.
Trade-off: requires password entry on mount (or Keychain-stored passphrase).
