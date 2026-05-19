#!/usr/bin/env bash
#
# check-dora.sh — Calculate DORA-like metrics from git log.
# Measures: deployment frequency, lead time proxy, change failure rate,
# commit regularity, bus factor, and commit message quality.

source "$(dirname "$0")/../../../lib/shell/check.sh"
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "calculating DORA metrics..."

# Configuration
WEEKS=4

# --- Deployment Frequency ---
commits_4w=$(git log --since="${WEEKS} weeks ago" --oneline 2>/dev/null | wc -l)
commits_per_week=$((commits_4w / WEEKS))

if [[ $commits_per_week -ge 20 ]]; then
  df_level="Elite"
  df_desc="on demand"
elif [[ $commits_per_week -ge 7 ]]; then
  df_level="High"
  df_desc="daily-weekly"
elif [[ $commits_per_week -ge 1 ]]; then
  df_level="Medium"
  df_desc="weekly-monthly"
else
  df_level="Low"
  df_desc="monthly-yearly"
fi

print_step "deployment frequency" "$commits_per_week/week" "$df_level" "$df_desc"

# --- Lead Time Proxy (avg time between commits) ---
timestamps=$(git log --format="%ai" --since="${WEEKS} weeks ago" 2>/dev/null)
if [[ -n "$timestamps" ]]; then
  prev=""
  total_diff=0
  count=0
  while IFS= read -r ts; do
    if [[ -n "$prev" ]]; then
      curr_sec=$(date -d "$ts" +%s 2>/dev/null || echo 0)
      prev_sec=$(date -d "$prev" +%s 2>/dev/null || echo 0)
      if [[ $curr_sec -gt 0 && $prev_sec -gt 0 ]]; then
        diff=$((curr_sec - prev_sec))
        total_diff=$((total_diff + diff))
        count=$((count + 1))
      fi
    fi
    prev="$ts"
  done <<< "$timestamps"

  if [[ $count -gt 0 ]]; then
    avg_hours=$((total_diff / count / 3600))
  else
    avg_hours=999
  fi
else
  avg_hours=999
fi

if [[ $avg_hours -lt 1 ]]; then
  lt_level="Elite"
  lt_desc="<1hr"
elif [[ $avg_hours -lt 24 ]]; then
  lt_level="High"
  lt_desc="1day-1week"
elif [[ $avg_hours -lt 168 ]]; then
  lt_level="Medium"
  lt_desc="1week-1month"
else
  lt_level="Low"
  lt_desc="1month-6months"
fi

print_step "lead time (proxy)" "~${avg_hours}h between commits" "$lt_level" "$lt_desc"

# --- Change Failure Rate (revert/fix ratio) ---
reverts=$(git log --grep="revert" --since="${WEEKS} weeks ago" --oneline 2>/dev/null | wc -l)
fixes=$(git log --grep="^fix" --since="${WEEKS} weeks ago" --oneline 2>/dev/null | wc -l)
failures=$((reverts + fixes))

if [[ $commits_4w -gt 0 ]]; then
  cfr=$((failures * 100 / commits_4w))
else
  cfr=0
fi

if [[ $cfr -le 15 ]]; then
  cfr_level="Elite"
  cfr_desc="0-15%"
elif [[ $cfr -le 30 ]]; then
  cfr_level="High"
  cfr_desc="16-30%"
elif [[ $cfr -le 45 ]]; then
  cfr_level="Medium"
  cfr_desc="31-45%"
else
  cfr_level="Low"
  cfr_desc="46-60%"
fi

print_step "change failure rate (proxy)" "${cfr}% ($failures/$commits_4w)" "$cfr_level" "$cfr_desc"

# --- Commit Regularity (days with commits) ---
days_with_commits=$(git log --since="${WEEKS} weeks ago" --format="%ad" --date=short 2>/dev/null | sort -u | wc -l)
total_days=$((WEEKS * 7))
regularity_pct=$((days_with_commits * 100 / total_days))

if [[ $days_with_commits -ge $total_days ]]; then
  reg_level="Elite"
  reg_desc="every day"
elif [[ $days_with_commits -ge 21 ]]; then
  reg_level="High"
  reg_desc="most days"
elif [[ $days_with_commits -ge 7 ]]; then
  reg_level="Medium"
  reg_desc="some days"
else
  reg_level="Low"
  reg_desc="infrequent"
fi

print_step "commit regularity" "${days_with_commits}/${total_days} days" "$reg_level" "$reg_desc"

# --- Bus Factor (unique authors) ---
authors_4w=$(git log --since="${WEEKS} weeks ago" --format="%an" 2>/dev/null | sort -u | wc -l)
authors_all=$(git log --format="%an" 2>/dev/null | sort -u | wc -l)

if [[ $authors_4w -ge 4 ]]; then
  bf_level="Healthy"
  bf_desc="$authors_4w active"
elif [[ $authors_4w -ge 2 ]]; then
  bf_level="Moderate"
  bf_desc="$authors_4w active"
else
  bf_level="Risk"
  bf_desc="$authors_4w active"
fi

print_step "bus factor" "$authors_4w (4w) / $authors_all (all)" "$bf_level" "$bf_desc"

# --- Commit Message Quality (conventional commits) ---
conventional=$(git log --since="${WEEKS} weeks ago" --format="%s" 2>/dev/null | \
  grep -E "^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\([^)]+\))?: " | wc -l)

if [[ $commits_4w -gt 0 ]]; then
  conv_pct=$((conventional * 100 / commits_4w))
else
  conv_pct=0
fi

if [[ $conv_pct -ge 90 ]]; then
  cq_level="Elite"
  cq_desc=">90%"
elif [[ $conv_pct -ge 70 ]]; then
  cq_level="High"
  cq_desc="70-90%"
elif [[ $conv_pct -ge 50 ]]; then
  cq_level="Medium"
  cq_desc="50-70%"
else
  cq_level="Low"
  cq_desc="<50%"
fi

print_step "commit quality" "${conv_pct}% conventional" "$cq_level" "$cq_desc"

# --- Summary ---
echo ""
echo "DORA Metrics Summary (last ${WEEKS} weeks)"
echo "=========================================="
printf "%-25s %-15s %-10s\n" "Metric" "Value" "Level"
printf "%-25s %-15s %-10s\n" "Deployment Frequency" "${commits_per_week}/week" "$df_level"
printf "%-25s %-15s %-10s\n" "Lead Time (proxy)" "~${avg_hours}h" "$lt_level"
printf "%-25s %-15s %-10s\n" "Change Failure Rate" "${cfr}%" "$cfr_level"
printf "%-25s %-15s %-10s\n" "Commit Regularity" "${days_with_commits}d" "$reg_level"
printf "%-25s %-15s %-10s\n" "Bus Factor" "$authors_4w" "$bf_level"
printf "%-25s %-15s %-10s\n" "Commit Quality" "${conv_pct}%" "$cq_level"

exit 0