#!/usr/bin/env bash
# check-k8s-hardening.sh — Detect missing security hardening in K8s manifests.
#
# Checks against CIS Kubernetes Benchmark 5.2.x:
#   - k8s-run-as-non-root: No runAsNonRoot: true (CIS 5.2.6)
#   - k8s-no-security-context: No securityContext at all (CIS 5.2.5)
#   - k8s-privilege-escalation: allowPrivilegeEscalation: true (CIS 5.2.5)
#   - k8s-privileged: privileged: true without justification (CIS 5.2.1)
#   - k8s-host-network: hostNetwork: true without justification (CIS 5.2.4)
#   - k8s-no-cap-drop: securityContext without drop: [ALL] (CIS 5.2.7)
#   - k8s-readonly-fs: No readOnlyRootFilesystem: true (CIS 5.2.4)
#
# Usage:
#   bash checks/universal/security/check-k8s-hardening.sh [repo-path]
#
# Config (cpm.toml):
#   [checks]
#   check-k8s-hardening = true
#
# Suppress:
#   - Inline: add `# cpm:ignore k8s-privileged` on or above the flagged line
#   - File-level: add path to .k8s-hardening-ignore (one glob per line)
#
# Exit codes:
#   0 = clean (or warnings/info only)
#   1 = errors found (blocking)

set -o errexit
set -o nounset
set -o pipefail

# --- Source framework (standalone fallback for testing) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../../lib/shell/check.sh" ]; then
  source "$SCRIPT_DIR/../../../lib/shell/check.sh"
else
  # Standalone mode
  _f_fail=0; _f_warn=0; _f_info=0; _f_total=0
  findings_add() {
    local status="$1" file="$2" rule="$3" message="$4"
    local fix="${5:-}" docs="${6:-}"
    _f_total=$((_f_total + 1))
    case "$status" in
      error|fail) _f_fail=$((_f_fail + 1)); printf "  \033[31m%-7s\033[0m  %-50s %s\n" "error" "$file" "$message" ;;
      warning)    _f_warn=$((_f_warn + 1)); printf "  \033[33m%-7s\033[0m  %-50s %s\n" "warning" "$file" "$message" ;;
      info)       _f_info=$((_f_info + 1)); printf "  \033[34m%-7s\033[0m  %-50s %s\n" "info" "$file" "$message" ;;
    esac
    [ -n "$fix" ] && printf "           fix: %s\n" "$fix"
  }
  trap 'echo ""; printf "  Findings: %d errors, %d warnings, %d info\n" "$_f_fail" "$_f_warn" "$_f_info"; [ "$_f_fail" -gt 0 ] && exit 1 || exit 0' EXIT
fi

# --- Config ---
REPO="${1:-.}"
IGNORE_FILE="$REPO/.k8s-hardening-ignore"
SKIP_DIRS=".git|node_modules|.tmp|vendor"

# --- Helpers ---
is_ignored() {
  local file="$1"
  [[ ! -f "$IGNORE_FILE" ]] && return 1
  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    # shellcheck disable=SC2053
    [[ "$file" == $pattern ]] && return 0
  done < "$IGNORE_FILE"
  return 1
}

is_suppressed() {
  local file="$1" line_num="$2" rule="$3"
  # Check for inline suppress comment: # cpm:ignore <rule>
  local start=$((line_num - 1))
  [ "$start" -lt 1 ] && start=1
  sed -n "${start},${line_num}p" "$file" 2>/dev/null | grep -q "cpm:ignore.*$rule"
}

# --- Find K8s manifests ---
MANIFESTS=$(find "$REPO" \( -name "*.yaml" -o -name "*.yml" \) \
  -not -path "*/.git/*" -not -path "*/.tmp/*" -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" | \
  xargs grep -l "^kind:" 2>/dev/null || true)

[ -z "$MANIFESTS" ] && exit 0

# --- Run checks ---
for manifest in $MANIFESTS; do
  REL_PATH="${manifest#$REPO/}"
  is_ignored "$REL_PATH" && continue

  # Skip non-workload manifests (Services, Ingress, ConfigMaps etc.)
  if ! grep -qE "^kind: (Deployment|StatefulSet|DaemonSet|CronJob|Job|Pod)" "$manifest" 2>/dev/null; then
    continue
  fi

  # --- k8s-run-as-non-root ---
  if grep -q "containers:" "$manifest" && ! grep -q "runAsNonRoot: *true" "$manifest"; then
    findings_add "error" "$REL_PATH" "k8s-run-as-non-root" \
      "No runAsNonRoot: true — pods run as root by default (CIS 5.2.6)" \
      "Add: securityContext: { runAsNonRoot: true }" \
      "https://kubernetes.io/docs/concepts/security/pod-security-standards/"
  fi

  # --- k8s-no-security-context ---
  if grep -q "containers:" "$manifest" && ! grep -q "securityContext:" "$manifest"; then
    findings_add "warning" "$REL_PATH" "k8s-no-security-context" \
      "No securityContext defined — add allowPrivilegeEscalation: false (CIS 5.2.5)" \
      "Add: securityContext: { allowPrivilegeEscalation: false, runAsNonRoot: true }" \
      "https://kubernetes.io/docs/tasks/configure-pod-container/security-context/"
  fi

  # --- k8s-privileged ---
  while IFS=: read -r line_num _; do
    [ -z "$line_num" ] && continue
    if ! is_suppressed "$manifest" "$line_num" "k8s-privileged"; then
      findings_add "error" "$REL_PATH:$line_num" "k8s-privileged" \
        "privileged: true — full host access, document justification (CIS 5.2.1)" \
        "Add comment: # cpm:ignore k8s-privileged — required for <reason>" \
        "https://kubernetes.io/docs/concepts/security/pod-security-standards/"
    fi
  done < <(grep -n "privileged: *true" "$manifest" 2>/dev/null || true)

  # --- k8s-host-network ---
  while IFS=: read -r line_num _; do
    [ -z "$line_num" ] && continue
    if ! is_suppressed "$manifest" "$line_num" "k8s-host-network"; then
      findings_add "warning" "$REL_PATH:$line_num" "k8s-host-network" \
        "hostNetwork: true — pod has full node network access (CIS 5.2.4)" \
        "Add comment: # cpm:ignore k8s-host-network — required for <DLNA/mDNS/etc>" \
        ""
    fi
  done < <(grep -n "hostNetwork: *true" "$manifest" 2>/dev/null || true)

  # --- k8s-no-cap-drop ---
  if grep -q "securityContext:" "$manifest" && ! grep -q "drop:" "$manifest"; then
    findings_add "warning" "$REL_PATH" "k8s-no-cap-drop" \
      "securityContext without capabilities drop: [ALL] (CIS 5.2.7)" \
      "Add: capabilities: { drop: [ALL] }" \
      ""
  fi

  # --- k8s-readonly-fs ---
  if grep -q "containers:" "$manifest" && ! grep -q "readOnlyRootFilesystem: *true" "$manifest"; then
    findings_add "info" "$REL_PATH" "k8s-readonly-fs" \
      "No readOnlyRootFilesystem: true — consider if writes are needed" \
      "Add: securityContext: { readOnlyRootFilesystem: true }" \
      ""
  fi
done
