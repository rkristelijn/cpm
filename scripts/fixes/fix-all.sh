#!/usr/bin/env bash
# fixes/fix-all.sh — Run all applicable fixes for a repo
# Usage: bash fixes/fix-all.sh [path]
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"
FIXES_DIR="$(cd "$(dirname "$0")" && pwd)"

[ -d "$REPO" ] || {
  echo "  ✗ Directory not found: $REPO"
  exit 1
}

echo ""
echo "  cpm fix — auto-remediation"
echo "  ─────────────────────────────────────────────"
echo "  Target: $REPO"
echo ""

APPLIED=0

# Detect Next.js
if [ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json"; then
  echo "  [nextjs] Detected Next.js project"
  echo ""

  echo "  → Security hardening"
  bash "$FIXES_DIR/nextjs-hardening.sh" "$REPO"
  APPLIED=$((APPLIED + 1))

  echo ""
  echo "  → Test setup"
  bash "$FIXES_DIR/nextjs-test.sh" "$REPO"
  APPLIED=$((APPLIED + 1))

  echo ""
  echo "  → Documentation"
  bash "$FIXES_DIR/nextjs-docs.sh" "$REPO"
  APPLIED=$((APPLIED + 1))

  echo ""
  echo "  → CI pipeline"
  bash "$FIXES_DIR/nextjs-ci.sh" "$REPO"
  APPLIED=$((APPLIED + 1))

  echo ""
  echo "  → Contributing guide"
  bash "$FIXES_DIR/contributing.sh" "$REPO"
  APPLIED=$((APPLIED + 1))

  echo ""
  echo "  → ESLint config"
  bash "$FIXES_DIR/nextjs-eslint.sh" "$REPO"
  APPLIED=$((APPLIED + 1))
fi

# Universal fixes (any repo)
if [ -f "$REPO/package.json" ]; then
  # Package.json best practices
  echo ""
  echo "  → Package.json best practices"
  bash "$FIXES_DIR/package-json.sh" "$REPO"
  APPLIED=$((APPLIED + 1))

  # Pin dependencies
  echo ""
  echo "  → Pin dependencies"
  bash "$FIXES_DIR/pin-deps.sh" "$REPO"
  APPLIED=$((APPLIED + 1))

  # License audit (report only, no auto-fix)
  echo ""
  echo "  → License audit"
  bash "$FIXES_DIR/license-audit.sh" "$REPO"

  # Add LICENSE if missing
  if [ ! -f "$REPO/LICENSE" ] && [ ! -f "$REPO/LICENSE.md" ]; then
    YEAR=$(date +%Y)
    cat >"$REPO/LICENSE" <<EOF
MIT License

Copyright (c) $YEAR

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    echo ""
    echo "  → License"
    echo "  ✓ Added MIT LICENSE"
    APPLIED=$((APPLIED + 1))
  fi
fi

echo ""
echo "  ─────────────────────────────────────────────"
echo "  Done. $APPLIED fixes applied."
echo ""
