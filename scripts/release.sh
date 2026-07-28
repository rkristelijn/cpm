#!/usr/bin/env bash
# scripts/release.sh — version bump logic (used by make + CI)
set -o errexit -o nounset -o pipefail

COMMANDS_H="src/commands/commands.h"
TOML="cpm.toml"

current_version() {
  grep '^version = ' "$TOML" | sed 's/.*"\(.*\)".*/\1/'
}

commits_since_tag() {
  local last_tag
  last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
  if [ -z "$last_tag" ]; then
    git log --oneline
  else
    git log "${last_tag}..HEAD" --oneline
  fi
}

detect_bump() {
  local commits="$1"
  if echo "$commits" | grep -qiE "^[a-f0-9]+ \w+!:|BREAKING CHANGE"; then
    echo "major"
  elif echo "$commits" | grep -qiE "^[a-f0-9]+ feat"; then
    echo "minor"
  else
    echo "patch"
  fi
}

next_version() {
  local current="$1" bump="$2"
  IFS='.' read -r major minor patch <<<"$current"
  case "$bump" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch) patch=$((patch + 1)) ;;
  esac
  echo "${major}.${minor}.${patch}"
}

apply_version() {
  local version="$1"
  sed -i '' "s/^version = \".*\"/version = \"${version}\"/" "$TOML" 2>/dev/null ||
    sed -i "s/^version = \".*\"/version = \"${version}\"/" "$TOML"
}

case "${1:-bump}" in
version)
  current_version
  ;;
bump)
  CURRENT=$(current_version)
  COMMITS=$(commits_since_tag)
  if [ -z "$COMMITS" ]; then
    echo "No commits since last tag — nothing to release"
    exit 0
  fi
  BUMP=$(detect_bump "$COMMITS")
  VERSION=$(next_version "$CURRENT" "$BUMP")
  # If cpm.toml already has a higher version (manual bump), respect it
  HIGHER=$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)
  if [ "$HIGHER" = "$CURRENT" ] && [ "$CURRENT" != "$VERSION" ]; then
    VERSION="$CURRENT"
    BUMP="manual"
  fi
  echo "${CURRENT} → ${VERSION} (${BUMP})"
  echo ""
  echo "Commits:"
  echo "$COMMITS"
  ;;
apply)
  CURRENT=$(current_version)
  COMMITS=$(commits_since_tag)
  if [ -z "$COMMITS" ]; then
    echo "No commits since last tag — nothing to release"
    exit 1
  fi
  BUMP=$(detect_bump "$COMMITS")
  VERSION=$(next_version "$CURRENT" "$BUMP")
  # If cpm.toml already has a higher version (manual bump), respect it
  if [ "$CURRENT" != "$VERSION" ]; then
    # Compare: if CURRENT > VERSION, keep CURRENT
    HIGHER=$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)
    if [ "$HIGHER" = "$CURRENT" ] && [ "$CURRENT" != "$VERSION" ]; then
      VERSION="$CURRENT"
    fi
  fi
  apply_version "$VERSION"
  echo "$VERSION"
  ;;
*)
  echo "Usage: $0 [version|bump|apply]"
  exit 1
  ;;
esac
