#!/usr/bin/env bash
# checks/javascript/react19/check-react19.sh
# React 19 anti-patterns: forwardRef deprecated, use() API, Suspense, ErrorBoundary
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"react"' "$REPO/package.json" || exit 0

findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/app" ] && SRC="$SRC $REPO/app/"
[ -d "$REPO/components" ] && SRC="$SRC $REPO/components/"
[ -z "$SRC" ] && exit 0

# forwardRef usage (deprecated in React 19, ref is a prop now)
while IFS= read -r file; do
  if grep -qE "forwardRef\s*\(" "$file" 2>/dev/null; then
    findings_add "warning" "react19-forward-ref" "forwardRef() usage (deprecated in React 19)" \
      "In React 19, ref is a regular prop. Remove forwardRef wrapper" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#ref-as-a-prop"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

# useContext without use() (React 19 has use() for reading context)
while IFS= read -r file; do
  if grep -qE "useContext\s*\(" "$file" 2>/dev/null && ! grep -qE "use\s*\(" "$file" 2>/dev/null; then
    findings_add "warning" "react19-usecontext" "useContext() without use() pattern" \
      "In React 19, use use(context) instead of useContext(context)" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#use"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

# useEffect for data fetching (use Suspense + use())
while IFS= read -r file; do
  if grep -qE "useEffect.*fetch\(|useEffect.*axios" "$file" 2>/dev/null; then
    findings_add "warning" "react19-useeffect-fetch" "useEffect for data fetching" \
      "In React 19, use Suspense + use() for data fetching" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#data-fetching"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

# React.lazy without Suspense boundary
while IFS= read -r file; do
  if grep -qE "React\.lazy\s*\(" "$file" 2>/dev/null && ! grep -qE "Suspense" "$file" 2>/dev/null; then
    findings_add "warning" "react19-lazy-suspense" "React.lazy without Suspense boundary" \
      "Wrap lazy components with <Suspense fallback=...>" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#suspense"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

# Missing ErrorBoundary
if ! grep -qE "ErrorBoundary|error-boundary" "$SRC" 2>/dev/null; then
  findings_add "warning" "react19-no-error-boundary" "No ErrorBoundary component found" \
    "Add ErrorBoundary to catch rendering errors" \
    "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#error-boundaries"
fi


# defaultProps on function components (deprecated)
while IFS= read -r file; do
  if grep -qE "\.defaultProps\s*=" "$file" 2>/dev/null; then
    findings_add "warning" "react19-default-props" "defaultProps on function component" \
      "Use default parameter values instead" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#defaultprops"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

# PropTypes usage (use TypeScript)
while IFS= read -r file; do
  if grep -qE "import.*prop-types|require.*prop-types" "$file" 2>/dev/null; then
    findings_add "warning" "react19-proptypes" "PropTypes usage instead of TypeScript" \
      "Use TypeScript types instead of PropTypes" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#proptypes"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

# createContext without default value
while IFS= read -r file; do
  if grep -qE "createContext\s*\(\s*\)" "$file" 2>/dev/null; then
    findings_add "warning" "react19-context-default" "createContext() without default value" \
      "Provide a default value to avoid context mismatch warnings" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide#context"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

# setState in render (causes infinite loop)
while IFS= read -r file; do
  if grep -qE "set[A-Z][a-zA-Z]*\([^)]*\)\s*;" "$file" 2>/dev/null && ! grep -qE "useEffect|onClick|onChange|handle" "$file" 2>/dev/null; then
    findings_add "warning" "react19-setstate-render" "setState called directly in render body" \
      "This causes infinite re-render loops. Move to event handler or useEffect" \
      "https://react.dev/blog/2024/04/25/react-19-upgrade-guide"
  fi
done < <(find $SRC -name "*.jsx" -o -name "*.tsx" 2>/dev/null)

echo "  ✓ React 19 patterns checked"