---
title: "cpm hook --global: one-command shift-left for any machine"
type: feat
created: 2026-08-31T13:00:16+00:00
labels: [feat, hooks, security, shift-left]
remote:
---

## What

Add `cpm hook --global` command that installs a curated set of fast pre-commit checks globally via `git config --global core.hooksPath`. The checks should:

1. Run on every `git commit` in every repo on the machine
2. Only scan **staged files** (fast — no full repo scans)
3. Be configurable: global defaults + per-repo overrides via `cpm.toml`
4. Deduplicate: if a repo already has a check (via `cpm.toml` or `.pre-commit-config.yaml`), skip the global version
5. Install required tools automatically (`gitleaks`, `semgrep`, etc.)

### User journey

```bash
# New machine setup — one command
cpm hook --global

# Verify
cpm hook --global --check

# Remove
cpm hook --global --remove

# Per-repo override in cpm.toml
[hooks]
pre-commit = true
# extend or disable specific global checks:
# hooks.global.gitleaks = false    # repo handles secrets itself
# hooks.global.owasp = true       # opt-in to OWASP checks
```

### Default global check set (fast, <3s total)

| Check | What it catches | Tool | Speed |
|-------|----------------|------|-------|
| `gitleaks` | API keys, tokens, passwords in staged files | gitleaks | <1s |
| `semgrep` | Critical SAST patterns (injection, RCE) | semgrep | <2s |
| `pii` | BSN, IBAN, phone numbers (NL-focused) | grep/awk | <0.5s |
| `filesize` | Files >5MB accidentally staged | wc | <0.1s |
| `conventional-commit` | Commit message format enforcement | regex | <0.1s |
| `secrets-fast` | Regex-based quick secret patterns (no gitleaks needed) | cpm rules/secrets | <0.5s |

### Optional checks (opt-in via cpm.toml or --with flag)

| Check | What | Why opt-in |
|-------|------|-----------|
| `owasp` | Hardcoded temps, empty catch, CORS wildcard, weak crypto, debug enabled | More opinionated |
| `supply-chain` | Lockfile sync, pinned actions, suspicious post-install scripts | May be noisy in legacy repos |
| `cpm-rules` | Full cpm rule-scan on staged files | Slower (~5s), needs cpm binary |

## Why

- **scripts/setup-global-hooks.sh already exists** but isn't wired into `cpm hook` CLI
- Developers at APS need a single command to get security guardrails without configuring each repo
- Current dotfiles-based approach (`~/git/hub/dotfiles/hooks/`) works but isn't distributable or self-updating
- cpm already has 80+ secrets rules, 70+ supply-chain rules, and OWASP checks — they should be usable as pre-commit hooks, not just in `cpm check`

## Value

- Quality characteristic: **Security** + **Usability**
- Stakeholder benefit: Any developer runs `cpm hook --global` once → every commit is checked for secrets, vulns, PII. Zero per-repo config needed. Teams get shift-left security without friction.

## Acceptance criteria

- [ ] `cpm hook --global` installs global hooks and sets `core.hooksPath` → test: test_e2e_hook_global_install
- [ ] `cpm hook --global --check` reports hook health (tools installed, hooks present) → test: test_e2e_hook_global_check
- [ ] `cpm hook --global --remove` unsets `core.hooksPath` and cleans up → test: test_e2e_hook_global_remove
- [ ] Hooks only scan staged files (not full repo) → test: test_e2e_hook_staged_only
- [ ] If repo has `cpm.toml` with `hooks.global.gitleaks = false`, global gitleaks is skipped → test: test_e2e_hook_dedup
- [ ] All default checks complete in <3s on a repo with 10 staged files → test: test_e2e_hook_performance
- [ ] `cpm install` installs hooks when `[hooks] pre-commit = true` is set → test: test_e2e_install_hooks

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated: README, docs/features/hooks.md
- [ ] `scripts/setup-global-hooks.sh` refactored into C++ command (or called by it)

## Design notes

### Architecture

```
cpm hook --global
    │
    ├── Installs to: ~/.config/git/hooks/ (XDG) or custom GLOBAL_HOOKS_DIR
    ├── Sets: git config --global core.hooksPath
    │
    └── ~/.config/git/hooks/
        ├── pre-commit          # Orchestrator (bash)
        │   ├── Runs repo's own hooks first
        │   ├── Detects what repo already covers (cpm.toml, .pre-commit-config.yaml)
        │   └── Runs missing checks in parallel
        ├── commit-msg          # Conventional commit validator
        └── lib/
            ├── gitleaks.sh     # Staged-only secrets scan
            ├── pii.sh          # PII detection (configurable patterns)
            ├── semgrep.sh      # SAST on staged files (5s timeout)
            ├── filesize.sh     # Large file guard
            ├── secrets-fast.sh # Regex-only secrets (no external tool needed)
            └── owasp.sh        # Optional OWASP pattern checks
```

### Deduplication logic

```
For each global check:
  1. Does cpm.toml exist in repo AND has hooks.global.<check> = false? → SKIP
  2. Does cpm.toml exist AND has the equivalent check enabled? → SKIP (repo handles it)
  3. Does .pre-commit-config.yaml reference the same tool? → SKIP
  4. Otherwise → RUN global check
```

### Extension in cpm.toml

```toml
[hooks]
pre-commit = true
commit-msg = true

[hooks.global]
# Override global defaults (all true by default when global hooks installed)
gitleaks = true         # default: true
semgrep = true          # default: true  
pii = true              # default: true
filesize = true         # default: true
conventional-commit = true  # default: true
# Opt-in extras
owasp = false           # default: false (opt-in)
supply-chain = false    # default: false (opt-in)
```

## References

- Existing implementation: `scripts/setup-global-hooks.sh`
- Current dotfiles hooks: `~/git/hub/dotfiles/hooks/`
- Related: `cpm hook` (per-repo) and `cpm unhook` commands already exist
