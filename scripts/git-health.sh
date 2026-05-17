#!/usr/bin/env bash
# scripts/git-health.sh — Extract quality signals from git history
# Usage: bash scripts/git-health.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
cd "$REPO" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "  Not a git repo"; exit 0; }

echo ""
echo "  ■ Git Health: $(basename "$(pwd)")"
echo ""

# === 1. Activity & Freshness ===
echo "  Activity:"
LAST_COMMIT=$(git log -1 --format="%cr" 2>/dev/null)
FIRST_COMMIT=$(git log --reverse --format="%cr" 2>/dev/null | head -1)
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null)
printf "    Last commit:    %s\n" "$LAST_COMMIT"
printf "    First commit:   %s\n" "$FIRST_COMMIT"
printf "    Total commits:  %s\n" "$TOTAL_COMMITS"

# Commits last 30 days
RECENT=$(git rev-list --count --since="30 days ago" HEAD 2>/dev/null)
printf "    Last 30 days:   %s commits\n" "$RECENT"
[ "${RECENT:-0}" -eq 0 ] && printf "    ⚠ No activity in 30 days — possibly abandoned\n"
echo ""

# === 2. Contributors & Bus Factor ===
echo "  Contributors:"
AUTHORS=$(git shortlog -sn --no-merges HEAD 2>/dev/null)
AUTHOR_COUNT=$(echo "$AUTHORS" | grep -c "." || echo 0)
printf "    Total authors:  %s\n" "$AUTHOR_COUNT"

# Top contributors
echo "$AUTHORS" | head -5 | while read -r count name; do
  PCT=$((count * 100 / TOTAL_COMMITS))
  printf "    %4d (%2d%%)  %s\n" "$count" "$PCT" "$name"
done

# Bus factor warning
TOP_PCT=$(echo "$AUTHORS" | head -1 | awk "{print int(\$1 * 100 / $TOTAL_COMMITS)}")
[ "${TOP_PCT:-0}" -gt 80 ] && printf "    ⚠ Bus factor: 1 person wrote %s%% of commits\n" "$TOP_PCT"
echo ""

# === 3. Commit Hygiene ===
echo "  Commit Hygiene:"
# Short/vague messages
VAGUE=$(git log --oneline -100 2>/dev/null | grep -ciE "^[a-f0-9]+ (fix|update|wip|temp|test|stuff|changes|misc|asdf)" || echo 0)
printf "    Vague messages (last 100): %s\n" "$VAGUE"
[ "$VAGUE" -gt 20 ] && printf "    ⚠ Poor commit messages — consider conventional commits\n"

# Conventional commits ratio
CONVENTIONAL=$(git log --oneline -100 2>/dev/null | grep -cE "^[a-f0-9]+ (feat|fix|chore|docs|style|refactor|test|ci|perf|build)\(" || echo 0)
printf "    Conventional commits:      %s/100\n" "$CONVENTIONAL"

# Mega-commits (>20 files changed)
MEGA=$(git log --shortstat -50 2>/dev/null | grep -E "[0-9]+ files? changed" | awk '{if($1>20) print}' | wc -l | tr -d ' ')
printf "    Mega-commits (>20 files):  %s (last 50)\n" "$MEGA"
[ "$MEGA" -gt 5 ] && printf "    ⚠ Too many mega-commits — break into smaller changes\n"
echo ""

# === 4. Hotspots (most changed files) ===
echo "  Hotspots (most changed files — likely complex/risky):"
git log --name-only --pretty=format: -100 2>/dev/null | \
  grep -v "^$" | sort | uniq -c | sort -rn | \
  grep -vE "package-lock|yarn\.lock|pnpm-lock|CHANGELOG" | \
  head -8 | awk '{printf "    %4d changes  %s\n", $1, $2}'
echo ""

# === 5. Stale branches ===
echo "  Branches:"
BRANCH_COUNT=$(git branch -a 2>/dev/null | wc -l | tr -d ' ')
printf "    Total: %s\n" "$BRANCH_COUNT"
STALE=$(git branch -a --sort=committerdate 2>/dev/null | head -5 | wc -l | tr -d ' ')
MERGED=$(git branch --merged main 2>/dev/null | grep -v "main\|master\|\*" | wc -l | tr -d ' ')
[ "${MERGED:-0}" -gt 0 ] && printf "    ⚠ %s merged branches not deleted\n" "$MERGED"
echo ""

# === 6. Burst patterns (commit frequency) ===
echo "  Work Patterns:"
# Commits per day of week
echo "    Commits by day:"
git log --format="%ad" --date=format:"%a" -200 2>/dev/null | sort | uniq -c | sort -rn | \
  head -7 | awk '{printf "      %s %s\n", $2, $1}'

# Weekend/night work
WEEKEND=$(git log --format="%ad" --date=format:"%u" -200 2>/dev/null | grep -c "[67]" || echo 0)
NIGHT=$(git log --format="%ad" --date=format:"%H" -200 2>/dev/null | grep -cE "^(2[2-3]|0[0-5])" || echo 0)
[ "$WEEKEND" -gt 20 ] && printf "    ⚠ %s weekend commits (last 200) — possible crunch\n" "$WEEKEND"
[ "$NIGHT" -gt 10 ] && printf "    ⚠ %s night commits (22:00-05:00) — possible overwork\n" "$NIGHT"
echo ""

# === 7. Code churn (files rewritten quickly) ===
echo "  Churn (files changed then changed again within 7 days):"
git log --name-only --pretty=format:"%H %ai" --since="60 days ago" 2>/dev/null | \
  grep -v "^$\|^[a-f0-9]" | sort | uniq -c | sort -rn | \
  grep -vE "package-lock|yarn\.lock|CHANGELOG" | \
  head -5 | awk '$1 > 3 {printf "    %4d times  %s\n", $1, $2}'
echo ""
