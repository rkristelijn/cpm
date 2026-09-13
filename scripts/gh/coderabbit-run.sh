#!/usr/bin/env bash
# coderabbit-run.sh — Run coderabbit-harvest.sh as a long, resumable background
# job with a hard time cap, a log file, and start/status/stop/progress control.
#
# Designed for "let it run for an hour (or overnight)" harvests over many repos.
# It wraps coderabbit-harvest.sh (which already does throttling + rate-limit
# backoff + --resume) and adds process supervision so you can detach and check
# back later.
#
# Usage:
#   coderabbit-run.sh start [--duration <sec>] [--targets <file>] [-- <harvest args>]
#   coderabbit-run.sh status
#   coderabbit-run.sh progress          # tail the ranked candidates so far
#   coderabbit-run.sh log [-f]          # show (or follow) the run log
#   coderabbit-run.sh stop
#
# Defaults: duration 3600s (1h), targets .cache/coderabbit/targets.txt.
# Everything lives under .cache/coderabbit/ (gitignored):
#   harvest-run.log   full stdout/stderr of the run
#   harvest.pid       PID of the supervised harvest (for status/stop)
#   comments.jsonl    source of truth (append-only, resume-safe)
#   ranked.md         ranked shift-left candidates
#   signals.csv       spreadsheet-friendly aggregate

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARVEST="$SCRIPT_DIR/coderabbit-harvest.sh"
OUT=".cache/coderabbit"
LOG="$OUT/harvest-run.log"
PIDF="$OUT/harvest.pid"
DURATION=3600
TARGETS="$OUT/targets.txt"

_running() { [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; }

cmd="${1:-status}"; shift || true

case "$cmd" in
  start)
    # Parse start options; anything after `--` is forwarded to the harvester.
    EXTRA=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --duration) DURATION="${2:?}"; shift 2 ;;
        --targets)  TARGETS="${2:?}"; shift 2 ;;
        --) shift; EXTRA=("$@"); break ;;
        *) echo "Unknown start option: $1" >&2; exit 2 ;;
      esac
    done

    if _running; then
      echo "Already running (PID $(cat "$PIDF")). Use 'status' or 'stop'." >&2
      exit 1
    fi
    [[ -f "$HARVEST" ]] || { echo "Missing $HARVEST" >&2; exit 1; }
    [[ -f "$TARGETS" ]] || { echo "Missing targets file: $TARGETS" >&2; exit 1; }

    mkdir -p "$OUT"
    # Read repos (skip comments/blanks).
    mapfile -t REPOS < <(grep -vE '^[[:space:]]*(#|$)' "$TARGETS")
    [[ ${#REPOS[@]} -gt 0 ]] || { echo "No targets in $TARGETS" >&2; exit 1; }

    # Sensible long-run defaults; overridable via `-- ...`.
    ARGS=(--state merged --limit 40 --repo-limit 50 --sleep 2 --min 3 --resume --out "$OUT")
    [[ ${#EXTRA[@]} -gt 0 ]] && ARGS=("${EXTRA[@]}")

    TO="$(command -v gtimeout || command -v timeout || true)"
    echo "Starting harvest of ${#REPOS[@]} repo(s), cap ${DURATION}s, log $LOG"
    {
      echo "=== run started $(date '+%F %T'), duration=${DURATION}s ==="
      echo "targets: ${REPOS[*]}"
      echo "args: ${ARGS[*]}"
    } >> "$LOG"

    if [[ -n "$TO" ]]; then
      nohup "$TO" "$DURATION" bash "$HARVEST" "${REPOS[@]}" "${ARGS[@]}" >> "$LOG" 2>&1 &
      echo $! > "$PIDF"
    else
      # Fallback: background the harvest + a watchdog that kills it after DURATION.
      nohup bash "$HARVEST" "${REPOS[@]}" "${ARGS[@]}" >> "$LOG" 2>&1 &
      bg=$!; echo "$bg" > "$PIDF"
      ( sleep "$DURATION"; kill "$bg" 2>/dev/null || true ) >/dev/null 2>&1 &
    fi
    echo "Started (PID $(cat "$PIDF")). Follow with: $0 log -f"
    ;;

  status)
    if _running; then
      echo "RUNNING (PID $(cat "$PIDF"))"
    else
      echo "not running"
    fi
    if [[ -f "$OUT/comments.jsonl" ]]; then
      echo "comments harvested: $(wc -l < "$OUT/comments.jsonl" | tr -d ' ')"
    fi
    if [[ -f "$OUT/done.log" ]]; then
      echo "PRs/MRs processed:  $(wc -l < "$OUT/done.log" | tr -d ' ')"
    fi
    ;;

  progress)
    [[ -f "$OUT/ranked.md" ]] || { echo "No ranked.md yet."; exit 0; }
    grep -E '^\| *[0-9]' "$OUT/ranked.md" | head -25
    ;;

  log)
    [[ -f "$LOG" ]] || { echo "No log yet at $LOG"; exit 0; }
    if [[ "${1:-}" == "-f" ]]; then tail -f "$LOG"; else tail -40 "$LOG"; fi
    ;;

  stop)
    if _running; then
      kill "$(cat "$PIDF")" 2>/dev/null || true
      echo "Stopped (PID $(cat "$PIDF"))."
    else
      echo "not running"
    fi
    ;;

  *)
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    exit 2 ;;
esac
