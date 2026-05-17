#!/usr/bin/env bash
# scripts/runtime.sh — Detect runtime versions, EOL status, framework versions
# Usage: bash scripts/runtime.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"

echo ""
echo "  ■ Runtime & Versions: $(basename "$(cd "$REPO" && pwd)")"
echo ""

found() { printf "    %-25s %s\n" "$1" "$2"; }
warn()  { printf "    ⚠ %-23s %s\n" "$1" "$2"; }

# === Node.js ===
if [ -f "$REPO/package.json" ]; then
  echo "  Node.js:"
  # Pinned version
  [ -f "$REPO/.nvmrc" ] && found "Pinned (.nvmrc):" "$(cat "$REPO/.nvmrc" | tr -d '[:space:]')"
  [ -f "$REPO/.node-version" ] && found "Pinned:" "$(cat "$REPO/.node-version" | tr -d '[:space:]')"
  ENGINES=$(grep -oE '"node"[^,}]*' "$REPO/package.json" 2>/dev/null | sed 's/.*: *"//;s/"//')
  [ -n "$ENGINES" ] && found "engines.node:" "$ENGINES"
  # EOL check
  VER=$(cat "$REPO/.nvmrc" "$REPO/.node-version" 2>/dev/null | head -1 | tr -d 'v[:space:]' | cut -d. -f1)
  [ -n "$VER" ] && [ "$VER" -lt 20 ] 2>/dev/null && warn "Node $VER is EOL" "Upgrade to 20+"
  echo ""

  # Package manager
  echo "  Package Manager:"
  [ -f "$REPO/pnpm-lock.yaml" ] && found "pnpm" ""
  [ -f "$REPO/yarn.lock" ] && found "yarn" ""
  [ -f "$REPO/package-lock.json" ] && found "npm" ""
  [ -f "$REPO/bun.lockb" ] && found "bun" ""
  echo ""

  # Framework versions from package.json
  echo "  Framework Versions:"
  for pkg in "@angular/core" "react" "next" "vue" "nuxt" "svelte" "@nestjs/core" "express" "fastify"; do
    VER=$(grep -oE "\"$pkg\"[^,}]*" "$REPO/package.json" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\|[~^]*[0-9]+\.[0-9]+" | head -1)
    [ -n "$VER" ] && found "$pkg" "$VER"
  done
  echo ""

  # TypeScript version
  TS_VER=$(grep -oE '"typescript"[^,}]*' "$REPO/package.json" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+" | head -1)
  if [ -n "$TS_VER" ]; then
    echo "  TypeScript:"
    found "Version:" "$TS_VER"
    MAJOR=$(echo "$TS_VER" | cut -d. -f1)
    [ "$MAJOR" -lt 5 ] 2>/dev/null && warn "TypeScript $TS_VER" "Consider upgrading to 5.x"
    echo ""
  fi
fi

# === Python ===
if [ -f "$REPO/requirements.txt" ] || [ -f "$REPO/pyproject.toml" ]; then
  echo "  Python:"
  [ -f "$REPO/.python-version" ] && found "Pinned:" "$(cat "$REPO/.python-version")"
  [ -f "$REPO/pyproject.toml" ] && grep -oE 'python_requires.*"[^"]*"' "$REPO/pyproject.toml" 2>/dev/null | sed 's/.*"//;s/"//' | head -1 | xargs -I{} printf "    requires: %s\n" "{}"
  echo ""
fi

# === Go ===
if [ -f "$REPO/go.mod" ]; then
  echo "  Go:"
  GO_VER=$(grep -oE "^go [0-9.]+" "$REPO/go.mod" | sed 's/go //')
  [ -n "$GO_VER" ] && found "Version:" "$GO_VER"
  echo ""
fi

# === Rust ===
if [ -f "$REPO/Cargo.toml" ]; then
  echo "  Rust:"
  RUST_ED=$(grep -oE 'edition = "[0-9]+"' "$REPO/Cargo.toml" | grep -oE "[0-9]+")
  [ -n "$RUST_ED" ] && found "Edition:" "$RUST_ED"
  echo ""
fi

# === Docker ===
if [ -f "$REPO/Dockerfile" ]; then
  echo "  Docker:"
  BASE=$(grep -E "^FROM " "$REPO/Dockerfile" | head -1 | sed 's/FROM //')
  [ -n "$BASE" ] && found "Base image:" "$BASE"
  echo ""
fi
echo ""
