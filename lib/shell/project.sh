#!/usr/bin/env bash
# project.sh — Project/roadmap management with provider sync.
# Usage: cpm project create "v0.2.0 — Process Complete"
#        cpm project list
#        cpm project add <project#> <issue-slug>
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISSUE_DIR="${ISSUE_DIR:-docs/issues}"

# Load provider
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

cmd_create() {
  local title="$*"
  [[ -z "$title" ]] && { echo "  Usage: cpm project create \"title\""; exit 1; }

  load_provider

  if ! type project_create &>/dev/null; then
    echo "  [project] Provider doesn't support projects."
    return 1
  fi

  echo "  [project] Creating: $title"
  local url
  url=$(project_create "$title")
  echo "  [project] Created: $url"

  # Add all open issues to the project
  local project_num
  project_num=$(echo "$url" | grep -oE '[0-9]+$')
  if [[ -n "$project_num" ]]; then
    echo "  [project] Adding open issues..."
    for f in "$ISSUE_DIR"/open/*.md; do
      [[ -f "$f" ]] || continue
      local remote
      remote=$(sed -n 's/^remote: *//p' "$f")
      [[ -z "$remote" ]] && continue
      project_add_issue "$project_num" "$remote" && \
        echo "  [project] + #$remote $(sed -n 's/^title: *//p' "$f")"
    done
  fi
}

cmd_list() {
  load_provider
  if ! type project_list &>/dev/null; then
    echo "  [project] Provider doesn't support projects."
    return 1
  fi
  project_list
}

cmd_add() {
  local project_num="$1" slug="$2"
  [[ -z "$project_num" || -z "$slug" ]] && { echo "  Usage: cpm project add <project#> <issue-slug>"; exit 1; }

  load_provider
  local file="$ISSUE_DIR/open/${slug}.md"
  [[ -f "$file" ]] || { echo "  Issue not found: $slug"; exit 1; }

  local remote
  remote=$(sed -n 's/^remote: *//p' "$file")
  [[ -z "$remote" ]] && { echo "  Issue not synced. Run: cpm issue push"; exit 1; }

  project_add_issue "$project_num" "$remote"
  echo "  [project] Added #$remote to project $project_num"
}

# Dispatch
case "${1:-}" in
  create) shift; cmd_create "$@" ;;
  list|ls) cmd_list ;;
  add)    cmd_add "${2:-}" "${3:-}" ;;
  -h|--help)
    echo "Usage: cpm project create \"title\"   — create project board"
    echo "       cpm project list              — list projects"
    echo "       cpm project add <#> <slug>    — add issue to project"
    ;;
  *)      echo "  Usage: cpm project <create|list|add>"; exit 1 ;;
esac
