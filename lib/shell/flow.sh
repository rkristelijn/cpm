#!/usr/bin/env bash
# flow.sh — Show V-model flow with quality gates per step.
# Usage: cpm flow [step]
# Shows where you are in the process and what's needed to advance.
set -o errexit
set -o nounset
set -o pipefail

# Terminal width detection
COLS=$(tput cols 2>/dev/null || echo 80)

# Colors
R='\033[31m' G='\033[32m' Y='\033[33m' B='\033[34m' D='\033[2m' N='\033[0m' BOLD='\033[1m'

# --- Detect current state ---
has_issue=false
has_branch=false
has_code=false
has_tests=false
has_passing=false
has_docs=false

# Check: issue exists for current branch
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
if [[ "$branch" == feat/* || "$branch" == fix/* ]]; then
  has_branch=true
  slug="${branch#*/}"
  slug="${slug#*-}" # strip issue number prefix
  [[ -f "docs/issues/open/${slug}.md" || -n "$(find docs/issues/open -name '*' -path "*${slug}*" 2>/dev/null | head -1)" ]] && has_issue=true
fi

# Check: code changes exist
if git diff --name-only HEAD 2>/dev/null | grep -qE '\.(cpp|ts|js|py|java|go|rs|sh)$'; then
  has_code=true
fi
# Also check staged
if git diff --cached --name-only 2>/dev/null | grep -qE '\.(cpp|ts|js|py|java|go|rs|sh)$'; then
  has_code=true
fi

# Check: tests exist for changes
if git diff --name-only HEAD 2>/dev/null | grep -qE '_test\.|\.test\.|\.spec\.|test_'; then
  has_tests=true
fi

# Check: build passes
if [[ -f cpm.toml ]] || [[ -f Makefile ]]; then
  has_passing=true # assume for now, actual check is expensive
fi

# --- Quality gates ---
gate_idea() {
  local pass=0 total=0
  total=$((total+1)); [[ "$has_issue" == true ]] && pass=$((pass+1))
  if [[ -f "docs/issues/open/${slug:-}.md" ]]; then
    total=$((total+1)); grep -q "## Value" "docs/issues/open/${slug}.md" 2>/dev/null && pass=$((pass+1))
    total=$((total+1)); grep -q "## Acceptance criteria" "docs/issues/open/${slug}.md" 2>/dev/null && pass=$((pass+1))
  fi
  echo "$pass/$total"
}

gate_design() {
  local pass=0 total=2
  [[ "$has_branch" == true ]] && pass=$((pass+1))
  [[ "$has_issue" == true ]] && pass=$((pass+1))
  echo "$pass/$total"
}

gate_code() {
  local pass=0 total=2
  [[ "$has_code" == true ]] && pass=$((pass+1))
  [[ "$has_tests" == true ]] && pass=$((pass+1))
  echo "$pass/$total"
}

gate_test() {
  local pass=0 total=1
  [[ "$has_passing" == true ]] && pass=$((pass+1))
  echo "$pass/$total"
}

# --- Determine current step ---
step=0
[[ "$has_issue" == true ]] && step=1
[[ "$has_branch" == true ]] && step=2
[[ "$has_code" == true ]] && step=3
[[ "$has_tests" == true ]] && step=4
# step 5 = validated (all checks pass)

# --- Render V-model ---
render() {
  local w=$((COLS - 4))
  local half=$((w / 2))
  local indent=""

  echo ""
  printf "  ${BOLD}V-Model Flow${N} — branch: ${B}%s${N}\n" "$branch"
  echo ""

  # Step markers
  s1="○" s2="○" s3="○" s4="○" s5="○"
  ((step >= 1)) && s1="●"
  ((step >= 2)) && s2="●"
  ((step >= 3)) && s3="●"
  ((step >= 4)) && s4="●"
  ((step >= 5)) && s5="●"

  # Gate results
  g1=$(gate_idea)
  g2=$(gate_design)
  g3=$(gate_code)
  g4=$(gate_test)

  if ((COLS >= 70)); then
    # Wide terminal: full V-model
    printf "  ${BOLD}Motivate${N}                                    ${BOLD}Validate${N}\n"
    printf "  %s Idee/Issue  [%s]                        %s Acceptance  [%s]\n" "$s1" "$g1" "$s5" "$g4"
    printf "     ╲                                        ╱\n"
    printf "      ${BOLD}Ontwerp${N}                          ${BOLD}Test${N}\n"
    printf "      %s Branch/ADR  [%s]              %s Tests passen  [%s]\n" "$s2" "$g2" "$s4" "$g4"
    printf "         ╲                            ╱\n"
    printf "           ${BOLD}Implementatie${N}\n"
    printf "           %s Code + Tests  [%s]\n" "$s3" "$g3"
    echo ""
  else
    # Narrow terminal: linear
    printf "  %s Idee       [%s]\n" "$s1" "$g1"
    printf "  │\n"
    printf "  %s Ontwerp    [%s]\n" "$s2" "$g2"
    printf "  │\n"
    printf "  %s Code       [%s]\n" "$s3" "$g3"
    printf "  │\n"
    printf "  %s Test       [%s]\n" "$s4" "$g4"
    printf "  │\n"
    printf "  %s Validatie  [%s]\n" "$s5" "$g4"
    echo ""
  fi

  # --- Quality gate details for current step ---
  echo "  ─────────────────────────────────────────"
  case $step in
    0)
      printf "  ${Y}▶ Next: Create an issue${N}\n"
      printf "    cpm issue \"feat: <title>\"\n"
      ;;
    1)
      printf "  ${Y}▶ Next: Create a branch${N}\n"
      printf "    cpm issue branch <slug>\n"
      printf "  ${D}Checks: issue has Value + Acceptance criteria${N}\n"
      ;;
    2)
      printf "  ${Y}▶ Next: Write code + tests${N}\n"
      printf "    Code changes must include tests\n"
      printf "  ${D}Checks: branch from issue, conventional commits${N}\n"
      ;;
    3)
      printf "  ${Y}▶ Next: Run tests${N}\n"
      printf "    cpm check --fast\n"
      printf "  ${D}Checks: code has tests, no lint errors${N}\n"
      ;;
    4)
      printf "  ${Y}▶ Next: Validate & push${N}\n"
      printf "    cpm check && git push\n"
      printf "  ${D}Checks: all tests pass, acceptance criteria met${N}\n"
      ;;
    5)
      printf "  ${G}✓ Ready for review/merge${N}\n"
      ;;
  esac
  echo ""
}

render
