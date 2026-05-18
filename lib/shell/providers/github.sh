#!/usr/bin/env bash
# github.sh — GitHub Issues provider for cpm issue sync.
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
  [[ -n "$labels" ]] && gh_args+=(--label "$labels")

  local url
  url=$(gh "${gh_args[@]}" 2>/dev/null) || return 1
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
