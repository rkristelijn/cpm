# lib/shell/ Audit — August 2026

> Comprehensive audit of `lib/shell/`: what each file does, who uses it, dead code removal, security fixes, and remaining options.

## Summary

| Metric | Before | After |
|--------|--------|-------|
| Total scripts | 35 | 23 |
| Dead code removed | — | 17 files |
| Security issues fixed | 3 | 0 |
| Bugs fixed | 1 | 0 |

## Current inventory (post-cleanup)

### Check framework — sourced by 80+ check scripts

| File | Purpose | Sourced by |
|------|---------|------------|
| `check.sh` | Standard wrapper for all shell checks — set errexit/nounset/pipefail, auto-detect CHECK_NAME, trap findings_finish on exit | Every check script via `source "$(dirname "$0")/../../../lib/shell/check.sh"` |
| `init.sh` | Single entry point — loads ui.sh, config.sh, timer.sh. Defines GREP_EXCLUDE, FIND_PRUNE | check.sh + ~57 check scripts that source it directly |
| `ui.sh` | TUI output — colors, print_step/error/warning/summary, spinner, progress bar. Respects NO_COLOR | init.sh, run.sh, timer.sh |
| `config.sh` | Parses cpm.toml into CPM_* env vars. Supports cpm_check_enabled() gating | init.sh, ~10 check scripts |
| `timer.sh` | Per-check timing with trend analysis — compares to previous run, warns on regression | init.sh, ui.sh |
| `findings.sh` | JSONL findings database + JUnit XML output. Core of the check system | check.sh, 2 check scripts directly |
| `search.sh` | Fast search helper — ripgrep with grep fallback. cpm_search(), cpm_search_files(), cpm_search_count() | check.sh, ~8 check scripts |
| `run.sh` | Wrapper for check execution — timing + live output + logging | scripts/onboard.sh, scripts/generate-docs.sh |
| `junit.sh` | JUnit XML renderer for cpm check results | scripts/findings-to-junit.sh |

### Commands — called by C++ binary (src/main.cpp, src/commands/cmd_ops.cpp)

| File | Command | Purpose |
|------|---------|---------|
| `commit.sh` | `cpm commit` | Interactive conventional commit helper |
| `commit-msg.sh` | git hook | Validates conventional commit format |
| `phase.sh` | `cpm phase` | Process enforcement — blocks code on main, code without tests |
| `guard.sh` | `cpm guard` | Blocks direct tool usage (grep, find, etc.) via shell function overrides |
| `flow.sh` | `cpm flow` | V-model flow visualization with quality gates |
| `fix-sql.sh` | `cpm fix sql` | Auto-fix SQL anti-patterns (utf8→utf8mb4, MyISAM→InnoDB, etc.) |
| `issue.sh` | `cpm issue` | Local-first issue tracking with remote sync via providers |
| `maturity.sh` | `cpm maturity` (via install.sh) | Maturity audit — 20 criteria, calculates score/level. Also used by test_maturity.sh |

### Secrets

| File | Purpose | Used by |
|------|---------|---------|
| `secret.sh` | Resolves secrets from env → vault.json → .env → global vault → macOS Keychain | providers/clickup.sh |

### Providers — loaded by issue.sh based on `[issues] provider` in cpm.toml

| File | Integration | CLI dependency |
|------|-------------|----------------|
| `providers/local.sh` | Default — no remote sync (all functions are no-ops) | None |
| `providers/github.sh` | GitHub Issues sync | `gh` CLI |
| `providers/gitlab.sh` | GitLab Issues sync | `glab` CLI |
| `providers/jira.sh` | Jira sync | `jira` CLI |
| `providers/clickup.sh` | ClickUp sync via REST API | `curl` + secret.sh |

## Removed files (17)

### Category 1: Replaced by C++ (dead since C++ rewrite)

| File | Original purpose | Why removed |
|------|-----------------|-------------|
| `cpm-check.sh` | Shell-based check orchestrator | Replaced by C++ `cmd_check_gate()` in src/commands/ |
| `registry.sh` | Parse `[[checks]]` from cpm.toml | Only used by cpm-check.sh. `[[checks]]` format deprecated |
| `delta.sh` | Detect changed files vs main branch | Only used by cpm-check.sh |
| `log.sh` | Centralized check log with timestamps | Never integrated. Referenced non-existent checks-registry.json |

### Category 2: Standalone utilities never wired to CLI

| File | Original purpose | Why removed |
|------|-----------------|-------------|
| `discover.sh` | Deep repo analysis — languages, frameworks, architecture | Never added as `cpm discover`. Functionality exists in scan.cpp |
| `history.sh` | Git history analysis — growth curve, hotspots, co-change clusters | Never added as `cpm history`. Hotspots covered by check-neglect-score.sh |
| `project.sh` | Project/roadmap management with provider sync | Never added as `cpm project` |
| `trace.sh` | Traceability matrix from @see annotations | Never added as `cpm trace`. Covered by check-traceability-coverage.sh |
| `changelog.sh` | Generate changelog from conventional commits | Never added as `cpm changelog` |
| `demo.sh` | Showcase UI features (spinners, status indicators) | Developer utility only |
| `table.sh` | Table formatting helper with ANSI-aware column width | Never integrated into any other script |
| `term-index.sh` | Extract technical terms, generate GLOSSARY.md | Zero references |
| `docs-generate.sh` | Auto-generate docs: dep graph, module overview, CLI reference | Zero code references |
| `generate-process.sh` | Generate PROCESS.md based on maturity-target in cpm.toml | Zero code references |
| `check-dead-code.sh` | Find unused shell functions in lib/ | Naïve implementation, never used |

### Category 3: Encryption subsystem (isolated, risky)

| File | Original purpose | Why removed |
|------|-----------------|-------------|
| `encrypt.sh` | Encrypted repo management — encrypt/decrypt with `age`, vault-based, `git push --force` | 395 lines, zero external refs, force push without confirmation, embedded Python |
| `commit-msg-encrypted.sh` | Git hook for encrypted repos — replaces commit msg with random bland text | Only referenced by encrypt.sh |

## Security fixes applied

### 1. findings.sh — eval() command injection (HIGH → FIXED)

**Before:**

```bash
findings_query() {
  local filter="cat"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --severity)
      filter="$filter | grep '\"severity\":\"$2\"'"
      shift 2 ;;
    esac
  done
  eval "$filter" <"$FINDINGS_FILE"  # ← COMMAND INJECTION
}
```

**Risk:** Crafted input like `--severity 'error"; rm -rf /'` could execute arbitrary commands.

**After:** Sequential grep piping with input sanitization:

```bash
_findings_sanitize() {
  printf '%s' "$1" | tr -cd 'a-zA-Z0-9._-'
}

findings_query() {
  local result
  result=$(cat "$FINDINGS_FILE" 2>/dev/null) || return 0
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --severity)
      local val; val=$(_findings_sanitize "$2")
      result=$(printf '%s' "$result" | grep "\"severity\":\"$val\"")
      shift 2 ;;
    esac
  done
  printf '%s\n' "$result"
}
```

### 2. secret.sh — Python code injection (MEDIUM → FIXED)

**Before:**

```bash
_json_get() {
  python3 -c "
    d = json.load(open('$file'))   # ← INJECTION via $file
    keys = '$key'.split('.')       # ← INJECTION via $key
  "
}
```

**After:** Arguments passed as sys.argv, no interpolation:

```bash
_json_get() {
  python3 -c '
    d = json.load(open(sys.argv[1]))
    keys = sys.argv[2].split(".")
  ' "$file" "$key"
}
```

### 3. clickup.sh — token exposure in ps aux (MEDIUM → FIXED)

**Before:**

```bash
curl -s -H "Authorization: $token" "$@"   # ← visible in process listing
```

**After:**

```bash
curl -s -H @- "$@" <<< "Authorization: $token"   # ← token via stdin
```

## Bug fix

### phase.sh — undefined function call

**Before:**

```bash
echo "  ⛔ BLOCKED — code without tests"
log_block "3" "code without tests"    # ← log_block does not exist → crash
exit 1
log_event "WARNING: code without tests"  # ← unreachable
```

**After:**

```bash
echo "  ⛔ BLOCKED — code without tests"
log_event "BLOCKED: code without tests"
exit 1
```

## Options for remaining scripts

### Option A: Keep as-is (recommended)

The 23 remaining scripts are all actively used. The current structure is clean:

- **9 framework files** sourced by 80+ check scripts
- **8 command files** called by the C++ binary
- **1 secret resolver** for provider auth
- **5 provider files** for issue sync

No further cleanup needed.

### Option B: Migrate command scripts to C++

Several shell commands could be reimplemented in C++ for consistency and performance:

| Script | Effort | Benefit |
|--------|--------|---------|
| `maturity.sh` | Medium | Already partially in C++ (`cpm score`). Full migration eliminates bash dependency |
| `flow.sh` | Low | Pure display logic, straightforward to port |
| `fix-sql.sh` | Low | Pattern-based rewrites, natural fit for rule engine |
| `commit.sh` | Medium | Interactive TUI in C++ needs ncurses or similar |
| `guard.sh` | Low | Shell function override concept doesn't translate well to C++ |

**Trade-off:** Shell scripts are easier to iterate on. C++ is faster and has no bash version compatibility issues. Recommend migrating only when the script's interface stabilizes.

### Option C: Migrate providers to plugin system

The provider pattern (issue.sh → providers/*.sh) could become a proper plugin system:

1. **Move providers to `~/.config/cpm/providers/`** — user-installable, not bundled
2. **Define a provider interface contract** — required functions, env vars, error handling
3. **Add provider discovery** — `cpm providers list`, `cpm providers install github`

**Trade-off:** Over-engineering for 5 providers. Only worth it if community contributions are expected.

### Option D: Convert maturity.sh checks to rule engine

maturity.sh runs 20 criteria checks. These could be `.rule` files in the rule engine:

- Has README
- Has LICENSE
- Has tests
- Has CI config
- Has CONTRIBUTING.md
- etc.

**Trade-off:** Rule engine is designed for file-content pattern matching, not file-existence checks. Would need engine extension.

### Option E: Eliminate run.sh and junit.sh

Both are only used by scripts/ helper utilities, not by the core cpm binary:

- `run.sh` — used by scripts/onboard.sh, scripts/generate-docs.sh
- `junit.sh` — used by scripts/findings-to-junit.sh

Could be inlined into those scripts or removed if those scripts are also dead.

**Recommendation:** Check if scripts/onboard.sh and scripts/generate-docs.sh are actively used first.

## File count history

```text
lib/shell/ evolution:
  35 files (pre-audit)
  → 17 removed (dead code, security risk, replaced by C++)
  → 18 remaining + 5 providers = 23 total
```
