#!/usr/bin/env bash
# record-tapes.sh — Generate GIF recordings from VHS tape files.
# Usage: bash scripts/dev/record-tapes.sh [--force]
#
# Requires: brew install charmbracelet/tap/vhs

set -o errexit
set -o nounset
set -o pipefail

FORCE="${1:-}"

if ! command -v vhs >/dev/null 2>&1; then
  echo "ERROR: vhs not installed. Run: brew install charmbracelet/tap/vhs"
  exit 1
fi

if [[ ! -x "./cpm" ]]; then
  echo "ERROR: ./cpm not found — run make build first"
  exit 1
fi

mkdir -p docs/features

recorded=0
skipped=0

for tape in tests/tapes/*.tape; do
  name=$(basename "$tape" .tape)
  gif="docs/features/${name}.gif"

  if [[ -f "$gif" && "$FORCE" != "--force" ]]; then
    echo "  skip $name (exists, use --force to re-record)"
    skipped=$((skipped + 1))
    continue
  fi

  echo "  recording $name..."
  vhs "$tape" 2>/dev/null
  recorded=$((recorded + 1))
done

echo ""
echo "  Done: $recorded recorded, $skipped skipped"
echo "  Output: docs/features/*.gif"
