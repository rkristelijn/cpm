#!/usr/bin/env bash
# gitlab-review-audit.sh — Audit the quality of code review on GitLab MRs.
#
# Research question (APS): are our merge-request reviews actually substantive,
# and would CodeRabbit add value? This harvests EVERY reviewer comment (not
# just a bot) across a group + subgroups and reports:
#   • how many MRs merged with zero substantive review comments
#     ("approve without feedback" — the gap an automated reviewer would fill)
#   • comments per MR and per reviewer (who reviews, how much)
#   • what topics reviewers actually raise (vs. what cpm/CodeRabbit could catch)
#
# It separates GitLab *system notes* (approved, added commit, requested review)
# from real human/bot comments (system=false). Output is local only.
#
# Usage:
#   gitlab-review-audit.sh --group <path> [--state merged|opened|all]
#                          [--limit <N>] [--repo-limit <N>] [--sleep <sec>]
#                          [--out <dir>] [--resume]
#
# Requires: glab (authenticated), jq. Read-only. Credentials via glab auth.
# Output under --out (default .cache/review-audit/, gitignored):
#   notes.jsonl   source of truth: one row per note (system + user), with
#                 project, mr, author, system flag, and body.
#   mr-index.jsonl one row per scanned MR: project, mr, author, approvers,
#                 substantive-comment count.
#   report.md     the review-quality report.

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

GROUP=""
STATE="merged"
LIMIT=40
REPO_LIMIT=50
SLEEP=1
OUT=".cache/review-audit"
RESUME=0

_usage() { sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    _usage
    exit 0
    ;;
  --group)
    GROUP="${2:?}"
    shift 2
    ;;
  --state)
    STATE="${2:?}"
    shift 2
    ;;
  --limit)
    LIMIT="${2:?}"
    shift 2
    ;;
  --repo-limit)
    REPO_LIMIT="${2:?}"
    shift 2
    ;;
  --sleep)
    SLEEP="${2:?}"
    shift 2
    ;;
  --out)
    OUT="${2:?}"
    shift 2
    ;;
  --resume)
    RESUME=1
    shift
    ;;
  -*)
    echo "Unknown option: $1" >&2
    _usage
    exit 2
    ;;
  *)
    echo "Unexpected arg: $1" >&2
    _usage
    exit 2
    ;;
  esac
done

[[ -n "$GROUP" ]] || {
  echo "Error: --group <path> is required." >&2
  _usage
  exit 2
}
for t in glab jq; do command -v "$t" >/dev/null 2>&1 || {
  echo "Error: '$t' required." >&2
  exit 1
}; done
glab auth status >/dev/null 2>&1 || {
  echo "Error: glab not authenticated (glab auth login)." >&2
  exit 1
}

mkdir -p "$OUT"
NOTES="$OUT/notes.jsonl"
MRIDX="$OUT/mr-index.jsonl"
DONE="$OUT/done.log"
touch "$DONE"
if [[ "$RESUME" -eq 0 ]]; then
  : >"$NOTES"
  : >"$MRIDX"
  : >"$DONE"
fi

_throttle() { [[ "$SLEEP" != "0" ]] && sleep "$SLEEP" || true; }
_seen() { grep -qxF "$1" "$DONE" 2>/dev/null; }
_mark() { printf '%s\n' "$1" >>"$DONE"; }

gl_state="$STATE"
[[ "$STATE" == "open" ]] && gl_state="opened"

echo "Review audit — group=$GROUP state=$gl_state limit=$LIMIT/repo"
echo "» discovering projects (max $REPO_LIMIT)..."
proj=$(glab api "groups/$GROUP/projects?per_page=$REPO_LIMIT&include_subgroups=true&archived=false&order_by=last_activity_at" \
  2>/dev/null | jq -r '.[] | "\(.id)\t\(.path_with_namespace)"' || true)
[[ -z "$proj" ]] && {
  echo "No projects or no access."
  exit 0
}

while IFS=$'\t' read -r pid ppath; do
  [[ -z "$pid" ]] && continue
  mrs=$(glab api "projects/$pid/merge_requests?state=$gl_state&per_page=$LIMIT&order_by=updated_at" \
    2>/dev/null | jq -c '.[] | {iid, author: .author.username}' || true)
  [[ -z "$mrs" ]] && continue
  echo "» $ppath"
  while IFS= read -r mrrow; do
    [[ -z "$mrrow" ]] && continue
    iid=$(printf '%s' "$mrrow" | jq -r '.iid')
    author=$(printf '%s' "$mrrow" | jq -r '.author // "unknown"')
    key="$pid!$iid"
    if [[ "$RESUME" -eq 1 ]] && _seen "$key"; then continue; fi

    notes=$(glab api "projects/$pid/merge_requests/$iid/notes?per_page=100" 2>/dev/null || echo '[]')

    # Persist every note (system + user) with context. We capture the note
    # kind so the report can separate INLINE code review (DiffNote, tied to a
    # file:line — what an automated reviewer/cpm rule would replace) from
    # GENERIC MR discussion (no diff position). Both come from this one
    # endpoint; type=="DiffNote" (or a non-null position) marks the inline ones.
    printf '%s' "$notes" | jq -c --arg p "$ppath" --arg iid "$iid" '
      .[] | {project:$p, mr:($iid|tonumber), system:.system,
             author:(.author.username // "unknown"),
             kind:( if (.type=="DiffNote" or .position!=null) then "inline" else "generic" end ),
             path:(.position.new_path // null),
             line:(.position.new_line // null),
             body:(.body // "")}' >>"$NOTES" 2>/dev/null || true

    # Per-MR summary: substantive (non-system) comment count + approvers.
    printf '%s' "$notes" | jq -c --arg p "$ppath" --arg iid "$iid" --arg a "$author" '
      ( [ .[] | select(.system==false) ] ) as $real
      | ( [ .[] | select(.system==true and (.body|test("approved this merge request")))
            | .author.username ] | unique ) as $approvers
      | {project:$p, mr:($iid|tonumber), mr_author:$a,
         comments: ($real|length),
         reviewers: ( [ $real[].author.username ] | unique ),
         approvers: $approvers}' >>"$MRIDX" 2>/dev/null || true

    _mark "$key"
    _throttle
  done <<<"$mrs"
done <<<"$proj"

total_mrs=$(wc -l <"$MRIDX" 2>/dev/null | tr -d ' ')
[[ -z "$total_mrs" ]] && total_mrs=0
[[ "$total_mrs" -eq 0 ]] && {
  echo "No MRs scanned."
  exit 0
}

# --- Report ---
REPORT="$OUT/report.md"
{
  echo "# GitLab review-quality audit — $GROUP"
  echo ""
  echo "Scanned $total_mrs merged MR(s), state=$gl_state."
  echo ""

  # 1) The headline gap: MRs merged with zero substantive comments.
  zero=$(jq -s '[ .[] | select(.comments==0) ] | length' "$MRIDX")
  withc=$(jq -s '[ .[] | select(.comments>0) ] | length' "$MRIDX")
  total_comments=$(jq -s '[ .[].comments ] | add // 0' "$MRIDX")
  pct=0
  [[ "$total_mrs" -gt 0 ]] && pct=$((zero * 100 / total_mrs))
  echo "## Headline"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|------:|"
  echo "| MRs merged with **zero** substantive review comments | $zero ($pct%) |"
  echo "| MRs with at least one comment | $withc |"
  echo "| Total substantive comments | $total_comments |"
  echo ""
  # Inline (code-line) vs generic (discussion) split — inline is the concrete
  # code review that a rule/automated reviewer could replace.
  inline=$(jq -s '[ .[] | select(.system==false and .kind=="inline") ] | length' "$NOTES")
  generic=$(jq -s '[ .[] | select(.system==false and .kind=="generic") ] | length' "$NOTES")
  echo "| — of which **inline** (on a code line) | $inline |"
  echo "| — of which **generic** (MR discussion) | $generic |"
  echo ""
  echo "A high zero-comment share is the gap an automated reviewer (CodeRabbit)"
  echo "or a shift-left cpm rule set would fill: today those MRs merge unreviewed"
  echo "in substance."
  echo ""

  # 2) Who reviews, and how much — split humans from bots/service accounts so
  #    the "how good are OUR reviews" question isn't skewed by automation.
  #    Heuristic: usernames matching svc_/bot/ci/_bot/coderabbit/renovate/
  #    dependabot are treated as non-human.
  bot_re='^(svc[_-]|.*bot$|.*\[bot\]|ci[_-]|.*-ci$)|coderabbit|renovate|dependabot|gitlab'
  echo "## Human reviewers (by substantive comments)"
  echo ""
  echo "| Comments | Reviewer |"
  echo "|---------:|----------|"
  jq -r 'select(.system==false) | .author' "$NOTES" |
    grep -viE "$bot_re" |
    sort | uniq -c | sort -rn | head -20 |
    while read -r c a; do printf '| %s | %s |\n' "$c" "$a"; done
  echo ""
  echo "## Automation / service accounts (excluded from human count)"
  echo ""
  echo "| Comments | Account |"
  echo "|---------:|---------|"
  jq -r 'select(.system==false) | .author' "$NOTES" |
    grep -iE "$bot_re" |
    sort | uniq -c | sort -rn | head -10 |
    while read -r c a; do printf '| %s | %s |\n' "$c" "$a"; done
  echo ""

  # 3) What reviewers talk about — topic buckets (would cpm/CodeRabbit catch it?)
  echo "## Review topics (could a rule catch these?)"
  echo ""
  echo "| Comments | Repos | Topic |"
  echo "|---------:|------:|-------|"
  while IFS=$'\t' read -r label regex; do
    [[ -z "$label" || "$label" == \#* ]] && continue
    hits=$(jq -r --arg re "$regex" 'select(.system==false and (.body|test($re;"i"))) | .project' "$NOTES" 2>/dev/null)
    [[ -z "$hits" ]] && continue
    n=$(printf '%s\n' "$hits" | grep -c .)
    repos=$(printf '%s\n' "$hits" | sort -u | grep -c .)
    printf '| %s | %s | %s |\n' "$n" "$repos" "$label"
  done <<'TOPICS' | sort -t'|' -k2 -rn
naming / style / typo	\bnaming\b|typo|rename|style|formatting
null / nil / undefined	null|nil|undefined|none-check
error handling	error handling|try|catch|exception|swallow
tests / coverage	test|coverage|assert|spec
security	security|injection|secret|token|password|auth
validation	validate|validation|sanitiz|input
performance	performance|slow|n\+1|allocat|memory
naming a rule-able nit	magic number|hardcoded|unused|dead code|duplicat
TOPICS
} >"$REPORT"

echo ""
echo "Source of truth: $NOTES  ($(wc -l <"$NOTES" | tr -d ' ') notes)"
echo "Per-MR index   : $MRIDX  ($total_mrs MRs)"
echo "Report         : $REPORT"
echo ""
sed -n '/## Headline/,/A high zero-comment/p' "$REPORT" | sed 's/^/  /'
