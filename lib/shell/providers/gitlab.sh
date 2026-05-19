#!/usr/bin/env bash
# gitlab.sh — GitLab Issues provider for cpm issue push/pull.
# @see ADR-129
# Requires: glab CLI (https://gitlab.com/gitlab-org/cli)

issue_provider_available() {
  command -v glab >/dev/null 2>&1
}

issue_provider_name() { echo "gitlab"; }

issue_sync_push_one() {
  local file="$1"
  local title remote

  title=$(sed -n 's/^title: *//p' "$file")
  remote=$(sed -n 's/^remote: *//p' "$file")
  [[ -n "$remote" && "$remote" != "null" ]] && return 0

  local body
  body=$(sed '1,/^---$/d' "$file" | sed '1,/^---$/d')

  local url
  url=$(glab issue create --title "$title" --description "$body" 2>/dev/null) || return 1
  local number
  number=$(echo "$url" | grep -oE '[0-9]+$')

  sed -i '' "s/^remote:.*$/remote: $number/" "$file"
  if ! grep -q '^remote-url:' "$file"; then
    sed -i '' "/^remote:/a\\
remote-url: $url" "$file"
  else
    sed -i '' "s|^remote-url:.*$|remote-url: $url|" "$file"
  fi

  echo "  [push] #$number ← $title"
}

issue_sync_pull() {
  local dir="$1"
  local issues
  issues=$(glab issue list --output-format json 2>/dev/null) || return 1

  echo "$issues" | python3 -c "
import json, sys, re, os
issues = json.load(sys.stdin)
for issue in issues:
    slug = re.sub(r'[^a-z0-9]+', '-', issue['title'].lower()).strip('-')
    path = f'$dir/open/{slug}.md'
    if os.path.exists(path):
        continue
    labels = ', '.join(issue.get('labels', []))
    with open(path, 'w') as f:
        f.write('---\n')
        f.write(f'title: {issue[\"title\"]}\n')
        f.write(f'remote: {issue[\"iid\"]}\n')
        f.write(f'labels: [{labels}]\n')
        f.write('---\n\n')
        f.write(issue.get('description', '') or '')
        f.write('\n')
    print(f'  [pull] #{issue[\"iid\"]} → {slug}.md')
" 2>/dev/null
}
