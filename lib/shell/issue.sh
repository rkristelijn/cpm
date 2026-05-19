#!/usr/bin/env bash
# issue.sh — Local-first issue tracking with optional remote sync.
# Usage: cpm issue "title"       — create issue
#        cpm issue               — list open issues
#        cpm issue show <slug>   — show issue
#        cpm issue close <slug>  — close issue
#        cpm issue sync          — push/pull to remote
#        cpm issue branch <slug> — create branch from issue
set -o errexit
set -o nounset
set -o pipefail

ISSUE_DIR="${ISSUE_DIR:-docs/issues}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure directories exist
mkdir -p "$ISSUE_DIR/open" "$ISSUE_DIR/closed"

# Slugify a title
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# Load provider (from cpm.toml or default to local)
load_provider() {
  local provider="local"
  if [[ -f cpm.toml ]]; then
    provider=$(grep -A5 '^\[issues\]' cpm.toml 2>/dev/null | sed -n 's/^provider *= *"\(.*\)"/\1/p' || echo "local")
    [[ -z "$provider" ]] && provider="local"
  fi
  local provider_file="$SCRIPT_DIR/providers/${provider}.sh"
  if [[ -f "$provider_file" ]]; then
    source "$provider_file"
  fi
}

# --- Commands ---

cmd_create() {
  local title="" type="feat"

  # Parse: "fix: title" or just "title"
  if [[ "$*" =~ ^(fix|feat|chore|refactor|docs|perf):\ (.+)$ ]]; then
    type="${BASH_REMATCH[1]}"
    title="${BASH_REMATCH[2]}"
  else
    title="$*"
  fi

  [[ -z "$title" ]] && { echo "  Usage: cpm issue \"[type:] title\""; exit 1; }

  local slug
  slug=$(slugify "$title")
  local file="$ISSUE_DIR/open/${slug}.md"

  if [[ -f "$file" ]]; then
    echo "  Issue already exists: $file"
    exit 1
  fi

  local target
  target=$(grep -A5 '^\[process\]' cpm.toml 2>/dev/null | sed -n 's/^maturity-target *= *//p' | tr -d ' ')
  target="${target:-2}"

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

  cat >"$file" <<EOF
---
title: $title
type: $type
created: $now
labels: [$type]
remote:
---

EOF

  # Template body based on type + maturity level
  case "$type" in
    fix)
      cat >>"$file" <<'EOF'
## Problem

## Reproduce

1. ...

## Expected vs actual

- Expected: ...
- Actual: ...

## Value

<!-- Which ISO 25010 quality characteristic does this fix? -->
- Quality characteristic:

EOF
      ((target >= 3)) && cat >>"$file" <<'EOF'
## Acceptance criteria

- [ ] <!-- AC1: bug no longer reproducible → test: test_e2e_xxx -->

## Done when

- [ ] Bug fixed (acceptance criteria met)
- [ ] Test reproduces the issue (regression test)
- [ ] No regression (existing tests pass)

## References

<!-- @see ADR-xxx, closes #N -->
EOF
      ;;
    feat)
      cat >>"$file" <<'EOF'
## What

## Why

## Value

<!-- Which ISO 25010 quality characteristic does this improve? -->
<!-- Options: Maintainability | Security | Reliability | Portability | -->
<!-- Functional Suitability | Performance Efficiency | Compatibility | Usability -->
- Quality characteristic:
- Stakeholder benefit:

EOF
      ((target >= 3)) && cat >>"$file" <<'EOF'
## Acceptance criteria

<!-- Testable criteria linked to E2E tests. Each criterion = one assertion. -->
- [ ] <!-- AC1: describe observable behavior → test: test_e2e_xxx -->
- [ ] <!-- AC2: describe observable behavior → test: test_e2e_xxx -->

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

<!-- @see ADR-xxx (decision), @see DES-xxx (design) -->
EOF
      ;;
    *)
      cat >>"$file" <<'EOF'
## What

EOF
      ;;
  esac

  echo "  Created: $file"
  echo "  Type: $type | Template: level $target"
}

cmd_list() {
  local count=0
  echo ""
  for f in "$ISSUE_DIR"/open/*.md; do
    [[ -f "$f" ]] || continue
    local title remote slug
    slug=$(basename "$f" .md)
    title=$(sed -n 's/^title: *//p' "$f")
    remote=$(sed -n 's/^remote: *//p' "$f")
    if [[ -n "$remote" && "$remote" != "null" ]]; then
      printf "  #%-4s %s\n" "$remote" "$title"
    else
      printf "  %-5s %s\n" "local" "$title"
    fi
    count=$((count + 1))
  done
  [[ $count -eq 0 ]] && echo "  No open issues."
  echo ""
}

cmd_show() {
  local slug="$1"
  local file="$ISSUE_DIR/open/${slug}.md"
  [[ -f "$file" ]] || file="$ISSUE_DIR/closed/${slug}.md"
  [[ -f "$file" ]] || {
    echo "  Issue not found: $slug"
    exit 1
  }
  cat "$file"
}

cmd_close() {
  local slug="$1"
  local file="$ISSUE_DIR/open/${slug}.md"
  [[ -f "$file" ]] || {
    echo "  Issue not found in open: $slug"
    exit 1
  }
  mv "$file" "$ISSUE_DIR/closed/"
  echo "  Closed: $slug"
}

cmd_branch() {
  local slug="$1"
  local file="$ISSUE_DIR/open/${slug}.md"
  [[ -f "$file" ]] || {
    echo "  Issue not found: $slug"
    exit 1
  }

  local remote title type branch
  remote=$(sed -n 's/^remote: *//p' "$file")
  title=$(sed -n 's/^title: *//p' "$file")

  # Detect type from labels or default to feat
  type="feat"
  grep -q 'fix\|bug' "$file" && type="fix"
  grep -q 'docs' "$file" && type="docs"

  if [[ -n "$remote" && "$remote" != "null" ]]; then
    branch="${type}/${remote}-${slug}"
  else
    branch="${type}/${slug}"
  fi

  git checkout -b "$branch"
  echo "  Branch: $branch"
}

cmd_push() {
  load_provider

  if ! type issue_provider_available &>/dev/null; then
    echo "  [push] No provider configured. Set [issues] provider in cpm.toml."
    return 1
  fi
  if ! issue_provider_available; then
    echo "  [push] Provider CLI not installed. Install gh: brew install gh"
    return 1
  fi

  echo "  [push] Pushing local issues..."
  for f in "$ISSUE_DIR"/open/*.md; do
    [[ -f "$f" ]] || continue
    issue_sync_push_one "$f"
  done
  echo "  [push] Done."
}

cmd_pull() {
  load_provider

  if ! type issue_provider_available &>/dev/null; then
    echo "  [pull] No provider configured. Set [issues] provider in cpm.toml."
    return 1
  fi
  if ! issue_provider_available; then
    echo "  [pull] Provider CLI not installed. Install gh: brew install gh"
    return 1
  fi

  echo "  [pull] Pulling remote issues..."
  issue_sync_pull "$ISSUE_DIR"
  echo "  [pull] Done."
}

# --- Dispatch ---

case "${1:-}" in
"" | ls | list) cmd_list ;;
show) cmd_show "${2:-}" ;;
close) cmd_close "${2:-}" ;;
branch) cmd_branch "${2:-}" ;;
push) cmd_push ;;
pull) cmd_pull ;;
-h | --help)
  echo "Usage: cpm issue \"title\"       — create issue"
  echo "       cpm issue               — list open issues"
  echo "       cpm issue show <slug>   — show issue"
  echo "       cpm issue close <slug>  — close issue"
  echo "       cpm issue push          — push local issues to remote"
  echo "       cpm issue pull          — pull remote issues to local"
  echo "       cpm issue branch <slug> — create branch from issue"
  ;;
*) cmd_create "$@" ;;
esac
