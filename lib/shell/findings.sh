#!/usr/bin/env bash
# findings.sh — Structured findings database with JUnit XML output.
#
# Pattern from production standard-components (xml-junit-helper-functions.sh).
# JSONL as intermediate format, queryable with jq/grep.
#
# Usage:
#   source lib/shell/findings.sh
#   findings_init "check-name"
#   findings_add "pass" "src/main.ts" "no-any" "No any types found"
#   findings_add "fail" "src/util.ts:42" "no-any" "Found 'any' type" "Use unknown or generics" "https://..."
#   findings_finish
#
# Query:
#   findings_query --severity error
#   findings_query --check npm-audit
#   findings_query --since 7d
#
# @see docs/adrs/adr-014-findings-database.md

FINDINGS_FILE="${CPM_FINDINGS_FILE:-.tmp/findings.jsonl}"
FINDINGS_JUNIT="${CPM_FINDINGS_JUNIT:-.tmp/reports}"
mkdir -p "$(dirname "$FINDINGS_FILE")" "$FINDINGS_JUNIT"

# State for current check run
_f_check=""
_f_total=0
_f_pass=0
_f_fail=0
_f_warn=0
_f_info=0
_f_skip=0

# XML escape (from production xml-junit-helper-functions.sh)
_xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# Initialize a findings session for a check
findings_init() {
  _f_check="${1:-unknown}"
  _f_total=0 _f_pass=0 _f_fail=0 _f_warn=0 _f_info=0 _f_skip=0
}

# Add a finding
# Args: status file rule message [fix] [docs_url]
# Status: pass | fail | warning | info | skip
findings_add() {
  local status="$1" file="$2" rule="$3" message="$4"
  local fix="${5:-}" docs="${6:-}"

  _f_total=$((_f_total + 1))
  case "$status" in
  pass) _f_pass=$((_f_pass + 1)) ;;
  fail | error)
    _f_fail=$((_f_fail + 1))
    status="error"
    ;;
  warning | warn)
    _f_warn=$((_f_warn + 1))
    status="warning"
    ;;
  info) _f_info=$((_f_info + 1)) ;;
  skip) _f_skip=$((_f_skip + 1)) ;;
  esac

  # Extract line number from file (file:line format)
  local line=0
  if [[ "$file" == *:* ]]; then
    line="${file##*:}"
    file="${file%%:*}"
  fi

  local ts commit
  ts=$(date +%Y-%m-%dT%H:%M:%S%z)
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo "none")

  # First-seen tracking
  local first_seen="$commit" first_ts="$ts"
  local existing
  existing=$(grep "\"check\":\"$_f_check\".*\"file\":\"$file\".*\"rule\":\"$rule\"" "$FINDINGS_FILE" 2>/dev/null | tail -1)
  if [[ -n "$existing" ]]; then
    first_seen=$(echo "$existing" | sed 's/.*"first_seen":"//;s/".*//')
    first_ts=$(echo "$existing" | sed 's/.*"first_ts":"//;s/".*//')
  fi

  # Append to JSONL
  printf '{"ts":"%s","check":"%s","severity":"%s","file":"%s","line":%d,"rule":"%s","message":"%s","fix":"%s","docs":"%s","first_seen":"%s","first_ts":"%s","commit":"%s"}\n' \
    "$ts" "$_f_check" "$status" "$file" "$line" "$rule" "$message" "$fix" "$docs" "$first_seen" "$first_ts" "$commit" >>"$FINDINGS_FILE"
}

# Finish and generate JUnit XML for this check
findings_finish() {
  local xmlfile="$FINDINGS_JUNIT/${_f_check}-junit.xml"
  local commit
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo "none")

  # Generate JUnit XML
  echo '<?xml version="1.0" encoding="UTF-8"?>' >"$xmlfile"
  echo '<testsuites>' >>"$xmlfile"
  echo "  <testsuite name=\"$(_xml_escape "$_f_check")\" tests=\"$_f_total\" failures=\"$_f_fail\" errors=\"0\" skipped=\"$_f_skip\">" >>"$xmlfile"

  # Read findings for this check from this commit
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local sev file rule msg fix
    sev=$(echo "$line" | sed 's/.*"severity":"//;s/".*//')
    file=$(echo "$line" | sed 's/.*"file":"//;s/".*//')
    rule=$(echo "$line" | sed 's/.*"rule":"//;s/".*//')
    msg=$(echo "$line" | sed 's/.*"message":"//;s/".*//')
    fix=$(echo "$line" | sed 's/.*"fix":"//;s/".*//')

    echo "    <testcase classname=\"$(_xml_escape "$file")\" name=\"$(_xml_escape "$rule")\" file=\"$(_xml_escape "$file")\">" >>"$xmlfile"
    case "$sev" in
    error)
      echo "      <failure message=\"$(_xml_escape "$msg")\" type=\"error\"><![CDATA[$fix]]></failure>" >>"$xmlfile"
      ;;
    warning)
      echo "      <system-out><![CDATA[WARNING: $msg${fix:+ | Fix: $fix}]]></system-out>" >>"$xmlfile"
      ;;
    skip)
      echo "      <skipped message=\"$(_xml_escape "$msg")\"/>" >>"$xmlfile"
      ;;
    *)
      [[ -n "$msg" ]] && echo "      <system-out><![CDATA[$msg]]></system-out>" >>"$xmlfile"
      ;;
    esac
    echo "    </testcase>" >>"$xmlfile"
  done < <(grep "\"check\":\"$_f_check\".*\"commit\":\"$commit\"" "$FINDINGS_FILE" 2>/dev/null)

  # Summary testcase
  echo "    <testcase classname=\"summary\" name=\"$_f_check: $_f_total checked, $_f_fail errors, $_f_warn warnings\">" >>"$xmlfile"
  echo "      <system-out><![CDATA[pass=$_f_pass fail=$_f_fail warn=$_f_warn info=$_f_info skip=$_f_skip]]></system-out>" >>"$xmlfile"
  echo "    </testcase>" >>"$xmlfile"

  echo "  </testsuite>" >>"$xmlfile"
  echo "</testsuites>" >>"$xmlfile"
}

# Query findings (filter by severity, check, time)
# Usage: findings_query [--severity error] [--check name] [--since 7d] [--commit hash]
findings_query() {
  local filter="cat"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --severity)
      filter="$filter | grep '\"severity\":\"$2\"'"
      shift 2
      ;;
    --check)
      filter="$filter | grep '\"check\":\"$2\"'"
      shift 2
      ;;
    --commit)
      filter="$filter | grep '\"commit\":\"$2\"'"
      shift 2
      ;;
    --new)
      filter="$filter | grep '\"first_seen\":\"$(git rev-parse --short HEAD 2>/dev/null)\"'"
      shift
      ;;
    *) shift ;;
    esac
  done
  eval "$filter" <"$FINDINGS_FILE" 2>/dev/null
}

# Print summary to console
findings_summary() {
  if ((_f_total == 0)); then
    echo "  ✓ No findings"
  else
    local summary="  $_f_total checked"
    ((_f_fail > 0)) && summary+=", $_f_fail errors"
    ((_f_warn > 0)) && summary+=", $_f_warn warnings"
    ((_f_info > 0)) && summary+=", $_f_info info"
    ((_f_skip > 0)) && summary+=", $_f_skip skipped"
    echo "$summary"
  fi
}

# Deduplicate findings file — keeps latest entry per (check, file, rule) key.
# Call after a scan/check run to remove stale duplicates.
findings_dedup() {
  local file="${1:-$FINDINGS_FILE}"
  [[ -f "$file" ]] || return 0
  # Sort by key (check+file+rule), keep last occurrence (most recent)
  awk -F'"' '{
    key = ""
    for (i=1; i<=NF; i++) {
      if ($(i) == "check") key = key $(i+2)
      if ($(i) == "file") key = key $(i+2)
      if ($(i) == "rule") key = key $(i+2)
    }
    lines[key] = $0
  } END { for (k in lines) print lines[k] }' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
}
