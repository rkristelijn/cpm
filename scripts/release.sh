#!/usr/bin/env bash
# scripts/release.sh — version bump logic (used by make + CI)
set -o errexit -o nounset -o pipefail

COMMANDS_H="src/commands/commands.h"
TOML="cpm.toml"
CHANGELOG="CHANGELOG.md"

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
  # 1. cpm.toml — source of truth for the Makefile-baked binary version
  sed -i '' "s/^version = \".*\"/version = \"${version}\"/" "$TOML" 2>/dev/null ||
    sed -i "s/^version = \".*\"/version = \"${version}\"/" "$TOML"

  # 2. src/commands/commands.h — keep the #ifndef fallback in sync so
  #    source-only builds (without the Makefile -DCPM_VERSION) report the
  #    right version instead of a stale hardcoded one.
  if [ -f "$COMMANDS_H" ]; then
    sed -i '' "s/#define CPM_VERSION \".*\"/#define CPM_VERSION \"${version}\"/" "$COMMANDS_H" 2>/dev/null ||
      sed -i "s/#define CPM_VERSION \".*\"/#define CPM_VERSION \"${version}\"/" "$COMMANDS_H"
  fi

  # 3. CHANGELOG.md — roll the "## [Unreleased]" section into a dated
  #    "## [version] — YYYY-MM-DD" section, then re-add an empty Unreleased.
  #    Idempotent: only acts if an [Unreleased] heading exists and the
  #    version section doesn't already exist.
  if [ -f "$CHANGELOG" ] && grep -q '^## \[Unreleased\]' "$CHANGELOG" &&
    ! grep -q "^## \[${version}\]" "$CHANGELOG"; then
    local today
    today=$(date +%Y-%m-%d)
    # Replace the Unreleased heading with a fresh Unreleased + the dated section.
    # Uses awk to insert after the matched line without touching other content.
    awk -v ver="$version" -v day="$today" '
      /^## \[Unreleased\]/ && !done {
        print "## [Unreleased]"
        print ""
        print "## [" ver "] — " day
        done = 1
        next
      }
      { print }
    ' "$CHANGELOG" >"${CHANGELOG}.tmp" && mv "${CHANGELOG}.tmp" "$CHANGELOG"
  fi
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
  # Calculate next version from the LAST TAG, not from cpm.toml
  LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
  LAST_TAG_VERSION="${LAST_TAG#v}"
  VERSION=$(next_version "$LAST_TAG_VERSION" "$BUMP")
  # If cpm.toml already has a higher or equal version (manual bump), respect it
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
  # Calculate next version from the LAST TAG, not from cpm.toml
  LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
  LAST_TAG_VERSION="${LAST_TAG#v}"
  VERSION=$(next_version "$LAST_TAG_VERSION" "$BUMP")
  # If cpm.toml already has a higher or equal version (manual bump), respect it
  HIGHER=$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)
  if [ "$HIGHER" = "$CURRENT" ] && [ "$CURRENT" != "$VERSION" ]; then
    VERSION="$CURRENT"
  fi
  apply_version "$VERSION"
  echo "$VERSION"
  ;;
*)
  echo "Usage: $0 [version|bump|apply]"
  exit 1
  ;;
esac
