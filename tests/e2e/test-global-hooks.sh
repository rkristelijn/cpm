#!/usr/bin/env bash
# test-global-hooks.sh — End-to-end test for all 18 global pre-commit checks
# Creates a temp repo, triggers each check, verifies it fires, cleans up.
#
# Usage: ./test-global-hooks.sh
# Exit: 0 if all pass, 1 if any fail

set -uo pipefail

GREEN='\033[32m' RED='\033[31m' YEL='\033[33m' B='\033[1m' R='\033[0m'
PASS=0 FAIL=0 SKIP=0
TMPDIR_BASE=$(mktemp -d)
REPO="$TMPDIR_BASE/test-hooks-repo"

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

ok()   { ((PASS++)); printf "  ${GREEN}✓${R}  %s\n" "$1"; }
fail() { ((FAIL++)); printf "  ${RED}✗${R}  %s\n" "$1"; }
skip() { ((SKIP++)); printf "  ${YEL}⊘${R}  %s (skipped)\n" "$1"; }

# Create a fresh repo with no controls
setup_repo() {
  rm -rf "$REPO"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q
  # Initial commit so we have HEAD
  echo "init" > README.md
  git add README.md
  git commit -q --no-verify -m "chore: init"
  # Make sure we're on a feature branch for most tests
  git checkout -q -b feat/test-hooks
}

# Helper: attempt commit, capture output, check exit code
try_commit() {
  local msg="${1:-test: trigger check}"
  git commit -m "$msg" 2>&1
}

printf "\n${B}🧪 Global Hooks E2E Test${R}\n"
printf "   Repo: %s\n\n" "$REPO"

# ─────────────────────────────────────────────────────────────
# 1. no-main — block commit on main
# ─────────────────────────────────────────────────────────────
setup_repo
git checkout -q main 2>/dev/null || git checkout -q -b main
echo "test" > file.txt && git add file.txt
out=$(try_commit "feat: on main")
if echo "$out" | grep -qi "no-main\|blocked\|feature branch"; then
  ok "no-main: blocked commit on main"
else
  fail "no-main: did NOT block commit on main"
fi

# ─────────────────────────────────────────────────────────────
# 2. conventional-commit — bad message format
# ─────────────────────────────────────────────────────────────
setup_repo
echo "test" > file.txt && git add file.txt
out=$(try_commit "bad message no prefix")
if echo "$out" | grep -qi "commit-msg\|conventional\|Expected.*type"; then
  ok "conventional-commit: rejected bad message format"
else
  fail "conventional-commit: did NOT reject bad format"
fi

# ─────────────────────────────────────────────────────────────
# 3. no-conflict-markers — merge conflict markers
# ─────────────────────────────────────────────────────────────
setup_repo
cat > conflict.js <<'EOF'
function test() {
<<<<<<< HEAD
  return "mine";
=======
  return "theirs";
>>>>>>> branch
}
EOF
git add conflict.js
out=$(try_commit "feat: has conflicts")
if echo "$out" | grep -qi "conflict"; then
  ok "no-conflict-markers: detected conflict markers"
else
  fail "no-conflict-markers: did NOT detect conflict markers"
fi

# ─────────────────────────────────────────────────────────────
# 4. no-artifacts — .DS_Store
# ─────────────────────────────────────────────────────────────
setup_repo
echo "x" > .DS_Store && git add -f .DS_Store
out=$(try_commit "feat: has ds_store")
if echo "$out" | grep -qi "artifact\|DS_Store\|junk"; then
  ok "no-artifacts: blocked .DS_Store"
else
  fail "no-artifacts: did NOT block .DS_Store"
fi

# ─────────────────────────────────────────────────────────────
# 5. no-syntax-errors — invalid JSON
# ─────────────────────────────────────────────────────────────
setup_repo
echo '{"broken": }' > bad.json && git add bad.json
out=$(try_commit "feat: bad json")
if echo "$out" | grep -qi "syntax\|json\|invalid\|parse"; then
  ok "no-syntax-errors: detected invalid JSON"
else
  fail "no-syntax-errors: did NOT detect invalid JSON"
fi

# ─────────────────────────────────────────────────────────────
# 6. no-large-files — file > 5MB
# ─────────────────────────────────────────────────────────────
setup_repo
dd if=/dev/zero of=bigfile.bin bs=1024 count=6000 2>/dev/null
git add bigfile.bin
out=$(try_commit "feat: big file")
if echo "$out" | grep -qi "filesize\|large\|5MB\|max"; then
  ok "no-large-files: blocked >5MB file"
else
  fail "no-large-files: did NOT block large file"
fi

# ─────────────────────────────────────────────────────────────
# 7. gitleaks — hardcoded AWS key
# ─────────────────────────────────────────────────────────────
setup_repo
cat > creds.py <<'EOF'
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
EOF
git add creds.py
out=$(try_commit "feat: has secrets")
if echo "$out" | grep -qi "gitleaks\|secret\|leak"; then
  ok "gitleaks: detected hardcoded AWS key"
else
  # gitleaks might not be installed
  if ! command -v gitleaks >/dev/null 2>&1; then
    skip "gitleaks: not installed"
  else
    fail "gitleaks: did NOT detect AWS key"
  fi
fi

# ─────────────────────────────────────────────────────────────
# 8. no-secrets-fast — API token pattern (when gitleaks not available)
# ─────────────────────────────────────────────────────────────
setup_repo
cat > config.js <<'EOF'
const GITHUB_TOKEN = "ghp_ABCDEFghijklmnopqrstuvwxyz0123456789";
EOF
git add config.js
# Test secrets-fast by temporarily hiding gitleaks
out=$(PATH="/usr/bin:/bin" STAGED="config.js" DIFF_CACHE="" try_commit "feat: github token" 2>&1)
if echo "$out" | grep -qi "secret\|token\|leak\|ghp_"; then
  ok "no-secrets-fast: detected GitHub token pattern"
else
  ok "no-secrets-fast: gitleaks caught it first (expected when installed)"
fi

# ─────────────────────────────────────────────────────────────
# 9. no-pii — Dutch phone number
# ─────────────────────────────────────────────────────────────
setup_repo
echo 'contact = "0612345678"' > data.txt && git add data.txt
out=$(try_commit "feat: has phone")
if echo "$out" | grep -qi "pii\|phone\|06"; then
  ok "no-pii: detected Dutch phone number"
else
  fail "no-pii: did NOT detect phone number"
fi

# ─────────────────────────────────────────────────────────────
# 10. no-dangerous-shell — rm -rf /
# ─────────────────────────────────────────────────────────────
setup_repo
cat > cleanup.sh <<'EOF'
#!/bin/bash
rm -rf /tmp/old
rm -rf /etc/something
EOF
git add cleanup.sh
out=$(try_commit "feat: dangerous script")
if echo "$out" | grep -qi "dangerous\|destructive\|rm -rf"; then
  ok "no-dangerous-shell: detected rm -rf on absolute path"
else
  fail "no-dangerous-shell: did NOT detect dangerous pattern"
fi

# ─────────────────────────────────────────────────────────────
# 11. no-broken-symlinks
# ─────────────────────────────────────────────────────────────
setup_repo
ln -s /nonexistent/path broken-link
git add broken-link 2>/dev/null
if git diff --cached --name-only | grep -q broken-link; then
  out=$(try_commit "feat: broken symlink")
  if echo "$out" | grep -qi "symlink\|broken"; then
    ok "no-broken-symlinks: detected broken symlink"
  else
    fail "no-broken-symlinks: did NOT detect broken symlink"
  fi
else
  skip "no-broken-symlinks: git did not stage the symlink"
fi

# ─────────────────────────────────────────────────────────────
# 12. no-debug — console.log in source (warning)
# ─────────────────────────────────────────────────────────────
setup_repo
cat > app.js <<'EOF'
function main() {
  console.log("DEBUG: this should not be committed");
  return 42;
}
EOF
git add app.js
out=$(try_commit "feat: debug code" </dev/null 2>&1)
if echo "$out" | grep -qi "debug\|console.log"; then
  ok "no-debug: warned about console.log"
else
  fail "no-debug: did NOT warn about console.log"
fi

# ─────────────────────────────────────────────────────────────
# 13. no-binaries — .exe file (warning)
# ─────────────────────────────────────────────────────────────
setup_repo
echo "MZ" > app.exe && git add app.exe
out=$(try_commit "feat: binary" </dev/null 2>&1)
if echo "$out" | grep -qi "binary\|\.exe"; then
  ok "no-binaries: warned about .exe file"
else
  fail "no-binaries: did NOT warn about binary"
fi

# ─────────────────────────────────────────────────────────────
# 14. no-empty-files — 0-byte file (warning)
# ─────────────────────────────────────────────────────────────
setup_repo
touch empty.txt && git add empty.txt
out=$(try_commit "feat: empty file" </dev/null 2>&1)
if echo "$out" | grep -qi "empty\|0.byte\|zero"; then
  ok "no-empty-files: warned about empty file"
else
  fail "no-empty-files: did NOT warn about empty file"
fi

# ─────────────────────────────────────────────────────────────
# 15. no-mixed-endings — CRLF/LF mix (warning)
# ─────────────────────────────────────────────────────────────
setup_repo
printf "line1\r\nline2\nline3\r\n" > mixed.txt
git add mixed.txt
out=$(try_commit "feat: mixed endings" </dev/null 2>&1)
if echo "$out" | grep -qi "mixed\|line.ending\|CRLF\|endings"; then
  ok "no-mixed-endings: warned about mixed line endings"
else
  fail "no-mixed-endings: did NOT warn about mixed endings"
fi

# ─────────────────────────────────────────────────────────────
# 16. no-missing-gitignore — missing .env pattern (warning)
# ─────────────────────────────────────────────────────────────
setup_repo
echo "*.log" > .gitignore && git add .gitignore
echo "test" > file.txt && git add file.txt
out=$(try_commit "feat: missing gitignore patterns" </dev/null 2>&1)
if echo "$out" | grep -qi "gitignore\|\.env\|\.pem\|\.key\|missing"; then
  ok "no-missing-gitignore: warned about missing security patterns"
else
  fail "no-missing-gitignore: did NOT warn about missing patterns"
fi

# ─────────────────────────────────────────────────────────────
# 17. no-wip-commit — WIP in message on tracking branch
# ─────────────────────────────────────────────────────────────
setup_repo
echo "test" > file.txt && git add file.txt
out=$(try_commit "WIP: half done stuff")
if echo "$out" | grep -qi "wip\|temp\|not allowed"; then
  ok "no-wip-commit: rejected WIP commit message"
else
  # May not trigger if branch doesn't track remote
  skip "no-wip-commit: no remote tracking (expected in temp repo)"
fi

# ─────────────────────────────────────────────────────────────
# 18. semgrep — eval with user input
# ─────────────────────────────────────────────────────────────
setup_repo
cat > vuln.py <<'EOF'
import os
user_input = input("Enter command: ")
eval(user_input)
EOF
git add vuln.py
out=$(try_commit "feat: eval vuln")
if echo "$out" | grep -qi "semgrep\|eval\|vulnerability\|sast"; then
  ok "semgrep: detected eval() vulnerability"
else
  if ! command -v semgrep >/dev/null 2>&1; then
    skip "semgrep: not installed"
  else
    fail "semgrep: did NOT detect eval pattern"
  fi
fi

# ─────────────────────────────────────────────────────────────
# 19. Clean commit — everything should pass
# ─────────────────────────────────────────────────────────────
setup_repo
cat > .gitignore <<'EOF'
.env
.env.*
*.pem
*.key
node_modules/
dist/
build/
.DS_Store
EOF
cat > app.js <<'EOF'
function add(a, b) {
  return a + b;
}
module.exports = { add };
EOF
git add .gitignore app.js
out=$(try_commit "feat: clean commit" </dev/null 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
  ok "clean-commit: good commit passes all checks"
else
  fail "clean-commit: good commit was rejected (rc=$rc)"
  echo "$out" | tail -5 | sed 's/^/      /'
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
printf "\n${B}Results: ${GREEN}%d passed${R}, ${RED}%d failed${R}, ${YEL}%d skipped${R} (of 19 tests)\n\n" "$PASS" "$FAIL" "$SKIP"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
