#!/usr/bin/env bash
# checks/javascript/angular/check-angular.sh
# @see ADR-129
# Angular anti-patterns: memory leaks, performance, architecture, security
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

# ==================== SECURITY CHECKS ====================

# --- SECURITY: Missing XSRF/CSRF protection ---
if cpm_grep -rq "HttpClientModule" "$REPO/src" 2>/dev/null; then
  HAS_XSRF=$(cpm_grep -rq "HttpClientXsrfModule" "$REPO/src" 2>/dev/null || true)
  [ -z "$HAS_XSRF" ] && finding "ng-no-xsrf" "HttpClientModule without HttpClientXsrfModule — CSRF vulnerability"
fi

# --- SECURITY: Missing Content-Security-Policy ---
if [ -f "$REPO/src/index.html" ]; then
  HAS_CSP=$(grep -l "Content-Security-Policy\|http-equiv.*CSP" "$REPO/src/index.html" 2>/dev/null || true)
  [ -z "$HAS_CSP" ] && finding "ng-no-csp" "No Content-Security-Policy in index.html — XSS vulnerability"
fi

# --- SECURITY: Routes without auth guards ---
ROUTE_FILES=$(find "$REPO/src" -name "*.routes.ts" -o -name "*-routing.module.ts" 2>/dev/null || true)
if [ -n "$ROUTE_FILES" ]; then
  ROUTES_WITH_GUARD=$(echo "$ROUTE_FILES" | xargs grep -l "canActivate\|canMatch" 2>/dev/null | wc -l | tr -d ' ')
  TOTAL_ROUTES=$(echo "$ROUTE_FILES" | wc -l | tr -d ' ')
  [ "$ROUTES_WITH_GUARD" -eq 0 ] && [ "$TOTAL_ROUTES" -gt 0 ] && \
    finding "ng-no-auth-guard" "Routes without canActivate/canMatch guards — unauthorized access risk"
fi

# --- SECURITY: Inline javascript: URLs ---
cpm_grep -rn "href.*javascript:" "$REPO/src" 2>/dev/null | grep "\.html:" | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-js-url" "javascript: URL in template — XSS risk, use routerLink instead"

# --- SECURITY: Hardcoded API URLs ---
cpm_grep -rn "https*://[a-zA-Z0-9./-]+\.(com|org|net|io)/api" "$REPO/src" 2>/dev/null | \
  grep "\.ts:" | grep -v "environment\|httpInterceptor\|\.spec\." | head -1 | grep -q . && \
  finding "ng-hardcoded-api" "Hardcoded API URL in code — use environment files instead"

# --- SECURITY: Potential secrets in code ---
cpm_grep -rn "api[_-]?key\|apikey\|secret\|token\|password" "$REPO/src" 2>/dev/null | \
  grep -v "\.spec\.\|\.env\|environment\|interface\|type\s" | grep -E "['\"][a-zA-Z0-9_-]{20,}['\"]" | head -1 | grep -q . && \
  finding "ng-secret-in-code" "Potential secret/API key found in source — move to environment/backend"

# --- SECURITY: navigateByUrl with string concatenation ---
cpm_grep -rn "navigateByUrl.*\+.*id\|navigateByUrl.*\/.*\+" "$REPO/src" 2>/dev/null | \
  grep "\.ts:" | grep -v "\.spec\." | head -1 | grep -q . && \
  finding "ng-unsafe-nav" "navigateByUrl with string concatenation — path traversal risk, use router.navigate with array"

# --- SECURITY: Missing server-side validation comment ---
cpm_grep -rn "form\.valid\|this\.form\.valid" "$REPO/src" 2>/dev/null | grep "\.ts:" | head -1 | grep -q . && \
  finding "ng-no-server-validation" "Form validation without server-side validation comment — client validation can be bypassed"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Angular patterns OK"
exit 0