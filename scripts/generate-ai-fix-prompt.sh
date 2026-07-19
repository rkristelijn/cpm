#!/usr/bin/env bash
# scripts/generate-ai-fix-prompt.sh — Generate AI prompts for findings that need context
# Usage: bash scripts/generate-ai-fix-prompt.sh [path] [rule]
# Without rule: generates prompts for ALL AI-fixable findings found
# With rule: generates prompt for specific rule only
set -o nounset -o pipefail

REPO="${1:-.}"
RULE="${2:-}"

# AI fix strategies per rule (rule → prompt template)
generate_prompt() {
  local RULE="$1" FILE="$2" LINE="${3:-}" CONTEXT="${4:-}"

  case "$RULE" in
    file-too-large)
      echo "Split $FILE into smaller components. The file is too large (>200 lines)."
      echo "Analyze the component and extract logical sub-components:"
      echo "- Each component should have a single responsibility"
      echo "- Extract hooks into separate files"
      echo "- Keep the main file as an orchestrator that composes the sub-components"
      echo "- Maintain the same public API (same props, same behavior)"
      ;;
    too-many-usestate)
      echo "Refactor $FILE — it has too many useState calls (>5)."
      echo "Options (pick the best fit):"
      echo "1. Group related state into useReducer with typed actions"
      echo "2. Extract related state+logic into a custom hook (useXxxState)"
      echo "3. Derive computed values instead of storing them"
      echo "Do NOT change the component's external behavior."
      ;;
    tanstack-query-in-component)
      echo "Extract the useQuery/useMutation call from $FILE into a custom hook."
      echo "Convention: src/hooks/useXxx.ts"
      echo "- Name: use[Entity][Action] (e.g., useFolders, useDashboardMetrics)"
      echo "- Return: { data, isLoading, error, refetch } or typed subset"
      echo "- Keep queryKey and queryFn together in the hook"
      echo "- Add proper TypeScript return type"
      ;;
    api-no-validation)
      echo "Add input validation to the route handler in $FILE using zod."
      echo "Steps:"
      echo "1. Define a zod schema for the request body/params"
      echo "2. Parse with schema.safeParse() at the top of the handler"
      echo "3. Return 400 with validation errors if parsing fails"
      echo "4. Use the typed result for the rest of the handler"
      echo "Example: const schema = z.object({ id: z.string().uuid() })"
      ;;
    nextjs-large-client)
      echo "Split $FILE (>150 lines Client Component) into:"
      echo "1. A Server Component wrapper (no 'use client') that fetches data"
      echo "2. Small Client Component islands for interactive parts only"
      echo "3. Move non-interactive rendering to the Server Component"
      echo "Goal: minimize the 'use client' boundary to only what needs interactivity."
      ;;
    react-effect-sets-state)
      echo "In $FILE, there's a useEffect that sets state (derived state anti-pattern)."
      echo "Fix: compute the value during render instead of in an effect."
      echo "- If derived from props/state: const derived = computeFrom(props.x, state.y)"
      echo "- If expensive: const derived = useMemo(() => compute(x, y), [x, y])"
      echo "- If from external subscription: use useSyncExternalStore"
      echo "Do NOT use useEffect to set state that can be calculated."
      ;;
    nextjs-self-fetch)
      echo "In $FILE, a Server Component fetches its own /api route."
      echo "This is an anti-pattern — the server makes an HTTP request to itself."
      echo "Fix: import and call the logic function directly:"
      echo "- Extract the route handler logic into a shared service (src/lib/)"
      echo "- Import that service in both the route handler AND the Server Component"
      echo "- Remove the fetch('/api/...') call"
      ;;
    mui-box-overuse)
      echo "Refactor $FILE — too many <Box> components used for layout."
      echo "Replace with semantic MUI layout components:"
      echo "- Vertical stacking: <Box> → <Stack spacing={2}>"
      echo "- Grid layouts: nested <Box> → <Grid container><Grid size={6}>..."
      echo "- Horizontal flex: <Box sx={{display:'flex'}}> → <Stack direction='row'>"
      echo "- Single wrapper with sx: keep as <Box sx={...}>"
      echo "Only replace Boxes that are used purely for spacing/layout."
      ;;
    low-test-coverage)
      echo "Generate unit tests for $FILE."
      echo "Requirements:"
      echo "- Use vitest + @testing-library/react"
      echo "- Test the happy path (renders correctly with valid props)"
      echo "- Test edge cases (empty data, loading state, error state)"
      echo "- Test user interactions (clicks, form submissions)"
      echo "- Mock external dependencies (fetch, useQuery, router)"
      echo "- File: create alongside as $FILE with .test before extension"
      ;;
    tanstack-no-optimistic)
      echo "Add optimistic updates to the useMutation in $FILE."
      echo "Pattern:"
      echo "  onMutate: async (newData) => {"
      echo "    await queryClient.cancelQueries({ queryKey: ['key'] })"
      echo "    const previous = queryClient.getQueryData(['key'])"
      echo "    queryClient.setQueryData(['key'], (old) => optimisticUpdate(old, newData))"
      echo "    return { previous }"
      echo "  },"
      echo "  onError: (err, vars, context) => {"
      echo "    queryClient.setQueryData(['key'], context.previous)"
      echo "  },"
      echo "  onSettled: () => queryClient.invalidateQueries({ queryKey: ['key'] })"
      ;;
    magic-number)
      echo "Extract magic numbers in $FILE to named constants."
      echo "- Place at top of file or in a constants file"
      echo "- Name should describe WHAT the number means, not its value"
      echo "- Example: const MAX_RETRIES = 3; const PAGINATION_SIZE = 20;"
      ;;
    *)
      echo "Fix the '$RULE' issue in $FILE."
      echo "Refer to the check description for guidance."
      ;;
  esac
}

# Run checks and collect findings
echo ""
echo "  🤖 AI Fix Prompts"
echo "  ═══════════════════"
echo ""

FOUND=0

# Run the checks that have AI-fixable rules
for CHECK in \
  "checks/javascript/check-code-hygiene.sh" \
  "checks/javascript/check-framework-misuse.sh" \
  "checks/javascript/check-tanstack.sh" \
  "checks/javascript/check-mui.sh" \
  "checks/javascript/check-api-patterns.sh"; do

  SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/$CHECK"
  [ -f "$SCRIPT_PATH" ] || continue

  OUTPUT=$(bash "$SCRIPT_PATH" "$REPO" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true)
  while IFS= read -r line; do
    # Extract rule name: it's the first word after "warning" or "error"
    FOUND_RULE=$(echo "$line" | sed 's/^.*\(warning\|error\|blocking\)\s*//' | awk '{print $1}' || true)
    [ -z "$FOUND_RULE" ] && continue

    # Filter by specific rule if given
    [ -n "$RULE" ] && [ "$FOUND_RULE" != "$RULE" ] && continue

    # Only generate for AI-fixable rules
    case "$FOUND_RULE" in
      file-too-large|too-many-usestate|tanstack-query-in-component|api-no-validation|\
      nextjs-large-client|react-effect-sets-state|nextjs-self-fetch|mui-box-overuse|\
      low-test-coverage|tanstack-no-optimistic|magic-number|react-prop-drilling|\
      api-no-error-response|handler-naming|async-no-catch|nested-ternary|\
      tanstack-no-error-handling|mui-raw-html-text|effect-fetch|manual-loading-state)
        FOUND=$((FOUND+1))
        echo "  ┌── Finding #$FOUND: $FOUND_RULE"
        echo "  │"
        generate_prompt "$FOUND_RULE" "$REPO" "" "" | sed 's/^/  │  /'
        echo "  │"
        echo "  └──────────────────────────────────────"
        echo ""
        ;;
    esac
  done <<< "$OUTPUT"
done

if [ "$FOUND" -eq 0 ]; then
  echo "  No AI-fixable findings detected. Code is clean! 🎉"
fi
echo ""
echo "  $FOUND AI-fixable findings. Copy a prompt above and paste to your AI assistant."
echo ""
