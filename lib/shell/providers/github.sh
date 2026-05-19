#!/usr/bin/env bash
# github.sh — GitHub Issues provider for cpm issue sync.
# @see ADR-129
# Requires: gh CLI (https://cli.github.com)

issue_provider_available() {
  command -v gh >/dev/null 2>&1
}

issue_provider_name() { echo "github"; }

# Push a local issue to GitHub. Sets remote number in frontmatter.
# Args: $1 = issue file path
issue_sync_push_one() {
  local file="$1"
  local title body labels remote

  title=$(sed -n 's/^title: *//p' "$file")
  remote=$(sed -n 's/^remote: *//p' "$file")

  # Already synced
  [[ -n "$remote" && "$remote" != "null" ]] && return 0

  # Body = everything after the frontmatter closing ---
  body=$(sed '1,/^---$/d' "$file" | sed '1,/^---$/d')
  labels=$(sed -n 's/^labels: *\[//p' "$file" | tr -d ']' | tr ',' '\n' | sed 's/^ *//' | paste -sd',' -)

  local gh_args=(issue create --title "$title" --body "$body")
  # Only add labels if they exist on the remote (skip on failure)
  if [[ -n "$labels" ]]; then
    gh_args+=(--label "$labels")
  fi

  local url
  url=$(gh "${gh_args[@]}" 2>&1) || {
    # Retry without labels if label doesn't exist
    url=$(gh issue create --title "$title" --body "$body" 2>/dev/null) || return 1
  }
  local number
  number=$(echo "$url" | grep -oE '[0-9]+$')

  # Write remote info back to frontmatter
  sed -i '' "s/^remote:.*$/remote: $number/" "$file"
  if ! grep -q '^remote-url:' "$file"; then
    sed -i '' "/^remote:/a\\
remote-url: $url" "$file"
  else
    sed -i '' "s|^remote-url:.*$|remote-url: $url|" "$file"
  fi

  echo "  [sync] #$number ← $title"
}

# Pull issues from GitHub that don't exist locally.
# Args: $1 = issues directory
issue_sync_pull() {
  local dir="$1"
  local issues
  issues=$(gh issue list --state open --json number,title,body,labels --limit 100 2>/dev/null) || return 1

  echo "$issues" | python3 -c "
import json, sys, re, os
issues = json.load(sys.stdin)
for issue in issues:
    slug = re.sub(r'[^a-z0-9]+', '-', issue['title'].lower()).strip('-')
    path = f'$dir/open/{slug}.md'
    if os.path.exists(path):
        continue
    labels = ', '.join(l['name'] for l in issue.get('labels', []))
    with open(path, 'w') as f:
        f.write('---\n')
        f.write(f'title: {issue[\"title\"]}\n')
        f.write(f'remote: {issue[\"number\"]}\n')
        f.write(f'labels: [{labels}]\n')
        f.write('---\n\n')
        f.write(issue.get('body', '') or '')
        f.write('\n')
    print(f'  [sync] #{issue[\"number\"]} → {slug}.md')
" 2>/dev/null

  # Check for remotely closed issues
  local closed
  closed=$(gh issue list --state closed --json number --limit 100 2>/dev/null) || return 0
  for f in "$dir"/open/*.md; do
    [[ -f "$f" ]] || continue
    local rnum
    rnum=$(sed -n 's/^remote: *//p' "$f")
    [[ -z "$rnum" ]] && continue
    if echo "$closed" | grep -q "\"number\":$rnum"; then
      local base
      base=$(basename "$f")
      mv "$f" "$dir/closed/$base"
      echo "  [sync] #$rnum closed → $base"
    fi
  done
}

# Create a project board and link issues to it.
# Args: $1 = project title
project_create() {
  local title="$1"
  local owner
  owner=$(grep -A5 '^\[issues\]' cpm.toml 2>/dev/null | sed -n 's/^repo *= *"\(.*\)"/\1/p' | cut -d/ -f1)
  [[ -z "$owner" ]] && { echo "  [project] Set issues.repo in cpm.toml"; return 1; }

  local url
  url=$(gh project create --title "$title" --owner "$owner" --format json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('url',''))" 2>/dev/null) || {
    url=$(gh project create --title "$title" --owner "$owner" 2>&1)
  }
  echo "$url"
}

# Add an issue to a project by number.
# Args: $1 = project number, $2 = issue number
project_add_issue() {
  local project_num="$1" issue_num="$2"
  local owner repo
  owner=$(grep -A5 '^\[issues\]' cpm.toml 2>/dev/null | sed -n 's/^repo *= *"\(.*\)"/\1/p' | cut -d/ -f1)
  repo=$(grep -A5 '^\[issues\]' cpm.toml 2>/dev/null | sed -n 's/^repo *= *"\(.*\)"/\1/p')

  local item_url="https://github.com/${repo}/issues/${issue_num}"
  gh project item-add "$project_num" --owner "$owner" --url "$item_url" 2>/dev/null
}

# List projects
project_list() {
  local owner
  owner=$(grep -A5 '^\[issues\]' cpm.toml 2>/dev/null | sed -n 's/^repo *= *"\(.*\)"/\1/p' | cut -d/ -f1)
  gh project list --owner "$owner" --format json 2>/dev/null | python3 -c "
import json, sys
projects = json.load(sys.stdin).get('projects', [])
for p in projects:
    print(f'  #{p[\"number\"]}  {p[\"title\"]}')
" 2>/dev/null
}
