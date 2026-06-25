# PII Detection

Prevents accidental commits of personally identifiable information (PII) like emails, hostnames, IP addresses, and private paths.

## Usage

```bash
# Full scan (source directories)
bash checks/universal/security/check-pii.sh

# Staged changes only (pre-commit hook mode)
bash checks/universal/security/check-pii.sh --staged
```

## Modes

| Mode | When | What it scans | Patterns |
|------|------|---------------|----------|
| Full | `cpm check` | `src/`, `lib/`, `checks/`, `docs/` | `.config/.pii` (custom) |
| Staged | `cpm check --fast` / pre-commit | Only added lines in `git diff --cached` | Built-in (BSN, IBAN, phone) |

## How it works

```text
Full:    cpm check → reads .config/.pii → scans source files → reports file:line matches
Staged:  git commit → hook → reads staged diff → scans added lines → reports file:line matches
```

## Output format

Findings use clickable `file:line` references (works in VSCode, iTerm2, Warp, and other terminals):

```text
⚠ pii: src/config.yaml:42  pattern '\b\+31[0-9]{9}\b'
   phone: "+31612345678"
   suppress: add 'cpm:ignore pii' to the line
```

Click the `file:line` reference to jump directly to the issue.

## Suppressing findings

### Inline (per line)

Add `cpm:ignore pii` as a comment on the line:

```python
bsn = "REDACTED"  # cpm:ignore pii  
```

```markdown
**Zaak**: AK-226000123 <!-- cpm:ignore pii -->
```

```yaml
account_id: "123456789"  # cpm:ignore pii
```

### File-level (.piiignore)

Add to `.config/.piiignore` for broader suppressions:

```bash
# Format: file:pattern (ignore in specific file)
docs/adrs/adr-094.md:R. Kristelijn

# Ignore a pattern everywhere:
*:example-internal-host
```

## Setup (full scan mode)

```bash
# First run creates the template automatically:
bash checks/universal/security/check-pii.sh

# Or create manually:
mkdir -p .config
cat > .config/.pii << 'EOF'
# One pattern per line (exact match, case-sensitive)
john.doe@company.com
192.168.1.100
my-secret-hostname
~/git/work/
EOF
```

## Staged mode — built-in patterns

The `--staged` mode uses hardcoded patterns for common Dutch/international PII:

| Pattern | Detects |
|---------|---------|
| `\b[0-9]{9}\b` | BSN (9 digits) |
| `\b[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}...` | IBAN |
| `\b06[0-9]{8}\b` | NL mobile phone |
| `\b\+31[0-9]{9}\b` | NL international phone |

## Pre-commit hook integration

The staged mode is designed for pre-commit hooks. In your global hooks:

```bash
# In hooks/lib/pii.sh or .git/hooks/pre-commit:
bash checks/universal/security/check-pii.sh --staged
```

Or via cpm's hook system:

```toml
# cpm.toml
[hooks]
pre-commit = true  # runs cpm check --fast (includes pii --staged)
```

## Performance

- **Full scan**: reads all source files (use in CI or `cpm check`)
- **Staged mode**: single `git diff --cached` + one `awk` pass + one `grep` per pattern — fast enough for every commit

## What gets scanned (full mode)

**File types**: `*.cpp`, `*.h`, `*.hpp`, `*.sh`, `*.md`, `*.toml`, `*.json`, `*.yml`, `*.yaml`

**Directories**: `src/`, `lib/`, `checks/`, `docs/`

## Files

| File | Committed | Purpose |
|------|-----------|---------|
| `.config/.pii` | No (gitignored) | Your PII patterns (full mode) |
| `.config/.piiignore` | No (gitignored) | False positive suppressions |

## Recommended placeholders

| Instead of | Use |
|-----------|-----|
| Real email | `user@example.com` |
| Real IP | `192.0.2.1` (TEST-NET-1) |
| Real hostname | `<hostname>` or `example.com` |
| Private path | `~/projects/my-app` |
| Real name | initials or `<author>` |
| BSN/IBAN | `<bsn>` or `<iban>` |

## Related

- [secrets.md](secrets.md) — secret detection (API keys, tokens)
- [hooks.md](hooks.md) — pre-commit hook setup
