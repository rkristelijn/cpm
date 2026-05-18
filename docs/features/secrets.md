# Secret Detection

Fast regex-based secret scanning that catches common patterns without external tools.

## Usage

```bash
bash checks/universal/security/check-secrets-fast.sh
```

Runs automatically as part of `cpm check`.

## What it detects

| Pattern | Example |
|---------|---------|
| AWS access keys | `AKIA...` |
| GitHub tokens | `ghp_...`, `gho_...` |
| OpenAI keys | `sk-...` |
| Slack tokens | `xoxb-...` |
| Google API keys | `AIza...` |
| Stripe keys | `sk_live_...` |
| Private keys | `-----BEGIN RSA PRIVATE KEY` |

## Performance

- Runs in <1s (regex-based, no git history scan)
- Uses `rg` (ripgrep) when available, falls back to `grep`
- No external tools required

## Deep scanning

For git history scanning, install dedicated tools:

```bash
brew install gitleaks trufflehog
```

cpm orchestrates these via `check-sast.sh` when available.

## Configuration

```toml
# cpm.toml
[checks]
code-generic-secrets-scan = true   # enable/disable
```

## Related

- [pii-detection.md](pii-detection.md) — personal data (emails, hostnames)
- [check.md](check.md) — runs secrets check as part of quality gate
