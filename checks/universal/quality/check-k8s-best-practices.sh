#!/usr/bin/env bash
# check-k8s-best-practices.sh — Detect K8s operational anti-patterns.
#
# Checks:
#   - k8s-latest-tag: Container image uses :latest or no tag
#   - k8s-no-tag: Image without any version tag
#   - k8s-no-resources: Missing resource requests/limits
#   - k8s-no-limits: Requests without limits
#   - k8s-no-liveness: Missing livenessProbe on Deployment/StatefulSet
#   - k8s-no-readiness: Missing readinessProbe
#   - k8s-cronjob-no-history-limit: CronJob without history cleanup
#   - k8s-cronjob-no-deadline: CronJob without activeDeadlineSeconds
#   - k8s-large-configmap: Inline ConfigMap data >80 lines
#
# Usage:
#   bash checks/universal/quality/check-k8s-best-practices.sh [repo-path]
#
# Config (cpm.toml):
#   [checks]
#   check-k8s-best-practices = true
#
# Suppress:
#   - File-level: add path to .k8s-bp-ignore (one glob per line)
#   - Inline: # cpm:ignore k8s-latest-tag
#
# Exit codes:
#   0 = clean (or warnings/info only)
#   1 = errors found (blocking)

set -o errexit
set -o nounset
set -o pipefail

# --- Source framework ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../../lib/shell/check.sh" ]; then
  source "$SCRIPT_DIR/../../../lib/shell/check.sh"
else
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
IGNORE_FILE="$REPO/.k8s-bp-ignore"

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

  KIND=$(grep "^kind:" "$manifest" 2>/dev/null | head -1 | awk '{print $2}')
  [ -z "$KIND" ] && continue

  # === :latest or untagged images ===
  while IFS=: read -r line_num line_content; do
    [ -z "$line_num" ] && continue
    img=$(echo "$line_content" | sed 's/.*image: *//' | tr -d '"' | tr -d "'")
    [ -z "$img" ] && continue

    if echo "$img" | grep -qE ":latest$"; then
      if ! is_suppressed "$manifest" "$line_num" "k8s-latest-tag"; then
        findings_add "error" "$REL_PATH:$line_num" "k8s-latest-tag" \
          "Image '$img' uses :latest — pin to specific version" \
          "Replace with pinned version tag (e.g., image:1.2.3)" \
          "https://kubernetes.io/docs/concepts/containers/images/#image-names"
      fi
    elif ! echo "$img" | grep -qE ":[a-zA-Z0-9]"; then
      if ! is_suppressed "$manifest" "$line_num" "k8s-no-tag"; then
        findings_add "error" "$REL_PATH:$line_num" "k8s-no-tag" \
          "Image '$img' has no tag — defaults to :latest" \
          "Add explicit version tag" \
          ""
      fi
    fi
  done < <(grep -n "image:" "$manifest" 2>/dev/null | grep -v "^#" || true)

  # === Missing resources (Deployments, StatefulSets, DaemonSets) ===
  if echo "$KIND" | grep -qE "Deployment|StatefulSet|DaemonSet"; then
    if ! grep -q "resources:" "$manifest"; then
      findings_add "warning" "$REL_PATH" "k8s-no-resources" \
        "No resource requests/limits — risk of resource starvation" \
        "Add: resources: { requests: {cpu: 100m, memory: 128Mi}, limits: {memory: 512Mi} }" \
        ""
    elif ! grep -q "limits:" "$manifest"; then
      findings_add "warning" "$REL_PATH" "k8s-no-limits" \
        "Resource requests without limits — unbounded consumption possible" \
        "Add: limits: { memory: <value> }" \
        ""
    fi
  fi

  # === Missing probes (Deployments/StatefulSets only) ===
  if echo "$KIND" | grep -qE "Deployment|StatefulSet"; then
    if ! grep -q "livenessProbe:" "$manifest"; then
      findings_add "warning" "$REL_PATH" "k8s-no-liveness" \
        "No livenessProbe — K8s cannot restart unhealthy pods" \
        "Add: livenessProbe: { httpGet: {path: /health, port: <port>} }" \
        ""
    fi
    if ! grep -q "readinessProbe:" "$manifest"; then
      findings_add "info" "$REL_PATH" "k8s-no-readiness" \
        "No readinessProbe — traffic may route to unready pods" \
        "Add: readinessProbe: { httpGet: {path: /ready, port: <port>} }" \
        ""
    fi
  fi

  # === CronJob without limits ===
  if [ "$KIND" = "CronJob" ]; then
    if ! grep -q "successfulJobsHistoryLimit:" "$manifest"; then
      findings_add "warning" "$REL_PATH" "k8s-cronjob-no-history-limit" \
        "CronJob without successfulJobsHistoryLimit — completed pods accumulate" \
        "Add: successfulJobsHistoryLimit: 3" \
        ""
    fi
    if ! grep -q "activeDeadlineSeconds:" "$manifest"; then
      findings_add "info" "$REL_PATH" "k8s-cronjob-no-deadline" \
        "CronJob without activeDeadlineSeconds — stuck jobs run forever" \
        "Add: activeDeadlineSeconds: 3600" \
        ""
    fi
  fi

  # === Large inline ConfigMap ===
  if [ "$KIND" = "ConfigMap" ]; then
    DATA_LINES=$(sed -n '/^data:/,/^---/p' "$manifest" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${DATA_LINES:-0}" -gt 80 ]; then
      findings_add "info" "$REL_PATH" "k8s-large-configmap" \
        "ConfigMap with $DATA_LINES lines inline — consider separate file" \
        "Extract to external file and reference via kustomize or helm" \
        ""
    fi
  fi
done
