#!/usr/bin/env bash
# checks/javascript/check-rxjs.sh
# RxJS best practices: unsubscribe, no nested subscribes, no deprecated operators
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-rxjs" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"rxjs"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/app" ] && SRC="$SRC $REPO/app/"
[ -z "$SRC" ] && exit 0

# --- subscribe() without unsubscribe/takeUntil/async pipe (memory leak) ---
SUBSCRIBE_FILES=$(cpm_grep -rl "\.subscribe(" $SRC 2>/dev/null | grep -v "\.test\.\|\.spec\." || true)
if [ -n "$SUBSCRIBE_FILES" ]; then
  UNSAFE=$(echo "$SUBSCRIBE_FILES" | xargs grep -l "\.subscribe(" 2>/dev/null | \
    xargs grep -L "unsubscribe\|takeUntil\|async pipe\|takeUntilDestroyed\|DestroyRef" 2>/dev/null | head -3 || true)
  [ -n "$UNSAFE" ] && finding "rxjs-no-unsubscribe" "subscribe() without unsubscribe/takeUntil/async pipe — memory leak"
fi

# --- Nested subscribes (should use switchMap/mergeMap) ---
NESTED=$(cpm_grep -rn "\.subscribe.*\{[^}]*\.subscribe" $SRC 2>/dev/null | head -3 || true)
if [ -n "$NESTED" ]; then
  finding "rxjs-nested-subscribes" "Nested subscribes — use switchMap/mergeMap instead for better composition"
fi

# --- Using deprecated operators (toPromise) ---
DEPRECATED=$(cpm_grep -rn "toPromise\|\.toPromise()" $SRC 2>/dev/null | head -3 || true)
if [ -n "$DEPRECATED" ]; then
  finding "rxjs-deprecated-operator" "toPromise is deprecated — use firstValueFrom/throwError from rxjs instead"
fi

# --- subscribe with error callback but no complete ---
SUB_COMPLETE=$(cpm_grep -rn "\.subscribe([^)]*\{[^}]*err" $SRC 2>/dev/null | \
  grep -v "complete:" | head -3 || true)
if [ -n "$SUB_COMPLETE" ]; then
  finding "rxjs-no-complete" "subscribe() with error callback but no complete — may leak resources"
fi

# --- Manual new Subject() without complete() in ngOnDestroy ---
SUBJECT_FILES=$(cpm_grep -rl "new Subject" $SRC 2>/dev/null | grep -v "\.test\.\|\.spec\." || true)
if [ -n "$SUBJECT_FILES" ]; then
  NO_COMPLETE=$(echo "$SUBJECT_FILES" | xargs grep -l "ngOnDestroy" 2>/dev/null | \
    xargs grep -L "\.complete()" 2>/dev/null | head -3 || true)
  [ -n "$NO_COMPLETE" ] && finding "rxjs-subject-complete" "Subject created without .complete() in ngOnDestroy — memory leak"
fi

# --- No takeUntilDestroyed or DestroyRef (Angular 16+ pattern) ---
TAKE_UNTIL=$(cpm_grep -rl "\.subscribe(" $SRC 2>/dev/null | grep -v "\.test\.\|\.spec\." || true)
if [ -n "$TAKE_UNTIL" ]; then
  NO_PATTERN=$(echo "$TAKE_UNTIL" | xargs grep -L "takeUntilDestroyed\|DestroyRef" 2>/dev/null | head -3 || true)
  [ -n "$NO_PATTERN" ] && finding "rxjs-no-take-until" "No takeUntilDestroyed/DestroyRef pattern — Angular 16+ should use these"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ RxJS patterns OK"
exit 0