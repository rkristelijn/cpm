#!/usr/bin/env bash
# scripts/routes.sh — Discover all URL routes and API endpoints
# Usage: bash scripts/routes.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__|\.test\.|\.spec\."

FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.go" -o -name "*.java" 2>/dev/null | grep -vE "$EXCLUDE" || true)
[ -z "$FILES" ] && { echo "  No source files found"; exit 0; }

echo ""
echo "  ■ Routes & Endpoints: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# === 1. Next.js App Router (file-based routing) ===
if [ -d "$REPO/app" ]; then
  echo "  Frontend routes (Next.js App Router):"
  find "$REPO/app" -name "page.tsx" -o -name "page.jsx" -o -name "page.ts" -o -name "page.js" 2>/dev/null | \
    sed "s|$REPO/app||; s|/page\.[tj]sx\?$||; s|^$|/|" | sort | sed 's/^/    /'
  echo ""
  # API routes
  API_ROUTES=$(find "$REPO/app" -path "*/api/*/route.*" 2>/dev/null)
  if [ -n "$API_ROUTES" ]; then
    echo "  API routes (Next.js):"
    echo "$API_ROUTES" | sed "s|$REPO/app||; s|/route\.[tj]sx\?$||" | sort | while read -r route; do
      METHODS=$(grep -oE "export.*(GET|POST|PUT|DELETE|PATCH)" "$REPO/app${route}/route."* 2>/dev/null | grep -oE "GET|POST|PUT|DELETE|PATCH" | sort -u | tr '\n' ',' | sed 's/,$//')
      printf "    %-6s %s\n" "${METHODS:-???}" "$route"
    done
    echo ""
  fi
fi

# === 2. Express/Fastify/Koa routes ===
EXPRESS_ROUTES=$(echo "$FILES" | xargs grep -hn "\.\(get\|post\|put\|delete\|patch\)(['\"]/" 2>/dev/null | \
  grep -vE "test|spec|mock" | grep -oE "\.(get|post|put|delete|patch)\(['\"/][^'\"]*['\"]" | \
  sed "s/^\.\(.*\)('/\U\1\E /; s/'$//; s/\"$//" | sort -u || true)
if [ -n "$EXPRESS_ROUTES" ]; then
  echo "  API routes (Express/Fastify):"
  echo "$EXPRESS_ROUTES" | sed 's/^/    /' | head -20
  echo ""
fi

# === 3. Angular routes ===
ANGULAR_ROUTES=$(echo "$FILES" | xargs grep -hA1 "path:" 2>/dev/null | \
  grep -oE "path:\s*'[^']*'" | sed "s/path: '//; s/'$//" | sort -u || true)
if [ -n "$ANGULAR_ROUTES" ] && [ -f "$REPO/angular.json" ]; then
  echo "  Frontend routes (Angular):"
  echo "$ANGULAR_ROUTES" | sed 's/^/    \//' | head -20
  echo ""
fi

# === 4. React Router routes ===
RR_ROUTES=$(echo "$FILES" | xargs grep -ohE "path=['\"][^'\"]*['\"]" 2>/dev/null | \
  sed "s/path=['\"]//; s/['\"]$//" | sort -u || true)
if [ -n "$RR_ROUTES" ] && [ -z "$ANGULAR_ROUTES" ]; then
  echo "  Frontend routes (React Router):"
  echo "$RR_ROUTES" | sed 's/^/    /' | head -20
  echo ""
fi

# === 5. Python Flask/Django/FastAPI ===
PY_ROUTES=$(echo "$FILES" | xargs grep -ohE "@(app|router)\.(get|post|put|delete|route)\(['\"][^'\"]*['\"]|path\(['\"][^'\"]*['\"]|url\(['\"][^'\"]*['\"]" 2>/dev/null | \
  grep -oE "['\"][^'\"]*['\"]" | sed "s/['\"]//g" | sort -u || true)
if [ -n "$PY_ROUTES" ]; then
  echo "  API routes (Python):"
  echo "$PY_ROUTES" | sed 's/^/    /' | head -20
  echo ""
fi

# === 6. Summary ===
TOTAL=0
[ -d "$REPO/app" ] && TOTAL=$((TOTAL + $(find "$REPO/app" -name "page.*" 2>/dev/null | wc -l | tr -d ' ')))
[ -n "$EXPRESS_ROUTES" ] && TOTAL=$((TOTAL + $(echo "$EXPRESS_ROUTES" | wc -l | tr -d ' ')))
[ -n "$RR_ROUTES" ] && TOTAL=$((TOTAL + $(echo "$RR_ROUTES" | wc -l | tr -d ' ')))
[ -n "$PY_ROUTES" ] && TOTAL=$((TOTAL + $(echo "$PY_ROUTES" | wc -l | tr -d ' ')))
echo "  Total: ~$TOTAL routes detected"
echo ""
