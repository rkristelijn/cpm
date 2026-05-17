#!/usr/bin/env bash
# scripts/howtorun.sh — Detect how to build, run, and test any project
# Usage: bash scripts/howtorun.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"

echo ""
echo "  ■ How to run: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# --- Prerequisites ---
echo "  Prerequisites:"
[ -f "$REPO/.nvmrc" ] && echo "    nvm use  (Node $(cat "$REPO/.nvmrc" | tr -d '[:space:]'))"
[ -f "$REPO/.node-version" ] && echo "    nvm use  (Node $(cat "$REPO/.node-version" | tr -d '[:space:]'))"
[ -f "$REPO/.python-version" ] && echo "    Python $(cat "$REPO/.python-version")"
[ -f "$REPO/.env.example" ] && echo "    cp .env.example .env  (configure environment)"
[ -f "$REPO/.env.local.example" ] && echo "    cp .env.local.example .env.local"
[ -f "$REPO/docker-compose.yml" ] && echo "    docker compose up -d  (start services)"
echo ""

# --- Install ---
echo "  Install:"
if [ -f "$REPO/package-lock.json" ]; then
  echo "    npm ci"
elif [ -f "$REPO/pnpm-lock.yaml" ]; then
  echo "    pnpm install"
elif [ -f "$REPO/yarn.lock" ]; then
  echo "    yarn install"
elif [ -f "$REPO/package.json" ]; then
  echo "    npm install"
elif [ -f "$REPO/Cargo.toml" ]; then
  echo "    cargo build"
elif [ -f "$REPO/go.mod" ]; then
  echo "    go mod download"
elif [ -f "$REPO/requirements.txt" ]; then
  echo "    pip install -r requirements.txt"
elif [ -f "$REPO/Gemfile" ]; then
  echo "    bundle install"
elif [ -f "$REPO/Makefile" ]; then
  echo "    make install  (or: make)"
else
  echo "    (no package manager detected)"
fi
echo ""

# --- Run / Dev ---
echo "  Run (dev):"
if [ -f "$REPO/package.json" ]; then
  DEV=$(grep -oE '"dev"\s*:\s*"[^"]*"' "$REPO/package.json" | sed 's/.*: *"//;s/"//')
  START=$(grep -oE '"start"\s*:\s*"[^"]*"' "$REPO/package.json" | sed 's/.*: *"//;s/"//')
  [ -n "$DEV" ] && echo "    npm run dev  ($DEV)"
  [ -n "$START" ] && [ -z "$DEV" ] && echo "    npm start  ($START)"
  [ -z "$DEV" ] && [ -z "$START" ] && echo "    (no dev/start script in package.json)"
elif [ -f "$REPO/Makefile" ]; then
  grep -q "^run:" "$REPO/Makefile" && echo "    make run"
  grep -q "^dev:" "$REPO/Makefile" && echo "    make dev"
  ! grep -q "^run:\|^dev:" "$REPO/Makefile" && echo "    make  (default target)"
elif [ -f "$REPO/Cargo.toml" ]; then
  echo "    cargo run"
elif [ -f "$REPO/go.mod" ]; then
  MAIN=$(find "$REPO" -name "main.go" -maxdepth 3 | head -1)
  [ -n "$MAIN" ] && echo "    go run $MAIN"
elif [ -f "$REPO/manage.py" ]; then
  echo "    python manage.py runserver"
fi
echo ""

# --- Test ---
echo "  Test:"
if [ -f "$REPO/package.json" ]; then
  TEST=$(grep -oE '"test"\s*:\s*"[^"]*"' "$REPO/package.json" | sed 's/.*: *"//;s/"//')
  [ -n "$TEST" ] && echo "    npm test  ($TEST)"
  [ -z "$TEST" ] && echo "    (no test script)"
elif [ -f "$REPO/Makefile" ] && grep -q "^test:" "$REPO/Makefile"; then
  echo "    make test"
elif [ -f "$REPO/Cargo.toml" ]; then
  echo "    cargo test"
elif [ -f "$REPO/go.mod" ]; then
  echo "    go test ./..."
fi
echo ""

# --- Build ---
echo "  Build:"
if [ -f "$REPO/package.json" ]; then
  BUILD=$(grep -oE '"build"\s*:\s*"[^"]*"' "$REPO/package.json" | sed 's/.*: *"//;s/"//')
  [ -n "$BUILD" ] && echo "    npm run build  ($BUILD)"
elif [ -f "$REPO/Makefile" ] && grep -q "^build:" "$REPO/Makefile"; then
  echo "    make build"
elif [ -f "$REPO/Cargo.toml" ]; then
  echo "    cargo build --release"
elif [ -f "$REPO/Dockerfile" ]; then
  echo "    docker build -t $(basename "$REPO") ."
fi
echo ""

# --- Useful URLs ---
if [ -f "$REPO/package.json" ]; then
  PORT=$(grep -oE "PORT[=:]\s*[0-9]+" "$REPO/package.json" "$REPO/.env" "$REPO/.env.example" 2>/dev/null | grep -oE "[0-9]+" | head -1)
  [ -n "$PORT" ] && echo "  Open: http://localhost:$PORT"
  [ -z "$PORT" ] && grep -q "next\|vite\|react-scripts" "$REPO/package.json" 2>/dev/null && echo "  Open: http://localhost:3000 (likely)"
fi
echo ""
