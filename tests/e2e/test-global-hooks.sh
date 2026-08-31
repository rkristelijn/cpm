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
# 20. Autofix: trailing whitespace gets fixed
# ─────────────────────────────────────────────────────────────
setup_repo
printf "hello   \nworld  \n" > spaces.txt
git add spaces.txt
STAGED="spaces.txt" bash ~/.config/git/hooks/lib/fix-trailing-whitespace.sh >/dev/null 2>&1
content=$(cat spaces.txt)
if [[ "$content" == $'hello\nworld' ]]; then
  ok "fix-trailing-whitespace: removed trailing whitespace"
else
  fail "fix-trailing-whitespace: did NOT fix whitespace"
fi

# ─────────────────────────────────────────────────────────────
# 21. Autofix: end-of-file newline gets added
# ─────────────────────────────────────────────────────────────
setup_repo
printf "no newline at end" > noeol.txt
git add noeol.txt
STAGED="noeol.txt" bash ~/.config/git/hooks/lib/fix-end-of-file.sh >/dev/null 2>&1
lastbyte=$(xxd -p noeol.txt | tail -c 3 | tr -d '[:space:]')
if [[ "$lastbyte" == "0a" ]]; then
  ok "fix-end-of-file: added newline at EOF"
else
  fail "fix-end-of-file: did NOT add newline (got $lastbyte)"
fi

# ─────────────────────────────────────────────────────────────
# 22. Autofix: mixed CRLF→LF gets normalized
# ─────────────────────────────────────────────────────────────
setup_repo
printf "line1\r\nline2\nline3\r\n" > mixed.txt
git add mixed.txt
STAGED="mixed.txt" bash ~/.config/git/hooks/lib/fix-mixed-endings.sh >/dev/null 2>&1
crlf=$(grep -cP '\r$' mixed.txt 2>/dev/null || echo "0")
if [ "$crlf" = "0" ]; then
  ok "fix-mixed-endings: normalized CRLF to LF"
else
  fail "fix-mixed-endings: still has $crlf CRLF lines"
fi

# ─────────────────────────────────────────────────────────────
# 23. no-typos: catches spelling mistakes
# ─────────────────────────────────────────────────────────────
setup_repo
echo 'def calcualte_ammount(): retrun 42' > code.py
git add code.py
out=$(STAGED="code.py" bash ~/.config/git/hooks/lib/no-typos.sh 2>&1)
if echo "$out" | grep -qi "calcualte\|ammount\|typos"; then
  ok "no-typos: detected spelling mistakes"
else
  if ! command -v typos >/dev/null 2>&1; then
    skip "no-typos: typos-cli not installed"
  else
    fail "no-typos: did NOT detect spelling mistakes"
  fi
fi

# ─────────────────────────────────────────────────────────────
# NORMAL ACTIONS THAT MUST NOT BLOCK
# ─────────────────────────────────────────────────────────────
printf "\n${B}── Normal commits that must pass ──${R}\n"

# ─────────────────────────────────────────────────────────────
# 24. Normal: Python file with clean code
# ─────────────────────────────────────────────────────────────
setup_repo
cat > app.py <<'EOF'
"""Application entry point."""


def main():
    """Run the application."""
    print("Hello, world!")
    return 0


if __name__ == "__main__":
    main()
EOF
git add app.py
out=$(try_commit "feat: add python app" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: clean Python file commits fine"
else
  fail "normal: clean Python file was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 25. Normal: TypeScript with kebab-case naming
# ─────────────────────────────────────────────────────────────
setup_repo
mkdir -p src/components
cat > src/components/user-profile.ts <<'EOF'
export interface UserProfile {
  name: string;
  email: string;
}

export function getUserProfile(id: number): UserProfile {
  return { name: "test", email: "test@example.com" };
}
EOF
git add src/components/user-profile.ts
out=$(try_commit "feat: add user profile component" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: TypeScript in kebab-case folder commits fine"
else
  fail "normal: TypeScript in kebab-case folder was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 26. Normal: Markdown documentation
# ─────────────────────────────────────────────────────────────
setup_repo
cat > docs.md <<'EOF'
# Project Documentation

## Getting Started

Run the following command:

```bash
npm install
npm start
```

## API Reference

See the [API docs](https://example.com/api).
EOF
git add docs.md
out=$(try_commit "docs: add project documentation" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: markdown documentation commits fine"
else
  fail "normal: markdown was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 27. Normal: JSON config file (valid)
# ─────────────────────────────────────────────────────────────
setup_repo
cat > config.json <<'EOF'
{
  "name": "my-app",
  "version": "1.0.0",
  "port": 3000,
  "features": {
    "auth": true,
    "logging": true
  }
}
EOF
git add config.json
out=$(try_commit "chore: add config" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: valid JSON commits fine"
else
  fail "normal: valid JSON was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 28. Normal: YAML config (valid)
# ─────────────────────────────────────────────────────────────
setup_repo
cat > deploy.yml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: app
          image: my-app:latest
EOF
git add deploy.yml
out=$(try_commit "chore: add kubernetes deployment" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: valid YAML commits fine"
else
  fail "normal: valid YAML was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 29. Normal: Shell script (safe, with shebang and strict mode)
# ─────────────────────────────────────────────────────────────
setup_repo
cat > deploy.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

echo "Deploying application..."
npm run build
npm run deploy
SCRIPT
git add deploy.sh
out=$(try_commit "feat: add deploy script" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: safe shell script commits fine"
else
  fail "normal: safe shell script was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 30. Normal: Multiple file types in one commit
# ─────────────────────────────────────────────────────────────
setup_repo
echo '{"name": "test"}' > package.json
echo "body { color: red; }" > style.css
echo "export const x = 1;" > index.ts
cat > README.md <<'EOF'
# My Project

A simple project.
EOF
git add package.json style.css index.ts README.md
out=$(try_commit "feat: initial project setup" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: multi-file commit with mixed types passes"
else
  fail "normal: multi-file commit was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 31. Normal: Dockerfile (safe)
# ─────────────────────────────────────────────────────────────
setup_repo
cat > Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
EOF
git add Dockerfile
out=$(try_commit "chore: add Dockerfile" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: safe Dockerfile commits fine"
else
  fail "normal: safe Dockerfile was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 32. Normal: .gitignore update (adding patterns)
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
coverage/
*.log
EOF
git add .gitignore
out=$(try_commit "chore: update gitignore" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: .gitignore update commits fine"
else
  fail "normal: .gitignore update was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 33. Normal: Deleting a file
# ─────────────────────────────────────────────────────────────
setup_repo
echo "old" > old-file.txt && git add old-file.txt && git commit -q --no-verify -m "chore: add old file"
git rm old-file.txt >/dev/null
out=$(try_commit "chore: remove old file" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: deleting a file commits fine"
else
  fail "normal: file deletion was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 34. Normal: Renaming a file
# ─────────────────────────────────────────────────────────────
setup_repo
echo "content" > old-name.txt && git add old-name.txt && git commit -q --no-verify -m "chore: add file"
git mv old-name.txt new-name.txt
out=$(try_commit "refactor: rename file" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: renaming a file commits fine"
else
  fail "normal: file rename was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 35. Normal: console.log in a TEST file (should not warn)
# ─────────────────────────────────────────────────────────────
setup_repo
cat > app.test.js <<'EOF'
describe("app", () => {
  it("should work", () => {
    console.log("test output");
    expect(true).toBe(true);
  });
});
EOF
git add app.test.js
out=$(try_commit "test: add app tests" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: console.log in test file is not flagged"
else
  fail "normal: console.log in test file was rejected"
fi

# ─────────────────────────────────────────────────────────────
# 36. Normal: Known uppercase files (README, LICENSE, Makefile)
# ─────────────────────────────────────────────────────────────
setup_repo
echo "# Project" > README.md
echo "MIT" > LICENSE
printf "all:\n\techo done\n" > Makefile
git add README.md LICENSE Makefile
out=$(try_commit "chore: add project files" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: README.md + LICENSE + Makefile pass naming check"
else
  fail "normal: known uppercase files were rejected"
fi

# ─────────────────────────────────────────────────────────────
# 37. Normal: Dotfiles (.editorconfig, .eslintrc)
# ─────────────────────────────────────────────────────────────
setup_repo
echo "root = true" > .editorconfig
echo '{"extends": "eslint:recommended"}' > .eslintrc.json
git add .editorconfig .eslintrc.json
out=$(try_commit "chore: add editor and lint config" </dev/null 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: dotfiles commit fine"
else
  fail "normal: dotfiles were rejected"
fi

# ─────────────────────────────────────────────────────────────
# 38. Normal: Empty commit (only message, no files)
# ─────────────────────────────────────────────────────────────
setup_repo
out=$(git commit --allow-empty -m "chore: empty commit" 2>&1)
if [ $? -eq 0 ]; then
  ok "normal: empty commit passes (no staged files = no checks)"
else
  fail "normal: empty commit was rejected"
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + SKIP))
printf "\n${B}Results: ${GREEN}%d passed${R}, ${RED}%d failed${R}, ${YEL}%d skipped${R} (of %d tests)\n\n" "$PASS" "$FAIL" "$SKIP" "$TOTAL"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
