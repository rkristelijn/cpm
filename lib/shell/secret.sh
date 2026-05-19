#!/usr/bin/env bash
# secret.sh — Resolve secrets from multiple sources.
# @see ADR-129
#
# Usage: source this file, then call:
#   token=$(resolve_secret "clickup-token")
#
# Resolution order (first match wins):
#   1. Environment variable (CLICKUP_TOKEN)
#   2. .config/vault.json (gitignored, like workspace-tui)
#   3. .config/.env (gitignored, dotenv format)
#   4. ~/.config/cpm/vault.json (global)
#   5. macOS Keychain (security find-generic-password)
#
# The user decides where to store secrets. cpm just finds them.

# Convert key name to env var format: "clickup-token" → "CLICKUP_TOKEN"
_to_env_var() {
  echo "$1" | tr '[:lower:]-' '[:upper:]_'
}

# Read a key from a JSON file using python3 (available on macOS/Linux)
_json_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  python3 -c "
import json, sys
try:
    d = json.load(open('$file'))
    # Support nested: providers.clickup.token or flat: clickup-token
    keys = '$key'.replace('-','_').split('.')
    v = d
    for k in keys:
        if isinstance(v, dict):
            v = v.get(k, v.get('$key'))
        else:
            v = None
            break
    if v and isinstance(v, str):
        print(v)
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null
}

resolve_secret() {
  local key="$1"
  local env_var val

  # 1. Environment variable
  env_var=$(_to_env_var "$key")
  val="${!env_var:-}"
  [[ -n "$val" ]] && {
    echo "$val"
    return 0
  }

  # 2. Project vault (.config/vault.json)
  val=$(_json_get ".config/vault.json" "$key")
  [[ -n "$val" ]] && {
    echo "$val"
    return 0
  }

  # 3. Project .env (.config/.env)
  if [[ -f ".config/.env" ]]; then
    val=$(grep "^${env_var}=" ".config/.env" 2>/dev/null | head -1 | cut -d= -f2-)
    [[ -n "$val" ]] && {
      echo "$val"
      return 0
    }
  fi

  # 4. Global vault (~/.config/cpm/vault.json)
  val=$(_json_get "$HOME/.config/cpm/vault.json" "$key")
  [[ -n "$val" ]] && {
    echo "$val"
    return 0
  }

  # 5. macOS Keychain
  if command -v security >/dev/null 2>&1; then
    val=$(security find-generic-password -s "$key" -w 2>/dev/null)
    [[ -n "$val" ]] && {
      echo "$val"
      return 0
    }
  fi

  return 1
}
