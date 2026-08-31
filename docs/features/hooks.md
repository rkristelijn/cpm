# cpm hooks — Complete Guide

## Two modes

| Mode | Command | Scope | What it does |
|------|---------|-------|-------------|
| **Per-repo** | `cpm hook` | Current repo only | Installs hooks in `.git/hooks/` that run `cpm check` |
| **Global** | `cpm hook --global` | Every repo on your machine | Installs 26 security & quality checks in `~/.config/git/hooks/` |

## Global hooks (`cpm hook --global`)

### Quick start

```bash
cpm hook --global              # Install
cpm hook --global --status     # What's on/off?
cpm hook --global --check      # Health check
cpm hook --global --enable X   # Enable a check
cpm hook --global --disable X  # Disable a check
cpm hook --global --remove     # Uninstall everything
```

### What runs on every commit

Three phases, in order:

#### Phase 1: Autofix (fix + re-stage, silent if nothing to fix)
| Check | What it fixes |
|-------|--------------|
| fix-trailing-whitespace | Removes trailing whitespace |
| fix-end-of-file | Adds newline at EOF |
| fix-mixed-endings | Normalizes CRLF → LF |

#### Phase 2: Blocking (commit rejected if any fail)
| Check | What it catches |
|-------|----------------|
| gitleaks | Secrets (API keys, tokens, passwords) |
| no-secrets-fast | 19 regex patterns (fallback when gitleaks not installed) |
| semgrep | SAST (injection, eval, deserialization, TLS bypass) |
| no-pii | PII data (BSN, IBAN, SSN, creditcard, IP, phone — 13 patterns) |
| no-large-files | Files >5MB |
| no-dangerous-shell | `rm -rf /`, `chmod 777`, `curl\|sh` |
| no-main | Commits on main/master/develop |
| no-conflict-markers | `<<<<<<<` merge conflict markers |
| no-artifacts | .DS_Store, node_modules, build/, IDE files, logs (~37 patterns) |
| no-syntax-errors | Invalid JSON/YAML |
| no-broken-symlinks | Broken symbolic links |

#### Phase 3: Warning (prompt "Continue committing? y/N")
| Check | What it warns about |
|-------|-------------------|
| no-missing-gitignore | .gitignore missing .env, *.pem, *.key, node_modules, .DS_Store, *.log |
| no-debug | console.log, debugger, print(), var_dump, dd(), System.out.println |
| no-binaries | .exe, .zip, .jar, .docx accidentally staged |
| no-empty-files | 0-byte files |
| no-mixed-endings | CRLF/LF mix (skipped when fix-mixed-endings autofix is enabled) |
| no-unconventional-casing | File/folder naming (lower-kebab-case, auto-detects React PascalCase) |
| no-typos | Spelling mistakes via typos-cli |
| no-dei-violations | Non-inclusive terminology (whitelist→allowlist, etc.) |
| no-absolute-paths | Hardcoded paths (/Users/..., ~/, ../ escapes) |

#### Phase 4: Commit message (commit-msg hook)
| Check | What it validates |
|-------|------------------|
| conventional-commit | Message format: `type(scope): description` |
| no-wip-commit | Blocks WIP/temp/fixup on remote-tracking branches |

### Performance

26 checks run in **~225ms** (parallel). Autofix adds ~50ms when files need fixing.

## Configuration hierarchy

Three levels, in priority order:

```
1. cpm.toml [hooks.global]     ← Repo-level override (HIGHEST priority)
2. Auto-detect                  ← cpm.toml [checks], .pre-commit-config.yaml
3. ~/.config/cpm/hooks.conf     ← Global defaults (LOWEST priority)
```

### Level 1: Per-repo override (`cpm.toml`)

```toml
# cpm.toml in repo root
[hooks.global]
no-pii = false           # Disable: this repo handles PII differently
gitleaks = true           # Force on: even if auto-detect would skip
no-debug = false          # Disable: this is a debug tool, console.log is fine
no-artifacts = false      # Disable: this repo intentionally tracks build output
```

Only checks explicitly listed are overridden. Everything else follows the global default.

### Level 2: Auto-detect (deduplication)

The orchestrator automatically detects if a repo already handles a check:

| If repo has... | Global hook skips... |
|----------------|---------------------|
| `cpm.toml` with `code-generic-secrets-scan = true` | gitleaks (repo runs its own) |
| `.pre-commit-config.yaml` with `gitleaks` | gitleaks |
| `cpm.toml` with `vulnerability-scan` or `semgrep` | semgrep |
| `cpm.toml` with `pii` | no-pii |

### Level 3: Global defaults (`~/.config/cpm/hooks.conf`)

```bash
cpm hook --global --status     # See current state
cpm hook --global --enable X   # Enable a check globally
cpm hook --global --disable X  # Disable a check globally
```

Config file: `~/.config/cpm/hooks.conf`. Auto-generated on first run. Edit manually or via CLI.

### React / PascalCase projects

The `no-unconventional-casing` check auto-detects React/Angular/Next.js from `package.json` and allows PascalCase filenames. Or force it:

```toml
# cpm.toml
[naming]
allow-pascal-case = true
```

## Per-repo hooks (`cpm hook`)

Separate from global hooks. Installs hooks that run `cpm check` on the current repo.

```bash
cpm hook      # Install based on cpm.toml [hooks]
cpm unhook    # Remove
```

```toml
# cpm.toml
[hooks]
pre-commit = true    # Runs: cpm check --fast
pre-push = true      # Runs: cpm check
commit-msg = true    # Conventional commit validation
```

### How per-repo and global hooks coexist

```
git commit
  ↓
Global orchestrator (from ~/.config/git/hooks/pre-commit)
  ├── 1. Runs repo's own hook first (.git/hooks/, .githooks/, or .husky/)
  │      └── This is where 'cpm hook' installs 'cpm check --fast'
  ├── 2. Reads cpm.toml [hooks.global] for overrides
  ├── 3. Auto-detects what repo already covers
  ├── 4. Runs autofix checks
  ├── 5. Runs blocking checks (only what's not already covered)
  └── 6. Runs warning checks
```

So a repo with `cpm hook` installed gets BOTH:
- `cpm check --fast` (per-repo, from .githooks/pre-commit)
- Global security checks (from ~/.config/git/hooks/)

They don't conflict because the global orchestrator runs the repo hook first, then adds its own checks. Checks that the repo already handles are skipped via dedup.

## File locations

| File | Purpose |
|------|---------|
| `~/.config/git/hooks/pre-commit` | Global orchestrator |
| `~/.config/git/hooks/commit-msg` | Global commit message validation |
| `~/.config/git/hooks/lib/*.sh` | Individual check scripts |
| `~/.config/cpm/hooks.conf` | Global on/off config |
| `cpm.toml` `[hooks]` | Per-repo hook installation config |
| `cpm.toml` `[hooks.global]` | Per-repo override of global checks |
| `cpm.toml` `[naming]` | Per-repo naming convention config |
| `.config/.pii-config` | Per-repo PII pattern disable list |

## Suppression

| Scope | Method |
|-------|--------|
| One line | `cpm:ignore pii`, `cpm:ignore dei`, `cpm:ignore path` comment |
| One commit | `git commit --no-verify` |
| One check globally | `cpm hook --global --disable <check>` |
| One check per-repo | `cpm.toml [hooks.global] <check> = false` |
| All checks | `CPM_SKIP_HOOKS=1 git commit` |

## Every warning links to docs

When a check fires, the output includes a link:
```
⚠ no-pii: PII detected (us-ssn)
   docs: https://github.com/rkristelijn/cpm/blob/main/docs/checks/hook-no-pii.md
```
