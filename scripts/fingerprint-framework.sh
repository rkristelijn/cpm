#!/usr/bin/env bash
# scripts/fingerprint-framework.sh — Generate and persist API coupling fingerprints.
#
# Clones a framework at a specific version, extracts how it uses each flupke-replaceable
# package, and stores the fingerprint. Diffs between versions show API surface changes.
#
# Usage:
#   ./scripts/fingerprint-framework.sh express 5.2.1
#   ./scripts/fingerprint-framework.sh express 4.21.2
#   ./scripts/fingerprint-framework.sh --diff express 4.21.2 5.2.1
#   ./scripts/fingerprint-framework.sh --all          # fingerprint all supported frameworks
#
# Fingerprints stored in: data/fingerprints/<framework>/<version>.json
set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${FINGERPRINT_DIR:-data/fingerprints}"
TMP_DIR=".tmp/frameworks"

# Supported frameworks: name → npm package → git repo
declare -A REPOS=(
  [express]="https://github.com/expressjs/express.git"
  [nestjs]="https://github.com/nestjs/nest.git"
  [jest]="https://github.com/jestjs/jest.git"
  [nuxt]="https://github.com/nuxt/nuxt.git"
  [next]="https://github.com/vercel/next.js.git"
)

# Supported versions (current + current-1)
declare -A VERSIONS=(
  [express]="4.21.2 5.2.1"
  [nestjs]="10.4.15 11.1.24"
  [jest]="29.7.0 30.4.2"
  [nuxt]="3.16.2 4.4.6"
  [next]="15.3.3 16.2.6"
)

# --- Functions ---

clone_at_version() {
  local name="$1" version="$2"
  local repo="${REPOS[$name]}"
  local dir="$TMP_DIR/$name-$version"

  if [ -d "$dir" ]; then
    echo "  Using cached: $dir" >&2
    return
  fi

  echo "  Cloning $name@$version..." >&2
  mkdir -p "$TMP_DIR"
  git clone --depth 1 --branch "v$version" "$repo" "$dir" 2>/dev/null || \
  git clone --depth 1 --branch "$version" "$repo" "$dir" 2>/dev/null || {
    echo "  Warning: could not clone $name@$version, trying without tag..." >&2
    git clone --depth 1 "$repo" "$dir" 2>/dev/null || { echo "  FAILED to clone $name" >&2; return 1; }
  }
}

get_flupke_packages() {
  # List all flupke package names
  if [ -d "packages" ]; then
    ls -d packages/*/package.json 2>/dev/null | sed 's|packages/||;s|/package.json||'
  else
    echo "debug ms etag cookie fresh parseurl on-finished once depd vary statuses"
  fi
}

fingerprint() {
  local name="$1" version="$2"
  local dir="$TMP_DIR/$name-$version"
  local out="$DATA_DIR/$name/$version.json"

  clone_at_version "$name" "$version" || return 1

  echo "  Extracting coupling for $name@$version..." >&2

  mkdir -p "$DATA_DIR/$name"
  local all_results="[]"
  local pkg_count=0

  for pkg in $(get_flupke_packages); do
    local result
    result=$("$SCRIPT_DIR/extract-coupling.sh" "$pkg" "$dir" 2>/dev/null || echo "[]")
    if [ "$result" != "[]" ]; then
      # Merge into all_results with package metadata
      all_results=$(echo "$all_results" | node -e "
        const fs=require('fs');
        const existing=JSON.parse(fs.readFileSync('/dev/stdin','utf8'));
        const newData=JSON.parse(process.argv[1]).map(e=>({...e, package:'$pkg'}));
        console.log(JSON.stringify([...existing,...newData]));
      " "$result")
      pkg_count=$((pkg_count + 1))
    fi
  done

  # Write fingerprint with metadata
  node -e "
    const data = JSON.parse(process.argv[1]);
    const fingerprint = {
      framework: '$name',
      version: '$version',
      generated: new Date().toISOString(),
      packages_used: $pkg_count,
      total_signatures: data.length,
      signatures: data
    };
    console.log(JSON.stringify(fingerprint, null, 2));
  " "$all_results" > "$out"

  echo "  Written: $out ($pkg_count packages, $(echo "$all_results" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).length)") signatures)" >&2
}

diff_versions() {
  local name="$1" v1="$2" v2="$3"
  local f1="$DATA_DIR/$name/$v1.json"
  local f2="$DATA_DIR/$name/$v2.json"

  if [ ! -f "$f1" ]; then echo "No fingerprint for $name@$v1. Run: $0 $name $v1" >&2; exit 1; fi
  if [ ! -f "$f2" ]; then echo "No fingerprint for $name@$v2. Run: $0 $name $v2" >&2; exit 1; fi

  node -e "
    const fs = require('fs');
    const a = JSON.parse(fs.readFileSync('$f1', 'utf8'));
    const b = JSON.parse(fs.readFileSync('$f2', 'utf8'));

    const sigA = new Set(a.signatures.map(s => s.package + '|' + s.signature));
    const sigB = new Set(b.signatures.map(s => s.package + '|' + s.signature));

    const added = [...sigB].filter(s => !sigA.has(s));
    const removed = [...sigA].filter(s => !sigB.has(s));
    const unchanged = [...sigA].filter(s => sigB.has(s));

    console.log('=== ${name} API surface diff: ${v1} → ${v2} ===');
    console.log('');
    console.log('Unchanged: ' + unchanged.length);
    console.log('Added:     ' + added.length);
    console.log('Removed:   ' + removed.length);

    if (added.length) {
      console.log('');
      console.log('+ New signatures (must support):');
      added.forEach(s => console.log('  + ' + s));
    }
    if (removed.length) {
      console.log('');
      console.log('- Removed signatures (can deprecate):');
      removed.forEach(s => console.log('  - ' + s));
    }
  "
}

# --- Main ---

case "${1:-}" in
  --diff)
    diff_versions "${2:?}" "${3:?}" "${4:?}"
    ;;
  --all)
    for name in "${!VERSIONS[@]}"; do
      for version in ${VERSIONS[$name]}; do
        echo "=== $name@$version ===" >&2
        fingerprint "$name" "$version" || true
      done
    done
    ;;
  --help|-h)
    head -13 "$0" | tail -10
    ;;
  *)
    NAME="${1:?Usage: $0 <framework> <version> | --diff <fw> <v1> <v2> | --all}"
    VERSION="${2:?Usage: $0 <framework> <version>}"
    fingerprint "$NAME" "$VERSION"
    ;;
esac
