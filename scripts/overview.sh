#!/usr/bin/env bash
# scripts/overview.sh — Instant codebase understanding without docs
# Usage: bash scripts/overview.sh [path]
# Answers: What is this? What does it do? How is it structured? Where do I start?
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__|\.cache"

echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │         cpm overview — instant insight       │"
echo "  └─────────────────────────────────────────────┘"
echo ""

# === 1. IDENTITY: What is this project? ===
echo "  ■ Identity"
NAME=""
DESC=""
if [ -f "$REPO/package.json" ]; then
  NAME=$(grep -oE '"name"\s*:\s*"[^"]*"' "$REPO/package.json" | head -1 | sed 's/.*: *"//;s/"//')
  DESC=$(grep -oE '"description"\s*:\s*"[^"]*"' "$REPO/package.json" | head -1 | sed 's/.*: *"//;s/"//')
elif [ -f "$REPO/cpm.toml" ]; then
  NAME=$(grep -oE 'name\s*=\s*"[^"]*"' "$REPO/cpm.toml" | head -1 | sed 's/.*= *"//;s/"//')
elif [ -f "$REPO/Cargo.toml" ]; then
  NAME=$(grep -oE 'name\s*=\s*"[^"]*"' "$REPO/Cargo.toml" | head -1 | sed 's/.*= *"//;s/"//')
elif [ -f "$REPO/pom.xml" ]; then
  NAME=$(grep -oE '<artifactId>[^<]*' "$REPO/pom.xml" | head -1 | sed 's/<artifactId>//')
fi
[ -z "$NAME" ] && NAME=$(basename "$(cd "$REPO" && pwd)")
printf "    Name: %s\n" "$NAME"
[ -n "$DESC" ] && printf "    Desc: %s\n" "$DESC"

# === 2. STACK: What technologies? ===
echo ""
echo "  ■ Stack"
STACK=""
[ -f "$REPO/package.json" ] && STACK="$STACK Node.js"
[ -f "$REPO/tsconfig.json" ] && STACK="$STACK TypeScript"
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && STACK="$STACK Next.js"
[ -f "$REPO/angular.json" ] && STACK="$STACK Angular"
[ -f "$REPO/vite.config.ts" ] && STACK="$STACK Vite"
[ -f "$REPO/Cargo.toml" ] && STACK="$STACK Rust"
[ -f "$REPO/go.mod" ] && STACK="$STACK Go"
[ -f "$REPO/pom.xml" ] && STACK="$STACK Java/Maven"
[ -f "$REPO/Makefile" ] && grep -q "g++" "$REPO/Makefile" 2>/dev/null && STACK="$STACK C++"
[ -f "$REPO/requirements.txt" ] || [ -f "$REPO/pyproject.toml" ] && STACK="$STACK Python"
[ -f "$REPO/Dockerfile" ] && STACK="$STACK Docker"
[ -f "$REPO/terraform" ] || find "$REPO" -name "*.tf" -maxdepth 2 2>/dev/null | head -1 | grep -q . && STACK="$STACK Terraform"
printf "    %s\n" "${STACK:-Unknown}"

# === 3. ENTRY POINTS: Where does it start? ===
echo ""
echo "  ■ Entry points"
[ -f "$REPO/src/main.ts" ] && echo "    → src/main.ts"
[ -f "$REPO/src/main.cpp" ] && echo "    → src/main.cpp"
[ -f "$REPO/src/index.ts" ] && echo "    → src/index.ts"
[ -f "$REPO/src/index.js" ] && echo "    → src/index.js"
[ -f "$REPO/src/app.ts" ] && echo "    → src/app.ts"
[ -f "$REPO/app/layout.tsx" ] && echo "    → app/layout.tsx (Next.js root)"
[ -f "$REPO/app/page.tsx" ] && echo "    → app/page.tsx (Next.js home)"
[ -f "$REPO/src/main.rs" ] && echo "    → src/main.rs"
[ -f "$REPO/cmd/main.go" ] && echo "    → cmd/main.go"
[ -f "$REPO/main.go" ] && echo "    → main.go"
if [ -f "$REPO/package.json" ]; then
  MAIN=$(grep -oE '"main"\s*:\s*"[^"]*"' "$REPO/package.json" | sed 's/.*: *"//;s/"//')
  [ -n "$MAIN" ] && echo "    → $MAIN (package.json main)"
  START=$(grep -oE '"start"\s*:\s*"[^"]*"' "$REPO/package.json" | sed 's/.*: *"//;s/"//')
  [ -n "$START" ] && echo "    → npm start: $START"
fi

# === 4. STRUCTURE: How is it organized? ===
echo ""
echo "  ■ Structure (top-level)"
find "$REPO" -maxdepth 1 -type d | grep -vE "^\.$|$EXCLUDE" | sort | while read -r dir; do
  d=$(basename "$dir")
  [[ "$d" == "." ]] && continue
  [[ "$d" == ".git" ]] && continue
  COUNT=$(find "$dir" -type f 2>/dev/null | grep -vE "$EXCLUDE" | wc -l | tr -d ' ')
  printf "    %-20s %s files\n" "$d/" "$COUNT"
done

# === 5. KEY FILES: What matters most? ===
echo ""
echo "  ■ Key files"
for f in README.md CONTRIBUTING.md CHANGELOG.md Makefile Dockerfile docker-compose.yml \
         .env.example cpm.toml package.json tsconfig.json angular.json nx.json \
         Cargo.toml go.mod pom.xml; do
  [ -f "$REPO/$f" ] && echo "    ✓ $f"
done

# === 6. PUBLIC API: What does it export/expose? ===
echo ""
echo "  ■ Public API / Commands"
if [ -f "$REPO/package.json" ]; then
  echo "    Scripts:"
  awk '/"scripts"/{found=1; next} found && /}/{found=0} found && /"/' "$REPO/package.json" | \
    grep -oE '"[^"]+"' | head -1 | sed 's/"//g' > /dev/null  # skip
  awk '/"scripts"/{found=1; next} found && /}/{found=0} found' "$REPO/package.json" | \
    grep -oE '"[a-z][a-z:_-]*"' | sed 's/"//g; s/^/      /' | head -10
fi
if [ -f "$REPO/Makefile" ]; then
  echo "    Make targets:"
  grep -E "^[a-zA-Z_-]+:" "$REPO/Makefile" | sed 's/:.*//; s/^/      /' | head -10
fi

# === 7. HOTSPOTS: Largest/most complex files ===
echo ""
echo "  ■ Hotspots (largest files)"
find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.cpp" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" 2>/dev/null | \
  grep -vE "$EXCLUDE|\.test\.|\.spec\.|\.min\." | \
  xargs wc -l 2>/dev/null | sort -rn | head -6 | tail -5 | \
  awk '{printf "    %5d lines  %s\n", $1, $2}'

# === 8. DEPENDENCIES: What does it rely on? ===
echo ""
echo "  ■ Dependencies (top 8)"
if [ -f "$REPO/package.json" ]; then
  # Extract just the dependency names between "dependencies": { ... }
  awk '/"dependencies"/{found=1; next} found && /}/{found=0} found && /"/' "$REPO/package.json" | \
    grep -oE '"[^"]+":' | sed 's/"//g; s/://; s/^/    /' | head -8
fi

# === 9. RECENT ACTIVITY: What changed last? ===
echo ""
echo "  ■ Recent activity (last 5 commits)"
(cd "$REPO" && git log --oneline -5 2>/dev/null | sed 's/^/    /' || echo "    (not a git repo)")

echo ""
