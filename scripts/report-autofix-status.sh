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

# ===== REPORT =====
echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║          CPM AUTOFIX STATUS REPORT                          ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_RULES=$(wc -l < /tmp/all-rules.txt 2>/dev/null || echo "?")
echo "  Total rules: $TOTAL_RULES"
echo "  Safe autofix: ${#SAFE_FIXES[@]}"
echo "  Risky autofix: ${#RISKY_FIXES[@]}"
echo "  Manual only: ${#MANUAL_RULES[@]}"
IMPL_COUNT=$(ls "$SCRIPT_DIR/docs/fixes/"*.sh 2>/dev/null | wc -l)
echo "  Fix scripts implemented: $IMPL_COUNT"
echo ""

echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │ ✅ SAFE AUTOFIX (${#SAFE_FIXES[@]} rules — can apply without review)     │"
echo "  └─────────────────────────────────────────────────────────────┘"
for entry in "${SAFE_FIXES[@]}"; do
  RULE="${entry%%:*}"
  DESC="${entry#*:}"
  # Check if implemented
  if grep -rq "$RULE" "$SCRIPT_DIR/docs/fixes/"*.sh 2>/dev/null; then
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
  if grep -rq "$RULE" "$SCRIPT_DIR/docs/fixes/"*.sh 2>/dev/null; then
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
AUTOFIX_TOTAL=$((${#SAFE_FIXES[@]} + ${#RISKY_FIXES[@]}))
echo "  Summary: $AUTOFIX_TOTAL/${TOTAL_RULES} rules are auto-fixable ($((AUTOFIX_TOTAL * 100 / TOTAL_RULES))%)"
echo "  Implemented: $IMPL_COUNT fix scripts"
echo "  Gap: $((AUTOFIX_TOTAL - IMPL_COUNT)) auto-fixable rules without implementation"
echo ""
