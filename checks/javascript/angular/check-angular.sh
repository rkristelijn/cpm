#!/usr/bin/env bash
# checks/javascript/angular/check-angular.sh
# Angular anti-patterns: memory leaks, performance, architecture
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "angular" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/angular.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC="$REPO/src/"
[ -d "$SRC" ] || exit 0

# --- .subscribe() without unsubscribe/takeUntil/async pipe (memory leak) ---
SUB_FILES=$(cpm_grep -rl "\.subscribe(" "$SRC" 2>/dev/null | grep "\.ts$" | grep -v "\.spec\." || true)
if [ -n "$SUB_FILES" ]; then
  LEAKS=$(echo "$SUB_FILES" | xargs grep -L "takeUntil\|takeUntilDestroyed\|unsubscribe\|async\|DestroyRef" 2>/dev/null | head -1 || true)
  [ -n "$LEAKS" ] && finding "ng-subscribe-leak" ".subscribe() without takeUntilDestroyed/unsubscribe — memory leak"
fi

# --- Nested subscriptions ---
cpm_grep -rn "\.subscribe(" "$SRC" 2>/dev/null | grep -v "\.spec\." | head -50 | \
  xargs -I{} grep -l "subscribe" 2>/dev/null | sort | uniq -d | head -1 | grep -q . 2>/dev/null
# Simpler: find files with 2+ subscribes (likely nested)
MULTI_SUB=$(echo "$SUB_FILES" | xargs grep -c "\.subscribe(" 2>/dev/null | awk -F: '$2 > 2' | head -1 || true)
[ -n "$MULTI_SUB" ] && finding "ng-nested-subscribe" "Multiple .subscribe() in one file — use switchMap/mergeMap operators"

# --- Functions in templates (performance) ---
cpm_grep -rn "{{ .*() }}\|\\[.*\\]=\".*()\"" "$SRC" 2>/dev/null | \
  grep "\.html:" | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-func-in-template" "Function call in template — runs every change detection. Use pipe or computed()"

# --- No trackBy in *ngFor ---
cpm_grep -rn "\*ngFor" "$SRC" 2>/dev/null | grep -v "trackBy\|track " | head -1 | grep -q . && \
  finding "ng-ngfor-no-trackby" "*ngFor without trackBy — entire list re-renders on change"

# --- Direct DOM manipulation ---
cpm_grep -rn "document\.getElementById\|document\.querySelector\|\.innerHTML\s*=" "$SRC" 2>/dev/null | \
  grep "\.ts:" | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-direct-dom" "Direct DOM manipulation — breaks SSR. Use Renderer2 or ElementRef"

# --- Default change detection (no OnPush) ---
COMPONENTS=$(cpm_grep -rl "@Component" "$SRC" 2>/dev/null | grep -v "\.spec\." || true)
if [ -n "$COMPONENTS" ]; then
  NO_ONPUSH=$(echo "$COMPONENTS" | xargs grep -L "OnPush\|ChangeDetectionStrategy\|signals\|signal(" 2>/dev/null | wc -l | tr -d ' ')
  TOTAL=$(echo "$COMPONENTS" | wc -l | tr -d ' ')
  [ "$NO_ONPUSH" -gt 5 ] && [ "$TOTAL" -gt 5 ] && \
    finding "ng-no-onpush" "$NO_ONPUSH/$TOTAL components without OnPush — heavy change detection"
fi

# --- Angular security: bypassSecurityTrust* (XSS risk) ---
cpm_grep -rn "bypassSecurityTrust" "$SRC" 2>/dev/null | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-bypass-security" "bypassSecurityTrust* used — XSS risk, review if truly necessary"

# --- innerHTML usage (XSS vector, use Angular templates) ---
cpm_grep -rn "innerHTML\|outerHTML" "$SRC" 2>/dev/null | grep "\.ts:\|\.html:" | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-innerhtml" "innerHTML/outerHTML used — XSS risk, use Angular template binding instead"

# --- ViewEncapsulation.None (styles leak globally) ---
cpm_grep -rn "ViewEncapsulation.None" "$SRC" 2>/dev/null | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-encapsulation-none" "ViewEncapsulation.None — styles leak globally, breaks component isolation"

# --- setTimeout in components (use Angular lifecycle/RxJS instead) ---
TIMEOUT_FILES=$(cpm_grep -rl "setTimeout\|setInterval" "$SRC" 2>/dev/null | grep "\.ts$" | grep -v "\.spec\.\|\.test\." || true)
if [ -n "$TIMEOUT_FILES" ]; then
  COUNT=$(echo "$TIMEOUT_FILES" | wc -l | tr -d ' ')
  [ "$COUNT" -gt 3 ] && finding "ng-settimeout-abuse" "setTimeout/setInterval in $COUNT files — use RxJS timer/interval or Angular lifecycle"
fi

# --- HttpClient with <any> (loses type safety) ---
cpm_grep -rn "HttpClient\|this\.http" "$SRC" 2>/dev/null | grep "<any>" | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-http-any" "HttpClient with <any> — define response interfaces for type safety"

# --- Browser APIs without platform check (breaks SSR) ---
if [ -f "$REPO/server.ts" ] || grep -q '"@angular/ssr"\|"@nguniversal"' "$REPO/package.json" 2>/dev/null; then
  BROWSER_API=$(cpm_grep -rl "localStorage\|sessionStorage\|window\.\|document\." "$SRC" 2>/dev/null | \
    grep "\.ts$" | grep -v "\.spec\.\|\.test\." || true)
  if [ -n "$BROWSER_API" ]; then
    NO_PLATFORM_CHECK=$(echo "$BROWSER_API" | xargs grep -L "isPlatformBrowser\|PLATFORM_ID" 2>/dev/null | head -1 || true)
    [ -n "$NO_PLATFORM_CHECK" ] && finding "ng-ssr-browser-api" "Browser API without isPlatformBrowser check — breaks SSR"
  fi
fi

# --- Eager routes (no lazy loading) ---
ROUTE_FILES=$(find "$SRC" -name "*.routes.ts" -o -name "*-routing.module.ts" 2>/dev/null || true)
if [ -n "$ROUTE_FILES" ]; then
  EAGER=$(echo "$ROUTE_FILES" | xargs grep -n "component:" 2>/dev/null | grep -v "loadComponent\|loadChildren" | head -1 || true)
  [ -n "$EAGER" ] && finding "ng-no-lazy-loading" "Eager component in routes — use loadComponent/loadChildren for lazy loading"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Angular patterns OK"
exit 0
