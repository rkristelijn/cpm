#!/usr/bin/env bash
# checks/run-all.sh — Run all cpm checks and output JUnit XML
# Usage: bash checks/run-all.sh [repo-path] [--junit output.xml]
set -o nounset -o pipefail

REPO="${1:-.}"
JUNIT_OUT=""
[ "${2:-}" = "--junit" ] && JUNIT_OUT="${3:-findings.xml}"

CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FINDINGS=()
ERRORS=0; WARNINGS=0; INFOS=0; PASSED=0

# Capture findings from check output (parses ANSI colored output)
run_check() {
  local name="$1" script="$2"
  [ -f "$script" ] || return 0
  [ -x "$script" ] || return 0

  local output
  output=$(bash "$script" "$REPO" 2>/dev/null) || true

  if [ -z "$output" ]; then
    PASSED=$((PASSED + 1))
    return 0
  fi

  # Parse each line for severity
  while IFS= read -r line; do
    # Strip ANSI codes
    local clean
    clean=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//')
    [ -z "$clean" ] && continue

    local severity="info" check_id="" message=""
    if echo "$clean" | grep -q "^error"; then
      severity="error"
      check_id=$(echo "$clean" | awk '{print $2}')
      message=$(echo "$clean" | sed 's/^error[[:space:]]*[^ ]*//' | sed 's/^[[:space:]]*//')
      ERRORS=$((ERRORS + 1))
    elif echo "$clean" | grep -q "^warning"; then
      severity="warning"
      check_id=$(echo "$clean" | awk '{print $2}')
      message=$(echo "$clean" | sed 's/^warning[[:space:]]*[^ ]*//' | sed 's/^[[:space:]]*//')
      WARNINGS=$((WARNINGS + 1))
    elif echo "$clean" | grep -q "^info\|^✓\|FAIL\|WARN"; then
      severity="info"
      check_id="$name"
      message="$clean"
      INFOS=$((INFOS + 1))
    else
      continue
    fi

    FINDINGS+=("$severity|$name|$check_id|$message")
  done <<< "$output"
}

echo ""
echo "  cpm check --full ($(basename "$REPO"))"
echo "  ════════════════════════════════════════"
echo ""

# --- Universal checks ---
echo "  ▸ universal"
run_check "clean-code" "$CHECKS_DIR/universal/quality/check-clean-code.sh"
run_check "file-size" "$CHECKS_DIR/universal/quality/check-file-size.sh"
run_check "slop" "$CHECKS_DIR/universal/quality/check-slop.sh"
run_check "solid" "$CHECKS_DIR/universal/quality/check-solid.sh"
run_check "dora" "$CHECKS_DIR/universal/quality/check-dora.sh"
run_check "comment-ratio" "$CHECKS_DIR/universal/quality/check-comment-ratio.sh"
run_check "scripts" "$CHECKS_DIR/universal/quality/check-scripts.sh"
run_check "makefile" "$CHECKS_DIR/universal/check-makefile.sh"
run_check "secrets" "$CHECKS_DIR/universal/security/check-secrets-fast.sh"
run_check "pii" "$CHECKS_DIR/universal/security/check-pii.sh"
run_check "licenses" "$CHECKS_DIR/universal/deps/check-licenses.sh"
run_check "lockfile" "$CHECKS_DIR/universal/deps/check-lockfile.sh"
run_check "version-pins" "$CHECKS_DIR/universal/deps/check-version-pins.sh"

# --- Framework checks (auto-detect) ---
if [ -f "$REPO/package.json" ]; then
  echo "  ▸ javascript"
  run_check "package-json" "$CHECKS_DIR/javascript/check-package-json.sh"
  run_check "ts-dangerous" "$CHECKS_DIR/javascript/check-ts-dangerous.sh"
  run_check "runtime-pin" "$CHECKS_DIR/javascript/check-runtime-pin.sh"

  # React
  grep -q '"react"' "$REPO/package.json" 2>/dev/null && \
    run_check "react" "$CHECKS_DIR/javascript/check-react.sh"

  # NextJS
  grep -q '"next"' "$REPO/package.json" 2>/dev/null && \
    run_check "nextjs" "$CHECKS_DIR/javascript/nextjs/check-architecture.sh"

  # NestJS
  grep -q "@nestjs" "$REPO/package.json" 2>/dev/null && \
    run_check "nestjs" "$CHECKS_DIR/javascript/nestjs/check-nestjs.sh"

  # Angular
  grep -q "@angular/core" "$REPO/package.json" 2>/dev/null && \
    run_check "angular" "$CHECKS_DIR/javascript/angular/check-angular.sh"

  # Nx
  [ -f "$REPO/nx.json" ] && \
    run_check "nx" "$CHECKS_DIR/javascript/nx/check-nx-workspace.sh"
fi

# Terraform
if find "$REPO" -maxdepth 2 -name "*.tf" 2>/dev/null | grep -q .; then
  echo "  ▸ terraform"
  run_check "tf-patterns" "$CHECKS_DIR/terraform/check-tf-patterns.sh"
fi

# --- Output findings ---
echo ""
echo "  ────────────────────────────────────────"
printf "  %d errors  %d warnings  %d info  %d passed\n" "$ERRORS" "$WARNINGS" "$INFOS" "$PASSED"
echo ""

# Print findings grouped by severity
if [ "$ERRORS" -gt 0 ]; then
  echo "  🔴 ERRORS (must fix)"
  for f in "${FINDINGS[@]}"; do
    IFS='|' read -r sev suite id msg <<< "$f"
    [ "$sev" = "error" ] && printf "     %-30s %s\n" "$id" "$msg"
  done
  echo ""
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo "  🟡 WARNINGS (should fix)"
  for f in "${FINDINGS[@]}"; do
    IFS='|' read -r sev suite id msg <<< "$f"
    [ "$sev" = "warning" ] && printf "     %-30s %s\n" "$id" "$msg"
  done
  echo ""
fi

if [ "$INFOS" -gt 0 ]; then
  echo "  🔵 INFO (consider)"
  for f in "${FINDINGS[@]}"; do
    IFS='|' read -r sev suite id msg <<< "$f"
    [ "$sev" = "info" ] && printf "     %-30s %s\n" "$id" "$msg"
  done
  echo ""
fi

# --- JUnit XML output ---
if [ -n "$JUNIT_OUT" ]; then
  local_total=${#FINDINGS[@]}
  cat > "$JUNIT_OUT" << XMLHEADER
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="cpm-checks" tests="$((ERRORS + WARNINGS + INFOS + PASSED))" failures="$ERRORS" errors="0" skipped="0">
XMLHEADER

  # Group by suite
  declare -A SUITES
  for f in "${FINDINGS[@]}"; do
    IFS='|' read -r sev suite id msg <<< "$f"
    SUITES["$suite"]+="    <testcase name=\"$id\" classname=\"cpm.$suite\">"$'\n'
    if [ "$sev" = "error" ]; then
      SUITES["$suite"]+="      <failure message=\"$msg\" type=\"$sev\"/>"$'\n'
    elif [ "$sev" = "warning" ]; then
      SUITES["$suite"]+="      <system-out>WARNING: $msg</system-out>"$'\n'
    else
      SUITES["$suite"]+="      <system-out>INFO: $msg</system-out>"$'\n'
    fi
    SUITES["$suite"]+="    </testcase>"$'\n'
  done

  for suite in "${!SUITES[@]}"; do
    echo "  <testsuite name=\"$suite\">" >> "$JUNIT_OUT"
    echo "${SUITES[$suite]}" >> "$JUNIT_OUT"
    echo "  </testsuite>" >> "$JUNIT_OUT"
  done

  echo "</testsuites>" >> "$JUNIT_OUT"
  echo "  📄 JUnit XML: $JUNIT_OUT"
fi

exit 0
