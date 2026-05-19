#!/usr/bin/env bash
# jira.sh — Jira provider for cpm issue push/pull.
# @see ADR-129
# Requires: jira CLI (https://github.com/ankitpokhrel/jira-cli)
#
# Config in cpm.toml:
#   [issues]
#   provider = "jira"
#   project = "CPM"          ← Jira project key

issue_provider_available() {
  command -v jira >/dev/null 2>&1
}

issue_provider_name() { echo "jira"; }

_jira_project() {
  grep -A5 '^\[issues\]' cpm.toml 2>/dev/null | sed -n 's/^project *= *"\(.*\)"/\1/p'
}

issue_sync_push_one() {
  local file="$1"
  local title remote project

  title=$(sed -n 's/^title: *//p' "$file")
  remote=$(sed -n 's/^remote: *//p' "$file")
  [[ -n "$remote" && "$remote" != "null" ]] && return 0

  project=$(_jira_project)
  [[ -z "$project" ]] && {
    echo "  [push] Set issues.project in cpm.toml"
    return 1
  }

  local body
  body=$(sed '1,/^---$/d' "$file" | sed '1,/^---$/d')

  local key
  key=$(jira issue create --project "$project" --type Task --summary "$title" --description "$body" --no-input 2>/dev/null | grep -oE '[A-Z]+-[0-9]+') || return 1

  sed -i '' "s/^remote:.*$/remote: $key/" "$file"
  echo "  [push] $key ← $title"
}

issue_sync_pull() {
  local dir="$1"
  local project
  project=$(_jira_project)
  [[ -z "$project" ]] && return 1

  jira issue list --project "$project" --status "To Do,In Progress" --plain --no-headers 2>/dev/null | while IFS=$'\t' read -r key _ _ summary _; do
    local slug
    slug=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g;s/^-//;s/-$//')
    local path="$dir/open/${slug}.md"
    [[ -f "$path" ]] && continue
    cat >"$path" <<EOF
---
title: $summary
remote: $key
labels: []
---

EOF
    echo "  [pull] $key → ${slug}.md"
  done
}
