# Global Hook Checks Overview

All 19 checks that run via `cpm hook --global`. Checks run in parallel on every `git commit`.

## Blocking checks

These reject the commit if they fail.

| Check | What it catches | Doc |
|-------|----------------|-----|
| [hook-gitleaks](hook-gitleaks.md) | Secrets (API keys, tokens, passwords) | [→](hook-gitleaks.md) |
| [hook-semgrep](hook-semgrep.md) | SAST vulnerabilities (SQLi, XSS, RCE) | [→](hook-semgrep.md) |
| [hook-no-secrets-fast](hook-no-secrets-fast.md) | Regex secret patterns (gitleaks fallback) | [→](hook-no-secrets-fast.md) |
| [hook-no-pii](hook-no-pii.md) | PII data (BSN, IBAN, phone numbers) | [→](hook-no-pii.md) |
| [hook-no-large-files](hook-no-large-files.md) | Files over 5MB | [→](hook-no-large-files.md) |
| [hook-no-dangerous-shell](hook-no-dangerous-shell.md) | Destructive bash patterns | [→](hook-no-dangerous-shell.md) |
| [hook-no-main](hook-no-main.md) | Commits on main/master/develop | [→](hook-no-main.md) |
| [hook-no-conflict-markers](hook-no-conflict-markers.md) | Merge conflict markers | [→](hook-no-conflict-markers.md) |
| [hook-no-artifacts](hook-no-artifacts.md) | .DS_Store, node_modules, build/ | [→](hook-no-artifacts.md) |
| [hook-no-syntax-errors](hook-no-syntax-errors.md) | Invalid JSON/YAML | [→](hook-no-syntax-errors.md) |
| [hook-no-broken-symlinks](hook-no-broken-symlinks.md) | Broken symbolic links | [→](hook-no-broken-symlinks.md) |

## Warning checks

These warn but allow the commit to proceed (interactive prompt).

| Check | What it catches | Doc |
|-------|----------------|-----|
| [hook-no-missing-gitignore](hook-no-missing-gitignore.md) | Missing .gitignore security patterns | [→](hook-no-missing-gitignore.md) |
| [hook-no-debug](hook-no-debug.md) | Debug statements (console.log, debugger) | [→](hook-no-debug.md) |
| [hook-no-binaries](hook-no-binaries.md) | Binary files (.exe, .zip, .jar) | [→](hook-no-binaries.md) |
| [hook-no-empty-files](hook-no-empty-files.md) | Empty (0-byte) files | [→](hook-no-empty-files.md) |
| [hook-no-mixed-endings](hook-no-mixed-endings.md) | Mixed CRLF/LF line endings | [→](hook-no-mixed-endings.md) |
| [hook-no-unconventional-casing](hook-no-unconventional-casing.md) | File/folder naming conventions | [→](hook-no-unconventional-casing.md) |

## Commit message checks

These run on the commit message (commit-msg hook).

| Check | What it catches | Doc |
|-------|----------------|-----|
| [hook-conventional-commit](hook-conventional-commit.md) | Non-conventional commit format | [→](hook-conventional-commit.md) |
| [hook-no-wip-commit](hook-no-wip-commit.md) | WIP/temp/fixup on tracked branches | [→](hook-no-wip-commit.md) |

## Quick commands

```bash
cpm hook --global                     # Install/update hooks
cpm hook --global --check             # Health check
cpm hook --global --status            # Show enabled/disabled
cpm hook --global --disable <check>   # Disable a check
cpm hook --global --enable <check>    # Enable a check
git commit --no-verify                # Skip all hooks once
```
