# Global Hook Checks Overview

25 checks that run via `cpm hook --global` on every `git commit`. Autofix checks run first (fix + re-stage), then blocking checks run in parallel, then warning checks (~225ms total).

## Autofix checks (fix + re-stage automatically)

| Check | What it fixes | Doc |
|-------|--------------|-----|
| [fix-trailing-whitespace](hook-fix-trailing-whitespace.md) | Removes trailing whitespace | [→](hook-fix-trailing-whitespace.md) |
| [fix-end-of-file](hook-fix-end-of-file.md) | Adds newline at end of file | [→](hook-fix-end-of-file.md) |
| [fix-mixed-endings](hook-fix-mixed-endings.md) | Normalizes CRLF → LF | [→](hook-fix-mixed-endings.md) |

## Blocking checks (commit rejected on failure)

| Check | What it catches | Doc |
|-------|----------------|-----|
| [gitleaks](hook-gitleaks.md) | Secrets (API keys, tokens, passwords) | [→](hook-gitleaks.md) |
| [semgrep](hook-semgrep.md) | SAST vulnerabilities (SQLi, XSS, RCE) | [→](hook-semgrep.md) |
| [no-secrets-fast](hook-no-secrets-fast.md) | Regex secret patterns (gitleaks fallback) | [→](hook-no-secrets-fast.md) |
| [no-pii](hook-no-pii.md) | PII data (BSN, IBAN, SSN, creditcard, IP — 13 patterns) | [→](hook-no-pii.md) |
| [no-large-files](hook-no-large-files.md) | Files over 5MB | [→](hook-no-large-files.md) |
| [no-dangerous-shell](hook-no-dangerous-shell.md) | Destructive bash patterns (rm -rf, chmod 777) | [→](hook-no-dangerous-shell.md) |
| [no-main](hook-no-main.md) | Commits on main/master/develop | [→](hook-no-main.md) |
| [no-conflict-markers](hook-no-conflict-markers.md) | Merge conflict markers | [→](hook-no-conflict-markers.md) |
| [no-artifacts](hook-no-artifacts.md) | .DS_Store, node_modules, build/, IDE files, logs (~37 patterns) | [→](hook-no-artifacts.md) |
| [no-syntax-errors](hook-no-syntax-errors.md) | Invalid JSON/YAML | [→](hook-no-syntax-errors.md) |
| [no-broken-symlinks](hook-no-broken-symlinks.md) | Broken symbolic links | [→](hook-no-broken-symlinks.md) |

## Warning checks (prompt to continue)

| Check | What it warns about | Doc |
|-------|-------------------|-----|
| [no-missing-gitignore](hook-no-missing-gitignore.md) | .gitignore missing security patterns | [→](hook-no-missing-gitignore.md) |
| [no-debug](hook-no-debug.md) | Debug statements (console.log, debugger, var_dump, dd) | [→](hook-no-debug.md) |
| [no-binaries](hook-no-binaries.md) | Binary files (.exe, .zip, .jar, .docx) | [→](hook-no-binaries.md) |
| [no-empty-files](hook-no-empty-files.md) | 0-byte files | [→](hook-no-empty-files.md) |
| [no-mixed-endings](hook-no-mixed-endings.md) | CRLF/LF mix (skipped when autofix enabled) | [→](hook-no-mixed-endings.md) |
| [no-unconventional-casing](hook-no-unconventional-casing.md) | File/folder naming conventions | [→](hook-no-unconventional-casing.md) |
| [no-typos](hook-no-typos.md) | Spelling mistakes via typos-cli | [→](hook-no-typos.md) |
| [no-dei-violations](hook-no-dei-violations.md) | Non-inclusive terminology | [→](hook-no-dei-violations.md) |
| [no-absolute-paths](hook-no-absolute-paths.md) | Hardcoded absolute paths, ~/, ../ escapes | [→](hook-no-absolute-paths.md) |

## Commit message checks

| Check | What it validates | Doc |
|-------|------------------|-----|
| [conventional-commit](hook-conventional-commit.md) | Message format: type(scope): description | [→](hook-conventional-commit.md) |
| [no-wip-commit](hook-no-wip-commit.md) | WIP/temp/fixup on remote-tracking branches | [→](hook-no-wip-commit.md) |

## Configuration

See [hooks.md](../features/hooks.md) for the complete configuration guide (global vs per-repo, override hierarchy, suppression methods).
