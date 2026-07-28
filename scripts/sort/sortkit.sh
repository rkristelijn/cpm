#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/sort/sortkit.sh <check|fix> --mode <cpm-toml|ts-imports|lines> --file <path> [options]

Options:
  --dedup                     Enable dedup where supported
  --alias-prefixes "@/,~/,src/"  Import group aliases for ts-imports mode
  --start-marker "..."       Start marker for lines mode
  --end-marker "..."         End marker for lines mode
USAGE
}

section_rank() {
  local sec="$1"
  case "$sec" in
  project) echo "00:$sec" ;;
  tools) echo "01:$sec" ;;
  checks) echo "02:$sec" ;;
  checks.*) echo "03:$sec" ;;
  hooks) echo "04:$sec" ;;
  runner) echo "05:$sec" ;;
  limits) echo "06:$sec" ;;
  process) echo "07:$sec" ;;
  issues) echo "08:$sec" ;;
  *) echo "50:$sec" ;;
  esac
}

sort_section_body_if_safe() {
  local body="$1"
  local dedup="$2"

  local tmp_kv tmp_comments tmp_other out
  tmp_kv=$(mktemp)
  tmp_comments=$(mktemp)
  tmp_other=$(mktemp)

  while IFS= read -r ln || [[ -n "$ln" ]]; do
    if [[ -z "$ln" || "$ln" =~ ^[[:space:]]*# ]]; then
      printf '%s\n' "$ln" >>"$tmp_comments"
    elif [[ "$ln" =~ ^[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*= ]]; then
      printf '%s\t%s\n' "${BASH_REMATCH[1]}" "$ln" >>"$tmp_kv"
    else
      printf '%s\n' "$ln" >>"$tmp_other"
    fi
  done <<<"$body"

  if [[ -s "$tmp_other" ]]; then
    cat "$tmp_kv" >/dev/null 2>&1 || true
    cat "$tmp_comments" >/dev/null 2>&1 || true
    rm -f "$tmp_kv" "$tmp_comments" "$tmp_other"
    printf '%s' "$body"
    return 0
  fi

  if [[ "$dedup" == "1" ]]; then
    out=$(awk -F '\t' '{m[$1]=$2} END{for(k in m) print k"\t"m[k]}' "$tmp_kv" | sort -t $'\t' -k1,1 | cut -f2-)
  else
    # Detect duplicate keys (report via stderr, still produce sorted output)
    local dupes
    dupes=$(awk -F '\t' '{c[$1]++} END{for(k in c) if(c[k]>1) print k}' "$tmp_kv")
    if [[ -n "$dupes" ]]; then
      echo "warning: duplicate keys detected: $dupes" >&2
    fi
    out=$(sort -t $'\t' -k1,1 "$tmp_kv" | cut -f2-)
  fi

  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  fi
  if [[ -s "$tmp_comments" ]]; then
    cat "$tmp_comments"
  fi

  rm -f "$tmp_kv" "$tmp_comments" "$tmp_other"
}

canonicalize_cpm_toml() {
  local file="$1"
  local dedup="$2"

  declare -A body_map=()
  declare -A seen=()
  declare -a sections=()
  local preamble=""
  local cur=""

  while IFS= read -r ln || [[ -n "$ln" ]]; do
    if [[ "$ln" =~ ^\[([^]]+)\][[:space:]]*$ ]]; then
      cur="${BASH_REMATCH[1]}"
      if [[ -z "${seen[$cur]:-}" ]]; then
        sections+=("$cur")
        seen[$cur]=1
      fi
      continue
    fi

    if [[ -z "$cur" ]]; then
      preamble+="$ln"$'\n'
    else
      body_map[$cur]+="$ln"$'\n'
    fi
  done <"$file"

  local sortable_sections=()
  for s in "${sections[@]}"; do
    sortable_sections+=("$(section_rank "$s")")
  done

  IFS=$'\n' read -r -d '' -a sorted_sec < <(printf '%s\n' "${sortable_sections[@]}" | sort && printf '\0')

  printf '%s' "$preamble"
  if [[ -n "$preamble" && "$preamble" != *$'\n\n' ]]; then
    printf '\n'
  fi

  local first=1
  for ranked in "${sorted_sec[@]}"; do
    local sec="${ranked#*:}"
    [[ "$first" -eq 1 ]] || printf '\n'
    first=0

    printf '[%s]\n' "$sec"
    local body="${body_map[$sec]:-}"

    if [[ "$sec" == "tools" || "$sec" == "checks" || "$sec" == "limits" || "$sec" == checks.* ]]; then
      sort_section_body_if_safe "$body" "$dedup"
    else
      printf '%s' "$body"
    fi
  done
}

sort_import_members_line() {
  local line="$1"
  if [[ "$line" =~ ^([[:space:]]*import[[:space:]]*\{)([^}]*)(\}[[:space:]]*from[[:space:]]*[\"\'][^\"\']+[\"\'][[:space:]]*;?[[:space:]]*)$ ]]; then
    local left="${BASH_REMATCH[1]}"
    local members="${BASH_REMATCH[2]}"
    local right="${BASH_REMATCH[3]}"
    local sorted
    sorted=$(printf '%s' "$members" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk 'NF' | sort | awk 'BEGIN{f=1}{if(!f)printf ", ";printf "%s",$0;f=0}')
    printf '%s %s %s\n' "$left" "$sorted" "$right" | sed 's/[[:space:]]\+/ /g;s/ $//'
  else
    printf '%s\n' "$line"
  fi
}

module_of_import() {
  local line="$1"
  local mod=""
  mod=$(printf '%s' "$line" | sed -n "s/.*from[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p")
  if [[ -z "$mod" ]]; then
    mod=$(printf '%s' "$line" | sed -n "s/^[[:space:]]*import[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p")
  fi
  printf '%s' "$mod"
}

group_of_module() {
  local mod="$1"
  local prefixes_csv="$2"
  if [[ "$mod" == .* ]]; then
    echo 2
    return
  fi

  IFS=',' read -r -a prefixes <<<"$prefixes_csv"
  for p in "${prefixes[@]}"; do
    if [[ -n "$p" && "$mod" == "$p"* ]]; then
      echo 1
      return
    fi
  done
  echo 0
}

canonicalize_ts_imports() {
  local file="$1"
  local alias_prefixes="$2"
  local start=0 end=0

  read -r start end < <(awk '
    BEGIN{started=0;s=0;e=0;done=0}
    {
      if (done) next
      if (!started) {
        # Skip directive prologues (use strict, use client, shebangs)
        if ($0 ~ /^#!/) next
        if ($0 ~ /^[[:space:]]*["'"'"']use (strict|client)["'"'"']/) next
        if ($0 ~ /^[[:space:]]*import[[:space:]]/) { started=1; s=NR; e=NR }
        else if ($0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*\/\//) { print "0 0"; done=1 }
      } else {
        if ($0 ~ /^[[:space:]]*import[[:space:]]/ || $0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*\/\//) e=NR
        else { print s, e; done=1 }
      }
    }
    END{ if (!done) { if (started) print s, e; else print "0 0" } }
  ' "$file")

  if [[ "$start" -eq 0 ]]; then
    cat "$file"
    return 0
  fi

  local g0 g1 g2 comments
  g0=$(mktemp)
  g1=$(mktemp)
  g2=$(mktemp)
  comments=$(mktemp)

  sed -n "${start},${end}p" "$file" | while IFS= read -r ln || [[ -n "$ln" ]]; do
    if [[ "$ln" =~ ^[[:space:]]*// ]]; then
      printf '%s\n' "$ln" >>"$comments"
      continue
    fi
    if [[ -z "${ln//[[:space:]]/}" ]]; then
      continue
    fi
    if [[ "$ln" =~ ^[[:space:]]*import[[:space:]] ]]; then
      ln=$(sort_import_members_line "$ln")
      local mod grp
      mod=$(module_of_import "$ln")
      grp=$(group_of_module "$mod" "$alias_prefixes")
      printf '%s\t%s\n' "$mod" "$ln" >>"$([[ "$grp" == 0 ]] && echo "$g0" || ([[ "$grp" == 1 ]] && echo "$g1" || echo "$g2"))"
    fi
  done

  local rebuilt
  rebuilt=$(mktemp)
  local wrote=0
  for g in "$g0" "$g1" "$g2"; do
    if [[ -s "$g" ]]; then
      if [[ "$wrote" -eq 1 ]]; then
        printf '\n' >>"$rebuilt"
      fi
      sort -t $'\t' -k1,1 -k2,2 "$g" | cut -f2- >>"$rebuilt"
      wrote=1
    fi
  done
  if [[ -s "$comments" ]]; then
    if [[ "$wrote" -eq 1 ]]; then printf '\n' >>"$rebuilt"; fi
    cat "$comments" >>"$rebuilt"
  fi

  awk -v s="$start" -v e="$end" -v repl="$rebuilt" '
    BEGIN {
      while ((getline line < repl) > 0) r[++rc] = line
      close(repl)
    }
    NR < s { print; next }
    NR == s {
      for (i = 1; i <= rc; i++) print r[i]
      next
    }
    NR > s && NR <= e { next }
    { print }
  ' "$file"

  rm -f "$g0" "$g1" "$g2" "$comments" "$rebuilt"
}

canonicalize_lines() {
  local file="$1"
  local dedup="$2"
  local start_marker="$3"
  local end_marker="$4"

  if [[ -z "$start_marker" || -z "$end_marker" ]]; then
    if [[ "$dedup" == "1" ]]; then
      awk 'NF' "$file" | sort -u
    else
      awk 'NF' "$file" | sort
    fi
    return 0
  fi

  awk -v sm="$start_marker" -v em="$end_marker" -v dedup="$dedup" '
    BEGIN { bc=0; inb=0 }
    function flush_block(   i,c,n) {
      n=0
      for (i=1;i<=bc;i++) {
        if (block[i] ~ /^[[:space:]]*$/) continue
        n++
        lines[n]=block[i]
      }
      # Shell out to sort for POSIX compatibility (no asort)
      for (i=1;i<=n;i++) print lines[i] | "sort"
      close("sort")
      if (dedup=="1") {
        # dedup handled via sort -u instead
      }
      delete block; delete lines; bc=0
    }
    {
      if (index($0, sm) > 0 && inb==0) {
        inb=1
        print $0
        next
      }
      if (inb==1 && index($0, em) > 0) {
        flush_block()
        inb=0
        print $0
        next
      }
      if (inb==1) {
        block[++bc]=$0
        next
      }
      print $0
    }
    END {
      if (inb==1) {
        print "error: unclosed marker block (end marker not found)" > "/dev/stderr"
        # Output buffered lines unchanged to avoid data loss
        for (i=1;i<=bc;i++) print block[i]
        exit 1
      }
    }
  ' "$file"
}

OP="${1:-}"
shift || true

MODE=""
FILE=""
DEDUP=0
ALIAS_PREFIXES="@/,~/,src/"
START_MARKER=""
END_MARKER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --mode)
    MODE="${2:-}"
    shift 2
    ;;
  --file)
    FILE="${2:-}"
    shift 2
    ;;
  --dedup)
    DEDUP=1
    shift
    ;;
  --alias-prefixes)
    ALIAS_PREFIXES="${2:-}"
    shift 2
    ;;
  --start-marker)
    START_MARKER="${2:-}"
    shift 2
    ;;
  --end-marker)
    END_MARKER="${2:-}"
    shift 2
    ;;
  *)
    echo "unknown arg: $1" >&2
    usage
    exit 2
    ;;
  esac
done

if [[ "$OP" != "check" && "$OP" != "fix" ]]; then
  usage
  exit 2
fi

if [[ -z "$MODE" || -z "$FILE" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "file not found: $FILE" >&2
  exit 2
fi

TMP=$(mktemp "$(dirname "$FILE")/.sortkit.XXXXXX")
case "$MODE" in
cpm-toml)
  canonicalize_cpm_toml "$FILE" "$DEDUP" >"$TMP"
  ;;
ts-imports)
  canonicalize_ts_imports "$FILE" "$ALIAS_PREFIXES" >"$TMP"
  ;;
lines)
  canonicalize_lines "$FILE" "$DEDUP" "$START_MARKER" "$END_MARKER" >"$TMP"
  ;;
*)
  echo "unknown mode: $MODE" >&2
  rm -f "$TMP"
  exit 2
  ;;
esac

# Ensure trailing newline
if [[ -s "$TMP" ]] && [[ "$(tail -c 1 "$TMP" | wc -l | tr -d ' ')" == "0" ]]; then
  printf '\n' >>"$TMP"
fi

if cmp -s "$FILE" "$TMP"; then
  echo "ok: $FILE"
  rm -f "$TMP"
  exit 0
fi

if [[ "$OP" == "check" ]]; then
  echo "not canonical: $FILE"
  rm -f "$TMP"
  exit 1
fi

mv "$TMP" "$FILE"
echo "fixed: $FILE"
