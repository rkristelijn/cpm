# hook-no-secrets-fast

## What it catches

Common secret patterns using fast regex matching — API keys, tokens, passwords, and connection strings.

## Why it matters

This is the lightweight fallback when gitleaks is not installed. It catches the most common secret patterns using pure bash regex, with zero external dependencies. It ensures every developer has at least basic secret detection even without installing extra tools.

## Examples

```text
# Bad
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SLACK_WEBHOOK=https://hooks.slack.com/services/T00/B00/xxxx
DB_URL=postgres://user:pass@host:5432/db

# Good
GITHUB_TOKEN=${GITHUB_TOKEN}
SLACK_WEBHOOK=$(vault read secret/slack)
DB_URL=postgres://localhost:5432/dev
```

## Override

- Global: `cpm hook --global --disable no-secrets-fast`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-secrets-fast = false
  ```

- One commit: `git commit --no-verify`
