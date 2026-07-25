#!/usr/bin/env bash
# scripts/report-autofix-status.sh
# Reports which checks have autofix capability and which don't.
# Usage: bash scripts/report-autofix-status.sh
set -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Classification: which rules CAN be autofixed safely
# Categories: SAFE (no risk), RISKY (needs review), MANUAL (human decision needed)
declare -A AUTOFIX_STATUS

# ===== SAFE AUTOFIXES (can be applied without review) =====
SAFE_FIXES=(
  # package.json metadata
  "no-description:Add placeholder description from folder name"
  "no-repository:Set from git remote URL"
  "no-engines:Set from current node -v"
  "no-license:Set MIT (most common)"
  "no-author:Set from git config user.name/email"
  "no-homepage:Set from repository URL"
  "no-bugs-url:Set from repository URL + /issues"
  "no-private:Add private:true for apps"
  "no-license-file:Create MIT LICENSE file"
  # package.json scripts
  "no-clean-script:Add 'rm -rf .next dist build'"
  "no-typecheck-script:Add 'tsc --noEmit'"
  "no-check-script:Add 'npm run lint && npm run test && npm run build'"
  "no-start-script:Add 'next start' or 'node dist/index.js'"
  # Node version
  "no-node-version-file:Create .nvmrc from current node -v"
  # MUI
  "mui-literal-color:Replace known hex codes with theme tokens"
  # TanStack
  "tanstack-no-staletime:Add defaultOptions.queries.staleTime to QueryClient"
  # Next.js boundaries
  "nextjs-no-loading:Create loading.tsx with CircularProgress"
  "nextjs-no-error-boundary:Create error.tsx with reset button"
  "nextjs-no-not-found:Create not-found.tsx"
  # Config
  "no-gitignore:Create .gitignore with common patterns"
  "gitignore-no-node-modules:Append node_modules to .gitignore"
  "lockfile-gitignored:Remove lockfile from .gitignore"
  # TSConfig
  "tsconfig-no-strict:Set strict:true"
  "tsconfig-no-skiplib:Set skipLibCheck:true"
  "tsconfig-no-isolated:Set isolatedModules:true"
  "tsconfig-no-json-resolve:Set resolveJsonModule:true"
  "tsconfig-no-unchecked-index:Set noUncheckedIndexedAccess:true"
  "tsconfig-no-case-check:Set forceConsistentCasingInFileNames:true"
  "tsconfig-no-esmoduleinterop:Set esModuleInterop:true"
  # React/Code
  "react19-no-forwardref:Remove forwardRef wrapper, pass ref as prop"
  "react-fc-deprecated:Replace React.FC<Props> with (props: Props)"
  # Dependencies
  "types-in-prod:Move @types/* to devDependencies"
  "dev-in-prod:Move dev packages to devDependencies"
  "duplicate-in-both:Remove from devDependencies (keep in dependencies)"
  # Formatting
  "no-formatter:Create .prettierrc with defaults"
)

# ===== RISKY AUTOFIXES (applied but flagged for review) =====
RISKY_FIXES=(
  "unpinned-deps:Remove ^ and ~ prefixes from versions"
  "tanstack-cachetime-removed:Rename cacheTime to gcTime"
  "tanstack-keepprevious-removed:Replace keepPreviousData with placeholderData"
  "mui-makestyles-removed:Convert to styled() — may need manual adjustment"
  "mui-old-components-prop:Rename componentsProps→slotProps, components→slots"
  "mui-grid2-deprecated:Rename Grid2 import to Grid"
  "nextjs16-middleware-renamed:Rename middleware.ts to proxy.ts"
  "eslint-dual-config:Remove .eslintrc (keep flat config)"
  "eslint-ignore-with-flat:Move patterns from .eslintignore to config"
  "stale-override:Remove override that matches dependency version"
  "has-overrides:Flag for review (may still be needed)"
)

# ===== MANUAL ONLY (require human decision) =====
MANUAL_RULES=(
  "file-too-large:Split component — AI can suggest but human must decide how"
  "too-many-usestate:Extract to useReducer/custom hook — architecture decision"
  "tanstack-query-in-component:Extract to custom hook — naming/structure decision"
  "react-prop-drilling:Use Context/composition — architecture decision"
  "api-no-validation:Add zod schema — schema design is domain-specific"
  "api-no-rate-limit:Choose rate limit strategy and thresholds"
  "api-get-mutates:Restructure to proper HTTP method"
  "nextjs-large-client:Split component — architecture decision"
  "nextjs-no-metadata:Write meaningful SEO metadata"
  "low-test-coverage:Write tests — requires domain knowledge"
  "tanstack-no-manual-pagination:Requires backend API changes"
  "tanstack-table-no-url:Architecture: URL state management"
  "no-commit-hooks:Team decision: husky vs lefthook vs CI-only"
  "no-commit-convention:Team decision: commitizen vs commitlint"
  "magic-number:Name the constant — requires domain context"
  "handler-naming:Rename — requires understanding intent"
  "nextjs-no-csp:Write CSP policy — security expertise needed"
  "react19-server-action-no-validation:Add validation — domain-specific schema"
  "cors-wildcard:Determine allowed origins"
  "secret-in-public-env:Move to server-side env — may need architecture change"
)

# ===== AI-FIXABLE (needs context understanding, AI can do with prompt) =====
AI_FIXES=(
  "file-too-large:Split into logical sub-components based on responsibilities"
  "too-many-usestate:Extract related state into custom hook or useReducer"
  "tanstack-query-in-component:Extract useQuery into custom hook with proper naming"
  "react-prop-drilling:Introduce Context or compose with children pattern"
  "api-no-validation:Generate zod schema from TypeScript interface"
  "api-no-error-response:Add try/catch with appropriate 4xx/5xx responses"
  "api-leaks-error:Replace error.message with generic message, log server-side"
  "nextjs-large-client:Split into Server Component wrapper + small Client island"
  "nextjs-no-metadata:Generate SEO metadata from page content/purpose"
  "low-test-coverage:Generate unit tests for untested components"
  "tanstack-no-manual-pagination:Add manualPagination + server-side params"
  "tanstack-table-no-url:Sync table state with useSearchParams"
  "tanstack-no-optimistic:Add onMutate with optimistic cache update"
  "tanstack-no-error-handling:Add error state rendering with retry button"
  "magic-number:Extract to named constant with descriptive name"
  "handler-naming:Rename to handle* convention based on action"
  "react-effect-sets-state:Convert to render-time derivation or useMemo"
  "react-prop-to-state:Remove useState, use prop directly or derive"
  "react-effect-for-event:Move logic from useEffect into event handler"
  "nextjs-self-fetch:Replace fetch('/api/x') with direct function call"
  "async-no-catch:Add try/catch with user-facing error handling"
  "effect-fetch:Replace useEffect+fetch with useQuery or Server Component"
  "manual-loading-state:Replace useState loading with Suspense or isPending"
  "no-loading-indicator:Add Skeleton or CircularProgress during async ops"
  "date-hydration:Wrap in useEffect or add suppressHydrationWarning"
  "mui-raw-html-text:Replace HTML tags with MUI Typography components"
  "mui-raw-button:Replace <button> with MUI Button"
  "mui-raw-input:Replace <input> with MUI TextField"
  "mui-box-overuse:Refactor layout Boxes into Stack/Grid where appropriate"
  "mui-inline-style:Convert style={{}} to sx prop with theme tokens"
  "spread-props-dom:Destructure needed props explicitly"
  "nested-ternary:Extract to variable or early return"
  "react19-server-action-no-validation:Add zod.parse() at top of server action"
  "nextjs-raw-img:Replace <img> with next/image, add width/height"
  "sql-interpolation:Convert template literal to parameterized query"
)

# ===== REPORT =====
echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║          CPM AUTOFIX STATUS REPORT                          ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_RULES=$(wc -l </tmp/all-rules.txt 2>/dev/null || echo "?")
echo "  Total rules: $TOTAL_RULES"
echo "  Safe autofix: ${#SAFE_FIXES[@]} (script can fix, zero risk)"
echo "  Risky autofix: ${#RISKY_FIXES[@]} (script can fix, may break)"
echo "  AI-fixable: ${#AI_FIXES[@]} (AI can fix with prompt, needs context)"
echo "  Manual only: ${#MANUAL_RULES[@]} (human architecture decision)"
IMPL_COUNT=$(ls "$SCRIPT_DIR/scripts/fixes/"*.sh 2>/dev/null | wc -l)
echo "  Fix scripts implemented: $IMPL_COUNT"
echo ""

echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │ ✅ SAFE AUTOFIX (${#SAFE_FIXES[@]} rules — can apply without review)     │"
echo "  └─────────────────────────────────────────────────────────────┘"
for entry in "${SAFE_FIXES[@]}"; do
  RULE="${entry%%:*}"
  DESC="${entry#*:}"
  # Check if implemented
  if grep -rq "$RULE" "$SCRIPT_DIR/scripts/fixes/"*.sh 2>/dev/null; then
    printf "  \033[32m  ✓ impl\033[0m  %-35s %s\n" "$RULE" "$DESC"
  else
    printf "  \033[33m  ○ todo\033[0m  %-35s %s\n" "$RULE" "$DESC"
  fi
done

echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │ ⚠️  RISKY AUTOFIX (${#RISKY_FIXES[@]} rules — apply but flag for review) │"
echo "  └─────────────────────────────────────────────────────────────┘"
for entry in "${RISKY_FIXES[@]}"; do
  RULE="${entry%%:*}"
  DESC="${entry#*:}"
  if grep -rq "$RULE" "$SCRIPT_DIR/scripts/fixes/"*.sh 2>/dev/null; then
    printf "  \033[32m  ✓ impl\033[0m  %-35s %s\n" "$RULE" "$DESC"
  else
    printf "  \033[33m  ○ todo\033[0m  %-35s %s\n" "$RULE" "$DESC"
  fi
done

echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │ 🔧 MANUAL ONLY (${#MANUAL_RULES[@]} rules — require human decision)       │"
echo "  └─────────────────────────────────────────────────────────────┘"
for entry in "${MANUAL_RULES[@]}"; do
  RULE="${entry%%:*}"
  DESC="${entry#*:}"
  printf "  \033[90m  · manual\033[0m %-35s %s\n" "$RULE" "$DESC"
done

echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │ 🤖 AI-FIXABLE (${#AI_FIXES[@]} rules — AI can fix with context prompt)  │"
echo "  └─────────────────────────────────────────────────────────────┘"
for entry in "${AI_FIXES[@]}"; do
  RULE="${entry%%:*}"
  DESC="${entry#*:}"
  printf "  \033[36m  ◆ ai\033[0m    %-35s %s\n" "$RULE" "$DESC"
done

echo ""
AUTOFIX_TOTAL=$((${#SAFE_FIXES[@]} + ${#RISKY_FIXES[@]}))
AI_TOTAL=${#AI_FIXES[@]}
ALL_FIXABLE=$((AUTOFIX_TOTAL + AI_TOTAL))
echo "  Summary:"
echo "    Script-fixable: $AUTOFIX_TOTAL/${TOTAL_RULES} rules ($((AUTOFIX_TOTAL * 100 / TOTAL_RULES))%)"
echo "    AI-fixable:     $AI_TOTAL/${TOTAL_RULES} rules ($((AI_TOTAL * 100 / TOTAL_RULES))%)"
echo "    Total fixable:  $ALL_FIXABLE/${TOTAL_RULES} rules ($((ALL_FIXABLE * 100 / TOTAL_RULES))%)"
echo "    Manual only:    ${#MANUAL_RULES[@]} rules (architecture decisions)"
echo "    Implemented:    $IMPL_COUNT fix scripts"
echo ""
