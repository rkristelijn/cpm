#!/usr/bin/env bash
# clickup.sh — ClickUp provider for cpm issue push/pull.
# Requires: CLICKUP_TOKEN env var + curl
#
# Config in cpm.toml:
#   [issues]
#   provider = "clickup"
#   list-id = "123456789"    ← ClickUp list ID

issue_provider_available() {
  _clickup_token >/dev/null 2>&1
}

issue_provider_name() { echo "clickup"; }

_clickup_token() {
  source "$(dirname "$0")/../../shell/secret.sh"
  resolve_secret "clickup-token"
}

_clickup_list_id() {
  grep -A5 '^\[issues\]' cpm.toml 2>/dev/null | sed -n 's/^list-id *= *"\(.*\)"/\1/p'
}

_clickup_api() {
  local token
  token=$(_clickup_token)
  curl -s -H "Authorization: $token" -H "Content-Type: application/json" "$@"
}

issue_sync_push_one() {
  local file="$1"
  local title remote list_id

  title=$(sed -n 's/^title: *//p' "$file")
  remote=$(sed -n 's/^remote: *//p' "$file")
  [[ -n "$remote" && "$remote" != "null" ]] && return 0

  list_id=$(_clickup_list_id)
  [[ -z "$list_id" ]] && { echo "  [push] Set issues.list-id in cpm.toml"; return 1; }

  local body
  body=$(sed '1,/^---$/d' "$file" | sed '1,/^---$/d')

  local response id
  response=$(_clickup_api -X POST "https://api.clickup.com/api/v2/list/$list_id/task" \
    -d "{\"name\":\"$title\",\"description\":\"$body\"}") || return 1
  id=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  [[ -z "$id" ]] && return 1
  sed -i '' "s/^remote:.*$/remote: $id/" "$file"
  echo "  [push] $id ← $title"
}

issue_sync_pull() {
  local dir="$1"
  local list_id
  list_id=$(_clickup_list_id)
  [[ -z "$list_id" ]] && return 1

  local tasks
  tasks=$(_clickup_api "https://api.clickup.com/api/v2/list/$list_id/task?statuses[]=to%20do&statuses[]=in%20progress") || return 1

  echo "$tasks" | python3 -c "
import json, sys, re, os
data = json.load(sys.stdin)
for task in data.get('tasks', []):
    slug = re.sub(r'[^a-z0-9]+', '-', task['name'].lower()).strip('-')
    path = f'$dir/open/{slug}.md'
    if os.path.exists(path):
        continue
    with open(path, 'w') as f:
        f.write('---\n')
        f.write(f'title: {task[\"name\"]}\n')
        f.write(f'remote: {task[\"id\"]}\n')
        f.write('labels: []\n')
        f.write('---\n\n')
        f.write(task.get('description', '') or '')
        f.write('\n')
    print(f'  [pull] {task[\"id\"]} → {slug}.md')
" 2>/dev/null
}
