#!/usr/bin/env bash
# checks/javascript/check-react.sh
# Common React mistakes: falsy rendering, state mutation, key anti-patterns, async effects
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-react" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"react"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Find source dirs
SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/app" ] && SRC="$SRC $REPO/app/"
[ -z "$SRC" ] && exit 0

# --- Falsy zero rendering: .length && <Component> (renders 0 in UI) ---
if cpm_grep -rn "\.length &&" $SRC 2>/dev/null | grep -v "\.length > 0\|\.length !== 0\|\.length !==" | head -1 | grep -q .; then
  finding "react-falsy-zero" ".length && <Comp> renders 0 in UI — use .length > 0 &&"
fi

# --- Array index as key ---
if cpm_grep -rn "key={i}\|key={index}\|key={idx}" $SRC 2>/dev/null | head -1 | grep -q .; then
  finding "react-index-as-key" "Array index used as key — causes bugs on reorder/delete. Use stable IDs"
fi

# --- useEffect(async ...) — returns promise instead of cleanup ---
if cpm_grep -rn "useEffect(async\|useEffect(() => async" $SRC 2>/dev/null | head -1 | grep -q .; then
  finding "react-async-effect" "async function passed to useEffect — define async fn inside the effect"
fi

# --- State mutation: .push() followed by setState ---
if cpm_grep -rn "\.push(" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  # Only flag if there's also a set* call nearby (likely state mutation)
  PUSH_FILES=$(cpm_grep -rl "\.push(" $SRC 2>/dev/null | grep -v "\.test\.\|\.spec\." || true)
  if [ -n "$PUSH_FILES" ]; then
    MUTATES=$(echo "$PUSH_FILES" | xargs grep -l "set[A-Z]" 2>/dev/null | head -1 || true)
    [ -n "$MUTATES" ] && finding "react-state-mutation" ".push() with setState — mutates state. Use spread: [...arr, item]"
  fi
fi

# --- useState() without initial value (uncontrolled→controlled flip) ---
if cpm_grep -rn "useState()" $SRC 2>/dev/null | head -1 | grep -q .; then
  finding "react-no-initial-state" "useState() without initial value — causes uncontrolled→controlled warning"
fi

# --- useEffect without dependency array (infinite loop risk) ---
if cpm_grep -rn "useEffect(() =>" $SRC 2>/dev/null | grep -v "\], \[\|], \[" | grep -v "// eslint-disable" | head -1 | grep -q .; then
  # Check if there's a useEffect that doesn't close with ], [deps])
  EFFECT_FILES=$(cpm_grep -rl "useEffect(" $SRC 2>/dev/null || true)
  if [ -n "$EFFECT_FILES" ]; then
    # Find useEffect calls without a closing dependency array on same or next lines
    NO_DEPS=$(echo "$EFFECT_FILES" | xargs grep -l "useEffect(() =>" 2>/dev/null | \
      xargs grep -c "\], \[\|, \[\])" 2>/dev/null | grep ":0$" | head -1 || true)
    [ -n "$NO_DEPS" ] && finding "react-effect-no-deps" "useEffect without dependency array — may cause infinite re-renders"
  fi
fi

# --- useEffect with addEventListener but no cleanup ---
LISTENER_FILES=$(cpm_grep -rl "addEventListener" $SRC 2>/dev/null | grep -v "\.test\.\|\.spec\." || true)
if [ -n "$LISTENER_FILES" ]; then
  NO_CLEANUP=$(echo "$LISTENER_FILES" | xargs grep -l "useEffect" 2>/dev/null | \
    xargs grep -L "removeEventListener" 2>/dev/null | head -1 || true)
  [ -n "$NO_CLEANUP" ] && finding "react-no-cleanup" "addEventListener in useEffect without removeEventListener — memory leak"
fi

# --- Direct DOM manipulation in components ---
if cpm_grep -rn "document\.querySelector\|document\.getElementById\|document\.getElementsBy" $SRC 2>/dev/null | \
  grep -v "\.test\.\|\.spec\.\|// cpm:ignore" | head -1 | grep -q .; then
  finding "react-direct-dom" "Direct DOM manipulation — use refs (useRef) instead"
fi

# --- Inline arrow function in JSX (creates new function every render) ---
if cpm_grep -rn "onClick={() =>\|onChange={() =>\|onSubmit={() =>" $SRC 2>/dev/null | \
  grep -v "useCallback\|// cpm:ignore" | head -1 | grep -q .; then
  finding "react-inline-fn" "Inline arrow function in JSX — creates new fn every render. Wrap in useCallback"
fi

# --- Missing useCallback for handlers passed to children ---
HANDLER_FILES=$(cpm_grep -rl "onClick\|onChange\|onSubmit" $SRC 2>/dev/null | grep -v "\.test\.\|\.spec\." || true)
if [ -n "$HANDLER_FILES" ]; then
  UNWRAPPED=$(echo "$HANDLER_FILES" | xargs grep -l "const.*=.*(" 2>/dev/null | \
    xargs grep -L "useCallback" 2>/dev/null | head -1 || true)
  [ -n "$UNWRAPPED" ] && finding "react-missing-callback" "Handler defined without useCallback — child re-renders unnecessarily"
fi

# --- Missing useMemo for expensive operations ---
EXPENSIVE=$(cpm_grep -rn "\.reduce\|\.sort\|\.filter.*\.map" $SRC 2>/dev/null | \
  grep -v "useMemo\|useCallback\|node_modules\|\.test\.\|\.spec\." | head -3 || true)
if [ -n "$EXPENSIVE" ]; then
  finding "react-missing-memo" "Expensive operation without useMemo — recalculates every render"
fi

# --- setState directly in render body (infinite loop risk) ---
if cpm_grep -rn "set[A-Z][a-zA-Z]*\(" $SRC 2>/dev/null | \
  grep -v "onClick\|onChange\|onSubmit\|useEffect\|useCallback\|handle\|// cpm:ignore" | head -1 | grep -q .; then
  finding "react-setstate-render" "setState called directly in render body — causes infinite re-render loop"
fi

# --- dangerouslySetInnerHTML without sanitization ---
if cpm_grep -rn "dangerouslySetInnerHTML" $SRC 2>/dev/null | \
  grep -v "DOMPurify\|sanitize\|isTrusted\|// cpm:ignore" | head -1 | grep -q .; then
  finding "react-dangerous-html" "dangerouslySetInnerHTML without sanitization — XSS vulnerability"
fi

# --- useEffect with empty deps that reference props/state (stale closure) ---
STALE=$(cpm_grep -rn "useEffect(() => \{[^}]*(props\.|state\.|use)" $SRC 2>/dev/null | \
  grep "\], \[\])" | head -3 || true)
if [ -n "$STALE" ]; then
  finding "react-stale-closure" "useEffect with empty deps references props/state — stale closure bug"
fi

# --- Array mutation (.push/.splice/.sort/.reverse) on potential state ---
MUTATE_FILES=$(cpm_grep -rl "\.push\|\.splice\|\.sort\|\.reverse" $SRC 2>/dev/null | \
  grep -v "node_modules\|\.test\.\|\.spec\." || true)
if [ -n "$MUTATE_FILES" ]; then
  MUTATING=$(echo "$MUTATE_FILES" | xargs grep -l "useState\|useReducer" 2>/dev/null | head -1 || true)
  [ -n "$MUTATING" ] && finding "react-array-mutation" "Array mutation on state — use spread [...arr, item] instead"
fi

# --- Object property mutation on potential state ---
if cpm_grep -rn "\.name = \|\.id = \|\.value = \|\.status = " $SRC 2>/dev/null | \
  grep -v "const \|let \|this\.\|// cpm:ignore" | head -1 | grep -q .; then
  finding "react-object-mutation" "Object property mutation — use spread {...obj, key: value}"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ React patterns OK"
exit 0
