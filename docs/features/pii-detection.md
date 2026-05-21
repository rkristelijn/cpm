# PII Detection

Prevents accidental commits of personally identifiable information (PII) like emails, hostnames, IP addresses, and private paths.

## Usage

```bash
bash checks/universal/security/check-pii.sh
```

## How it works

Each developer maintains a local `.config/.pii` file with patterns to scan for. This file is gitignored — your patterns never leave your machine.

```text
cpm check → reads .config/.pii → scans source files → reports matches
```

## Setup

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

## Ignoring false positives (.piiignore)

When a finding is not real PII, add it to `.config/.piiignore`:

```bash
# Format: file:pattern (ignore in specific file)
docs/adrs/adr-094.md:R. Kristelijn

# Ignore a pattern everywhere:
*:example-internal-host
```

The check output shows the exact command to add an ignore entry:

```text
  [pii] FOUND: R. Kristelijn
    docs/adrs/adr-094.md:9:deciders: R. Kristelijn
    ignore: echo 'docs/adrs/adr-094.md:R. Kristelijn' >> .config/.piiignore
```

## What gets scanned

**File types**: `*.cpp`, `*.h`, `*.hpp`, `*.sh`, `*.md`, `*.toml`, `*.json`, `*.yml`, `*.yaml`

**Directories**: `src/`, `lib/`, `checks/`, `docs/`

## Files

| File | Committed | Purpose |
|------|-----------|---------|
| `.config/.pii` | No (gitignored) | Your PII patterns |
| `.config/.piiignore` | No (gitignored) | False positive suppressions |

## Recommended placeholders

| Instead of | Use |
|-----------|-----|
| Real email | `user@example.com` |
| Real IP | `192.0.2.1` (TEST-NET-1) |
| Real hostname | `<hostname>` or `example.com` |
| Private path | `~/projects/my-app` |
| Real name | initials or `<author>` |

## Related

- [secrets.md](secrets.md) — secret detection (API keys, tokens)
