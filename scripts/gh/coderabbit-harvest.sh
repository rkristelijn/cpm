#!/usr/bin/env bash
# coderabbit-harvest.sh — Aggregate CodeRabbit review findings across repos/PRs
# to surface recurring patterns worth encoding as shift-left cpm rules.
#
# CodeRabbit posts review comments as the GitHub bot user "coderabbitai[bot]".
# This walks recent (default: merged) PRs across one or more repos, extracts
# each inline comment, normalises it into a coarse "signal" (category + short
# title), and ranks signals by frequency. High-frequency signals are the best
# candidates to turn into a cpm rule (catch it locally, before review).
#
# Usage:
#   coderabbit-harvest.sh <owner/repo> [<owner/repo> ...] [options]
#   coderabbit-harvest.sh --org <github-org> [options]
#   coderabbit-harvest.sh --group <gitlab-group> [options]
#   coderabbit-harvest.sh --help
#
# Sources (combine freely — findings are merged into one cross-repo ranking):
#   <owner/repo>        Explicit GitHub repos (space-separated).
#   --org <name>        All GitHub repos in an org (auto-discovered via gh).
#   --group <path>      All GitLab projects under a group + subgroups (glab).
#
# Options:
#   --state <merged|open|all>   PR/MR state to scan (default: merged)
#   --limit <N>                 Max PRs/MRs per repo (default: 30)
#   --out <dir>                 Output dir (default: .cache/coderabbit)
#   --min <N>                   Only report signals seen >= N times (default: 2)
#   --repo-limit <N>            Max repos to pull from --org/--group (default: 50)
#   --sleep <sec>               Pause between repos/MR-batches (default: 1).
#                               Use a higher value for large overnight runs.
#   --resume                    Skip repos/PRs already recorded in the run's
#                               done-log, so an interrupted overnight harvest
#                               can be re-run without redoing work.
#
# Overnight runs: point at a whole org/group, raise --repo-limit and --limit,
# keep --sleep >= 1, add --resume, and run under nohup/at. The script self-
# throttles and backs off on GitHub rate-limit (HTTP 403 + reset header).
#
# Requires: gh (GitHub) and/or glab (GitLab), plus jq. Read-only: makes no
# changes to any repo. Credentials come from gh/glab's own auth — nothing is
# hardcoded here.
#
# @see checks/universal/quality/check-coderabbit-patterns.sh (already-encoded
#      patterns; this harvester finds the NEXT ones to encode).

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

STATE="merged"
LIMIT=30
OUT=".cache/coderabbit"
MIN=2
REPO_LIMIT=50
SLEEP=1
RESUME=0
GH_ORG=""
GL_GROUP=""
REPOS=()

_usage() {
  sed -n '2,48p' "$0" | sed 's/^# \{0,1\}//'
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    _usage
    exit 0
    ;;
  --state)
    STATE="${2:?--state needs a value}"
    shift 2
    ;;
  --limit)
    LIMIT="${2:?--limit needs a value}"
    shift 2
    ;;
  --out)
    OUT="${2:?--out needs a value}"
    shift 2
    ;;
  --min)
    MIN="${2:?--min needs a value}"
    shift 2
    ;;
  --org)
    GH_ORG="${2:?--org needs a value}"
    shift 2
    ;;
  --group)
    GL_GROUP="${2:?--group needs a value}"
    shift 2
    ;;
  --repo-limit)
    REPO_LIMIT="${2:?--repo-limit needs a value}"
    shift 2
    ;;
  --sleep)
    SLEEP="${2:?--sleep needs a value}"
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
    REPOS+=("$1")
    shift
    ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  echo "Error: 'jq' is required." >&2
  exit 1
}

# --- Cross-repo discovery ---
# GitHub org: auto-discover every non-archived repo.
if [[ -n "$GH_ORG" ]]; then
  command -v gh >/dev/null 2>&1 || {
    echo "Error: 'gh' required for --org." >&2
    exit 1
  }
  echo "Discovering GitHub repos in org '$GH_ORG' (max $REPO_LIMIT)..."
  while IFS= read -r r; do [[ -n "$r" ]] && REPOS+=("$r"); done < <(
    gh repo list "$GH_ORG" --no-archived --limit "$REPO_LIMIT" \
      --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null || true
  )
fi

# Default to the current repo's origin if no GitHub source was given at all.
if [[ ${#REPOS[@]} -eq 0 && -z "$GL_GROUP" ]]; then
  origin=$(git remote get-url origin 2>/dev/null | sed 's#.*github.com[/:]##; s#\.git$##' || true)
  [[ -n "$origin" ]] && REPOS+=("$origin")
fi

if [[ ${#REPOS[@]} -eq 0 && -z "$GL_GROUP" ]]; then
  echo "Error: no repos, no --org, no --group, and no github origin detected." >&2
  _usage
  exit 2
fi

mkdir -p "$OUT"
RAW="$OUT/comments.jsonl"
DONE="$OUT/done.log" # keys of already-processed repos/PRs (for --resume)
touch "$DONE"
# On a fresh (non-resume) run start clean; on --resume keep prior data.
if [[ "$RESUME" -eq 0 ]]; then
  : >"$RAW"
  : >"$DONE"
fi

# throttle: pause between API-heavy steps to stay under rate limits.
_throttle() { [[ "$SLEEP" != "0" ]] && sleep "$SLEEP" || true; }

# mark/seen: resumability. A key is e.g. "gh:owner/repo#123".
_seen() { grep -qxF "$1" "$DONE" 2>/dev/null; }
_mark() { printf '%s\n' "$1" >>"$DONE"; }

# gh_api: wrapper that respects GitHub's rate limit. On HTTP 403 with a
# rate-limit reset, it waits until the reset (capped) and retries once. Keeps
# an overnight run alive instead of dying mid-harvest.
_gh_api() {
  local out rc
  out=$(gh api "$@" 2>/tmp/cr-gh-err)
  rc=$?
  if [[ $rc -ne 0 ]] && grep -qi 'rate limit\|API rate' /tmp/cr-gh-err; then
    local reset now wait
    reset=$(gh api rate_limit --jq '.resources.core.reset' 2>/dev/null || echo 0)
    now=$(date +%s)
    wait=$((reset - now))
    [[ $wait -lt 0 ]] && wait=60
    [[ $wait -gt 3600 ]] && wait=3600
    echo "  ⏳ rate limited — sleeping ${wait}s until reset..." >&2
    sleep "$wait"
    out=$(gh api "$@" 2>/dev/null) || return 1
  fi
  printf '%s' "$out"
}

echo "CodeRabbit harvest — state=$STATE limit=$LIMIT repos=${REPOS[*]}"
echo ""

# --- Collect inline review comments from CodeRabbit across PRs (GitHub) ---
total_comments=0
if [[ ${#REPOS[@]} -gt 0 ]]; then
  command -v gh >/dev/null 2>&1 || {
    echo "Error: 'gh' required for GitHub repos." >&2
    exit 1
  }
  for repo in "${REPOS[@]}"; do
    echo "» [gh] $repo: listing $STATE PRs (max $LIMIT)..."
    prs=$(gh pr list --repo "$repo" --state "$STATE" --limit "$LIMIT" \
      --json number --jq '.[].number' 2>/dev/null || true)
    [[ -z "$prs" ]] && {
      echo "  (no PRs or no access)"
      continue
    }
    while IFS= read -r pr; do
      [[ -z "$pr" ]] && continue
      key="gh:$repo#$pr"
      if [[ "$RESUME" -eq 1 ]] && _seen "$key"; then continue; fi
      _gh_api "repos/$repo/pulls/$pr/comments" --paginate \
        --jq '.[] | select(.user.login == "coderabbitai[bot]")
               | {source: "github", repo: "'"$repo"'", ref: '"$pr"', path, line, body}' \
        >>"$RAW" 2>/dev/null || true
      _mark "$key"
      _throttle
    done <<<"$prs"
    n=$(grep -cF "\"repo\":\"$repo\"" "$RAW" 2>/dev/null) || n=0
    echo "  collected $n comment(s) (cumulative for $repo)"
  done
fi

# --- Collect CodeRabbit MR notes across a GitLab group + subgroups ---
# CodeRabbit's GitLab bot username can vary per install; match any author whose
# username/name contains "coderabbit". MR notes carry the review body.
if [[ -n "$GL_GROUP" ]]; then
  command -v glab >/dev/null 2>&1 || {
    echo "Error: 'glab' required for --group." >&2
    exit 1
  }
  echo "» [glab] discovering projects under group '$GL_GROUP' (max $REPO_LIMIT)..."
  proj_ids=$(glab api "groups/$GL_GROUP/projects?per_page=$REPO_LIMIT&include_subgroups=true&archived=false" \
    2>/dev/null | jq -r '.[].id' || true)
  [[ -z "$proj_ids" ]] && echo "  (no projects or no access)"
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    # State mapping: GitLab uses merged|opened|all.
    gl_state="$STATE"
    [[ "$STATE" == "open" ]] && gl_state="opened"
    mrs=$(glab api "projects/$pid/merge_requests?state=$gl_state&per_page=$LIMIT" \
      2>/dev/null | jq -r '.[].iid' || true)
    [[ -z "$mrs" ]] && continue
    while IFS= read -r iid; do
      [[ -z "$iid" ]] && continue
      key="gl:$pid!$iid"
      if [[ "$RESUME" -eq 1 ]] && _seen "$key"; then continue; fi
      glab api "projects/$pid/merge_requests/$iid/notes?per_page=100" 2>/dev/null |
        jq -c '.[] | select((.author.username // "" | ascii_downcase | test("coderabbit"))
                            or (.author.name // "" | ascii_downcase | test("coderabbit")))
                 | {source: "gitlab", repo: "gl:'"$pid"'", ref: '"$iid"', path: null, line: null, body}' \
          >>"$RAW" || true
      _mark "$key"
      _throttle
    done <<<"$mrs"
  done <<<"$proj_ids"
  gln=$(grep -cF '"source":"gitlab"' "$RAW" 2>/dev/null) || gln=0
  echo "  collected $gln GitLab note(s)"
fi

echo ""
# Source of truth is the JSONL; the definitive total is its line count
# (append-only, so this stays correct across --resume runs too).
total_comments=$(wc -l <"$RAW" 2>/dev/null | tr -d ' ')
[[ -z "$total_comments" ]] && total_comments=0
echo "Total CodeRabbit comments harvested: $total_comments"
[[ "$total_comments" -eq 0 ]] && {
  echo "Nothing to rank."
  exit 0
}

# --- Normalise each comment into a coarse signal ---
# Storage model:
#   comments.jsonl  = source of truth (one raw comment per line, append-only,
#                     resume-friendly — mirrors cpm's findings.jsonl choice).
#   signals.csv     = derived, spreadsheet-friendly aggregate (safely quoted
#                     via jq @csv, so review text with commas/newlines is fine).
#   ranked.md       = derived, human-readable report.
# We deliberately do NOT keep a separate raw .dat: the full body already lives,
# safely escaped, in the JSONL body field — one source of truth beats two.
#
# CodeRabbit inline comments have a stable shape:
#   line 1 : "_🩺 <Category>_ | _🟠 <Severity>_ | _⚡ <tag>_"
#   line 3 : "**<one-line advice>**"
#   then   : prose, then collapsible "<details>...</details>" blocks (Tools,
#            zizmor, "Prompt for AI Agents") that must NOT be mined.
# So we: (1) read the category from line 1 (strip _underscores_, emoji and the
# part after the first "|"); (2) truncate the body at the first "<details>" and
# take the FIRST bold span from that head as the advice title. Comments without
# a bold head (thread replies like "thanks for the fix") are dropped.
# Pure jq — no inline Python.
SIGNALS="$OUT/signals.csv"
echo "category,title,repo,ref" >"$SIGNALS"

jq -r '
  # --- category from line 1 ---
  ( .body | split("\n")[0] // "" ) as $l1
  | ( $l1 | split("|")[0] // ""            # take the first "| ... |" segment
          | gsub("_";"")                    # drop italics underscores
          | gsub("[^A-Za-z& ]";"")          # drop emoji/punctuation
          | gsub("^ +| +$";"") ) as $cat_raw
  | ( if ($cat_raw | length) > 0 then $cat_raw else "Uncategorised" end) as $cat
  # --- advice title: first **bold** BEFORE the first <details> ---
  | ( .body | split("<details>")[0] ) as $head
  | ( $head | [ scan("\\*\\*([^*]{3,140})\\*\\*") ] | .[0][0] // null ) as $bold
  | select($bold != null)                    # skip replies / non-advice notes
  | ( $bold | gsub("`";"") | gsub("^ +| +$";"") ) as $title
  | [$cat, $title, (.repo // ""), (.ref // "" | tostring)] | @csv
' "$RAW" >>"$SIGNALS"

# --- Rank signals by (category,title) frequency ---
REPORT="$OUT/ranked.md"
{
  echo "# CodeRabbit recurring findings — shift-left candidates"
  echo ""
  echo "Harvested $total_comments comment(s) across GitHub repos [${REPOS[*]:-none}]"
  echo "and GitLab group [${GL_GROUP:-none}]."
  echo "State=$STATE, limit=$LIMIT/repo. Showing signals seen >= $MIN times."
  echo ""
  echo "## By category"
  echo ""
  echo "| Count | Category |"
  echo "|------:|----------|"
  # Category distribution (col 1 of the CSV), quotes stripped.
  tail -n +2 "$SIGNALS" |
    sed -E 's/^"([^"]*)".*/\1/' |
    sort | uniq -c | sort -rn |
    while read -r count cat; do printf '| %s | %s |\n' "$count" "$cat"; done
  echo ""
  echo "## Recurring advice (candidate rules)"
  echo ""
  echo "| Count | Category | Signal (candidate rule) |"
  echo "|------:|----------|-------------------------|"
  # Rank on (category,title). Extract the first two quoted CSV fields robustly.
  tail -n +2 "$SIGNALS" |
    sed -E 's/^"([^"]*)","([^"]*)".*/\1\t\2/' |
    sort | uniq -c | sort -rn | while read -r count rest; do
    [[ "$count" -lt "$MIN" ]] && continue
    cat=$(printf '%s' "$rest" | cut -f1)
    title=$(printf '%s' "$rest" | cut -f2- | sed 's/|/\\|/g')
    printf '| %s | %s | %s |\n' "$count" "$cat" "$title"
  done
  echo ""
  echo "## Recurring topics (cross-repo rule candidates)"
  echo ""
  echo "Exact titles rarely repeat across repos, but *topics* do. Each row below"
  echo "counts comments whose body matches the topic, plus how many distinct repos"
  echo "raised it — breadth (repos) is the strongest signal for a shift-left rule."
  echo ""
  echo "| Comments | Repos | Topic |"
  echo "|---------:|------:|-------|"
  # Topic buckets: label<TAB>regex. Kept in the report so the mining is
  # transparent and tweakable. Matched against the raw body via jq (recall).
  while IFS=$'\t' read -r label regex; do
    [[ -z "$label" || "$label" == \#* ]] && continue
    hits=$(jq -r --arg re "$regex" 'select(.body|test($re;"i")) | .repo' "$RAW" 2>/dev/null)
    [[ -z "$hits" ]] && continue
    n=$(printf '%s\n' "$hits" | grep -c .)
    repos=$(printf '%s\n' "$hits" | sort -u | grep -c .)
    [[ "$n" -lt "$MIN" ]] && continue
    printf '| %s | %s | %s |\n' "$n" "$repos" "$label"
  done <<'TOPICS' | sort -t'|' -k3 -rn
resource leak / handle not closed	leak|not closed|unclosed|dispose|resource.{0,12}(leak|free)|missing close
integer overflow / underflow	overflow|underflow
input not validated	unvalidated|validate .*(before|input)|missing validation
command / SQL injection	injection|sanitiz|shell escap|command injection
too-broad file permissions	0o777|world-writable|overly broad permission|chmod 777
unsafe regex / ReDoS	redos|catastrophic backtrack|unsafe regex
swallowed / silent errors	swallow|silently (ignored|fail)|empty catch|except: *pass
missing timeout	without a timeout|no timeout|missing timeout
non-atomic file write	atomic write|write.*temporary file.*rename|temp.*then rename
race condition / TOCTOU	race condition|TOCTOU|time-of-check
null / nil dereference	null deref|nil deref|possible null|could be null|none-check
TOPICS
} >"$REPORT"

echo ""
echo "Sources    : comments.jsonl (source of truth)"
echo "Ranked     : $REPORT"
echo "Signals CSV: $SIGNALS"
echo ""
echo "Top candidates:"
# Show the ranked table rows (skip the markdown header block).
grep -E '^\| *[0-9]' "$REPORT" | head -10 | sed 's/^/  /' || true
echo ""
echo "Next: compare high-count signals against checks/universal/quality/"
echo "check-coderabbit-patterns.sh — anything not yet covered is a new cpm rule."
