#!/usr/bin/env bash
# check.sh — Standard wrapper for all shell checks.
#
# Source this as the FIRST line in any check script:
#   source "$(dirname "$0")/../../lib/shell/check.sh"
#
# Provides:
#   - set -o errexit/nounset/pipefail
#   - sources init.sh (ui, config, timer)
#   - findings_init with auto-detected check name
#   - trap findings_finish on EXIT
#   - CHECK_NAME variable
#
# @see ADR-129 (unified findings contract)
set -o errexit
set -o nounset
set -o pipefail

# Auto-detect check name from calling script's filename
CHECK_NAME="$(basename "${BASH_SOURCE[1]}" .sh)"

# Resolve lib/shell path relative to this file
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source framework
source "$_LIB_DIR/init.sh"
source "$_LIB_DIR/findings.sh"
source "$_LIB_DIR/search.sh"

# Initialize findings for this check
findings_init "$CHECK_NAME"

# Ensure findings_finish runs on exit, exit non-zero if errors found
_check_cleanup() {
  findings_finish
  ((_f_fail > 0)) && exit 1
  exit 0
}
trap '_check_cleanup' EXIT
