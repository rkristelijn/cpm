# Global Pre-Commit Security Hooks

> One-time setup. Covers every git repo on your machine automatically.

## Architecture

```
git config --global core.hooksPath
        │
        ▼
~/git/hub/dotfiles/hooks/
├── pre-commit              ← Orchestrator (parallel, skip-if-repo-covers-it)
└── lib/
    ├── gitleaks.sh         ← Secrets (API keys, tokens, passwords)
    ├── pii.sh              ← PII (names, domains, org data from vault)
    ├── semgrep.sh          ← SAST (code vulnerabilities)
    └── filesize.sh         ← Large file guard
```

### How it works

1. Repo's own pre-commit hook runs first (if any)
2. Orchestrator detects what the repo already covers (cpm.toml, .pre-commit-config.yaml)
3. Only runs global checks the repo doesn't handle itself
4. All checks run in parallel for speed
5. Skip everything: `git commit --no-verify` or `CPM_SKIP_HOOKS=1`

## Installation

### Prerequisites

```bash
# gitleaks (secrets scanner)
brew install gitleaks

# semgrep (SAST)
brew install semgrep

# PII vault (custom patterns)
~/git/hub/cpm/scripts/setup-pii-vault.sh
```

### Set global hooks path

```bash
git config --global core.hooksPath ~/git/hub/dotfiles/hooks
```

That's it. Every `git commit` in any repo now runs gitleaks + pii + semgrep + filesize.

### Verify

```bash
# Check it's set
git config --global core.hooksPath

# Test in any repo
cd ~/git/hub/some-repo
echo "AKIA1234567890ABCDEF" > test-secret.txt
git add test-secret.txt
git commit -m "test"  # Should be blocked by gitleaks
rm test-secret.txt && git reset
```

## What each hook does

| Hook | Tool | Detects | Speed |
|---|---|---|---|
| `gitleaks.sh` | gitleaks v8 | API keys, tokens, passwords, secrets | ~200ms |
| `pii.sh` | bash + grep | Org names, colleague names, internal domains, BSN/IBAN | ~100ms |
| `semgrep.sh` | semgrep | SQL injection, XSS, insecure crypto, etc. | ~2-5s |
| `filesize.sh` | bash + stat | Files > 5MB accidentally staged | ~50ms |

## Baseline: bulk-exclude existing findings

After rotating all secrets and verifying no real leaks remain, create a baseline
so the hooks only flag **new** findings going forward.

### Step 1: Generate current findings

```bash
# Gitleaks — scan full repo, output to baseline
cd ~/git/lab/your-repo
gitleaks git --report-path .gitleaks-baseline.json --report-format json

# PII — scan full tree, collect findings into .piiignore
bash ~/git/hub/cpm/checks/universal/security/check-pii.sh 2>&1 \
  | grep "^⚠ pii(" | awk -F'[:(]' '{gsub(/^ +/,"",$1); print $1}' \
  | sort -u > .config/.piiignore
```

### Step 2: Gitleaks baseline

```bash
# Future scans ignore everything in the baseline file
gitleaks git --pre-commit --staged --baseline-path .gitleaks-baseline.json
```

Add to your `.gitleaks.toml`:
```toml
[allowlist]
description = "Baseline — all rotated as of YYYY-MM-DD"
paths = [
  '''\.gitleaks-baseline\.json''',
]
```

Update your `lib/gitleaks.sh` to use it:
```bash
#!/bin/bash
command -v gitleaks >/dev/null 2>&1 || exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
BASELINE=""
if [[ -f "$REPO_ROOT/.gitleaks-baseline.json" ]]; then
  BASELINE="--baseline-path $REPO_ROOT/.gitleaks-baseline.json"
fi

gitleaks git --pre-commit --staged --no-banner $BASELINE 2>/dev/null
```

### Step 3: PII baseline (.piiignore)

Create `.config/.piiignore` in the repo:
```bash
# Format: file:pattern OR just pattern
# Generated on YYYY-MM-DD after review — all findings are intentional

# Docs that reference internal systems by design
docs/architecture/deployment.md:gitlab\.apsmos\.com
docs/runbook/monitoring.md:opensearch\.prod-apsmos\.com

# Test fixtures with fake data
tests/fixtures/user.json:remi.kristelijn
tests/fixtures/config.yml:vault\.prod-apsmos\.com

# Wildcard: this pattern is OK everywhere in this repo
*:Platform Team
```

### Step 4: Bulk generate .piiignore from current scan

```bash
#!/bin/bash
# generate-pii-baseline.sh — Run in a repo to create .piiignore from current findings
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "# PII baseline generated on $(date +%Y-%m-%d)" > .config/.piiignore
echo "# All findings below have been reviewed and are intentional." >> .config/.piiignore
echo "" >> .config/.piiignore

# Scan all source dirs
PII_VAULT="${PII_VAULT:-$HOME/.local/share/pii}"
PATTERNS=()
for f in "$PII_VAULT/patterns.d"/*.pii; do
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    PATTERNS+=("$line")
  done <"$f"
done

for pattern in "${PATTERNS[@]}"; do
  HITS=$(grep -rln "$pattern" src/ lib/ docs/ scripts/ checks/ 2>/dev/null || true)
  for file in $HITS; do
    [[ -z "$file" ]] && continue
    echo "$file:$pattern" >> .config/.piiignore
  done
done

# Deduplicate
sort -u .config/.piiignore -o .config/.piiignore
echo "Generated $(wc -l < .config/.piiignore) ignore rules in .config/.piiignore"
```

## Per-repo opt-out

If a repo should skip a specific global hook:

```toml
# cpm.toml — declaring what the repo handles itself
[checks]
secrets = true    # → global gitleaks.sh skips
pii = true        # → global pii.sh skips
sast = true       # → global semgrep.sh skips
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Hook too slow | `CPM_SKIP_HOOKS=1 git commit` for one-off |
| False positive gitleaks | Add to `.gitleaks.toml` allowlist |
| False positive PII | Add to `.config/.piiignore` |
| Hook not running | Check `git config --global core.hooksPath` |
| Repo has own hooks | Global orchestrator runs them first, then adds missing |

## Troubleshooting

### Release pipeline says "No commits to release"

**Cause**: A stale tag on remote that points past HEAD, OR the version regex
in `release.yml` doesn't match the `release.sh bump` output format.

**Fix**:
```bash
# Check what tags exist
git ls-remote --tags origin

# If stale tag exists (points to wrong commit)
git push origin --delete v<stale-version>

# Verify bump works locally
bash scripts/release.sh bump
# Should output: "0.4.1 → 0.5.0 (minor)"

# Re-trigger
gh workflow run release.yml --ref main
```

**Root cause (fixed in v0.5.0)**: The regex `grep -oE '[0-9]+\.[0-9]+\.[0-9]+$'`
used a `$` anchor but bump output ends with ` (minor)`, not a version number.
Fixed to: `grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1`

### Build check doesn't trigger (skipping)

**Cause**: `dorny/paths-filter` only triggers build when `src/**` or `Makefile`
changes. Docs-only or workflow-only PRs skip the build job, but branch protection
still requires it.

**Fix**: Touch a src file to trigger the build:
```bash
echo "" >> src/version_test.cpp
git add src/version_test.cpp && git commit --amend --no-edit
git push --force-with-lease
```

**Long-term fix**: Configure branch protection to allow skipped checks, or add
a `paths-ignore` based passthrough.

### SonarCloud coverage gate fails on shell scripts

**Cause**: Shell scripts have no line-coverage instrumentation. SonarCloud counts
them as "new code" with 0% coverage.

**Fix**: Add to `sonar-project.properties`:
```properties
sonar.coverage.exclusions=...,checks/**/*.sh,scripts/**/*.sh,lib/**/*.sh
```

Shell scripts are validated via e2e tests (`tests/e2e/test_*.sh`), not unit tests.

### Pre-commit hook fails with "cd: lib: No such file or directory"

**Cause**: The dotfiles repo has its hooks directory AS the global hooks path.
When committing inside the dotfiles repo itself, git tries to resolve
`$(dirname "$0")/lib` relative to `.git/hooks/` which doesn't exist (hooks
are in the repo root, not `.git/hooks/`).

**Fix**: The global `pre-commit` uses `$0` to find `lib/`. When the hook is
the global hook, `$0` points to `~/git/hub/dotfiles/hooks/pre-commit` and
`lib/` is at `~/git/hub/dotfiles/hooks/lib/`. This works for all repos EXCEPT
dotfiles itself (where `.git/hooks/` is empty). Commit dotfiles with:
```bash
git commit --no-verify -m "message"
```

### Manual tag push blocked

**Cause**: The global `pre-push` hook blocks version tags (`v*`) from being
pushed manually. Releases must go via the pipeline.

**Fix**:
```bash
# Normal workflow (correct)
gh workflow run release.yml --ref main

# Emergency override (use sparingly)
ALLOW_TAG_PUSH=1 git push origin v1.2.3
```
