# hook-gitleaks

## What it catches

Secrets like API keys, tokens, passwords, and private keys in staged files.

## Why it matters

Leaked secrets in git history are permanent — even after deletion, they remain in older commits. Attackers actively scan public repos for credentials. A single leaked AWS key can cost thousands in minutes.

## Examples

```text
# Bad
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
password = "hunter2"

# Good
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
password = os.environ["DB_PASSWORD"]
```

## Override

- Global: `cpm hook --global --disable gitleaks`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  gitleaks = false
  ```

- One commit: `git commit --no-verify`
- Baseline: add false positives to `.gitleaks-baseline.json`
