# React — Read The Framework Manual (RTFM) Patterns

Source: Epic React Training (epicreact.dev)
Version: React 18+ (hooks patterns stable through 18.x)
Last reviewed: 2026-05

## Checkable Rules

### 1. Missing key prop in lists

**What**: Every array.map() must have a stable `key` prop using a unique ID, not array index.
**Why**: React uses keys to track element identity. Index as key causes focus bugs, state corruption, and animation issues on reorder/delete.
**Check**: `<li>{items.map(item => <span>...</span>)}` without `key={item.id}`.

```bash
# Anti-pattern: no key
grep -rn "\.map(" src/ | grep -v "key=" | grep -v "\.test\|\.spec"
```

### 2. Inline function creation in render

**What**: Avoid `onClick={() => handleClick(id)}` in JSX — creates new function on every render.
**Why**: Causes unnecessary re-renders of child components that receive callbacks.
**Check**: Arrow functions directly in JSX props.

```bash
# Anti-pattern
grep -rn "onClick={() =>" src/ --include="*.jsx" --include="*.tsx"
```

### 3. Missing useCallback for event handlers

**What**: Callbacks passed to child components or dependencies of other hooks must use `useCallback`.
**Why**: Prevents new function creation, stabilizes reference equality.
**Check**: Event handlers defined inside component without useCallback.

```bash
# Check for handlers passed to memoized children or used in useEffect
grep -rn "const.*=.*(" src/ | grep -v "useCallback\|useMemo\|const {" | head -20
```

### 4. Missing useMemo for expensive computations

**What**: Expensive calculations (reduce, sort, filter on large arrays) must use `useMemo`.
**Why**: Prevents recalculation on every render.
**Check**: .reduce(), .sort(), .filter() on arrays > 100 items without useMemo.

```bash
# Anti-pattern: expensive op without memo
grep -rn "\.reduce\|\.sort\|\.filter.*\.map" src/ | grep -v "useMemo\|useCallback"
```

### 5. useEffect missing cleanup function

**What**: Subscriptions, timers, and event listeners must return a cleanup function.
**Why**: Prevents memory leaks, duplicate subscriptions, and stale state.
**Check**: useEffect without return statement when it should clean up.

```bash
# Check useEffect that sets up listeners/timers without cleanup
grep -rn "addEventListener\|setInterval\|setTimeout" src/ | grep "useEffect" | grep -v "return\|cleanup"
```

### 6. Stale closures in useEffect/useCallback

**What**: Always include all dependencies in hook dependency arrays.
**Why**: Missing deps cause stale closures — effect uses old state values.
**Check**: useEffect/useCallback with empty [] deps that reference props/state.

```bash
# Anti-pattern: effect with deps but missing ones
grep -rn "useEffect(() => \{[^}]*props\." src/ | grep "\], \[\])"
```

### 7. setState in render body

**What**: Never call setState directly in component function body (except in event handlers).
**Why**: Causes infinite render loop — setState triggers re-render, which calls setState again.
**Check**: `setXxx(` not inside useCallback/useEffect or event handler.

```bash
# Anti-pattern
grep -rn "set[A-Z][a-zA-Z]*(" src/ | grep -v "onClick\|onChange\|useEffect\|useCallback\|handle"
```

### 8. DangerouslySetInnerHTML without sanitization

**What**: Never use `dangerouslySetInnerHTML` with raw strings — always sanitize first.
**Why**: XSS vulnerability — user input can execute arbitrary JavaScript.
**Check**: dangerouslySetInnerHTML without DOMPurify or similar sanitization.

```bash
# Anti-pattern
grep -rn "dangerouslySetInnerHTML" src/ | grep -v "DOMPurify\|sanitize\|isTrusted"
```

### 9. Missing ErrorBoundary for async content

**What**: Components that load data asynchronously must be wrapped in ErrorBoundary.
**Why**: Network errors crash the entire app, not just the component.
**Check**: Data-fetching components without ErrorBoundary ancestor.

```bash
# Check for useEffect data fetching without ErrorBoundary in component tree
grep -rn "useEffect.*fetch\|axios\|fetch(" src/ | grep -v "ErrorBoundary\|componentDidCatch"
```

### 10. Prop drilling without context

**What**: Passing the same props through 3+ component levels indicates need for Context.
**Why**: Prop drilling makes components less reusable and harder to maintain.
**Check**: Same prop passed through 3+ intermediate components.

```bash
# Manual review needed — pattern: same prop name in 3+ parent-child chains
```

### 11. useReducer with string action types

**What**: Use discriminated union actions, not string literals like `{ type: 'INCREMENT' }`.
**Why**: String types don't provide type safety; typos cause silent bugs.
**Check**: Action objects with string types without TypeScript discriminated unions.

```bash
# Anti-pattern
grep -rn "type:.*'" src/ | grep "useReducer\|dispatch" | grep -v "@type\|ActionTypes"
```

### 12. Conditional hooks (forbidden)

**What**: Hooks must be called unconditionally at top level of component.
**Why**: React relies on call order to maintain state between renders.
**Check**: useState/useEffect inside if/for/while blocks.

```bash
# Anti-pattern
grep -rn "useState\|useEffect" src/ | grep -v "^\s*if\|^\s*for\|^\s*while" | head -1
# Then manually check for hooks inside conditionals
```

### 13. useLayoutEffect without reason

**What**: Prefer useEffect over useLayoutEffect unless measuring DOM layout.
**Why**: useLayoutEffect blocks paint and can cause performance issues.
**Check**: useLayoutEffect without clear DOM measurement purpose.

```bash
# Check: useLayoutEffect without DOM read/write
grep -rn "useLayoutEffect" src/ | grep -v "getBoundingClientRect\|offsetHeight\|clientRect"
```

### 14. Missing React.FC type for components

**What**: Function components should be typed with `React.FC<Props>` or explicit props type.
**Why**: Consistency, explicit children handling, future-proof for React type changes.
**Check**: Component without explicit type annotation.

```bash
# Anti-pattern
grep -rn "function.*Props" src/ --include="*.tsx" | grep -v "React.FC\|FC<"
```

### 15. Hardcoded magic numbers

**What**: Magic numbers should be extracted to named constants.
**Why**: Maintainability, self-documenting code, easier updates.
**Check**: Numeric literals > 2 digits not assigned to const.

```bash
# Anti-pattern
grep -rn " {\s*[0-9]\{3,\}" src/ | grep -v "const\|timeout\|delay\|duration"
```

### 16. Missing dependency array entirely

**What**: Every useEffect/useCallback/useMemo must have a dependency array.
**Why**: Without it, effect runs after every render — performance killer.
**Check**: Hook calls without closing `],` or `])`.

```bash
# Anti-pattern
grep -rn "useEffect(() =>" src/ | grep -v "\], \[\|\], \[\])"
```

### 17. Event handler not wrapped in useCallback

**What**: Event handlers passed to child components must use useCallback.
**Why**: Child components re-render when parent renders; stable callback prevents this.
**Check**: onClick/onChange handlers without useCallback.

```bash
# Check handlers passed to child components
grep -rn "onClick=\{.*\}" src/ | grep -v "useCallback\|ArrowFunctionExpression"
```

### 18. Array mutation instead of copy

**What**: Use `[...arr, item]` not `arr.push(item)` for state updates.
**Why**: Mutating state directly breaks React's change detection.
**Check**: .push(), .splice(), .sort(), .reverse() on state arrays.

```bash
# Anti-pattern
grep -rn "\.push\|\.splice\|\.sort\|\.reverse" src/ | grep -v "\[..." | grep -v "node_modules"
```

### 19. Object mutation instead of copy

**What**: Use `{...obj, key: value}` not `obj.key = value` for state updates.
**Why**: Same as array mutation — breaks React immutability contract.
**Check**: Direct property assignment on objects that might be state.

```bash
# Check for state object mutations
grep -rn "\.name = \|\.id = \|\.value = " src/ | grep -v "const \|let \|this\."
```

### 20. Missing React.memo for pure components

**What**: Components that receive same props should use React.memo.
**Why**: Prevents unnecessary re-renders when parent re-renders with same props.
**Check**: Components that could benefit from memoization.

```bash
# Check: frequently re-rendered parent with static children
grep -rn "export default function\|export function" src/ | grep -v "React.memo\|memo("
```

## Severity Mapping

| Rule | Severity | Rationale |
|------|----------|-----------|
| 1. Missing key prop | error | Breaks list rendering, state corruption |
| 2. Inline functions | warning | Performance, unnecessary re-renders |
| 3. Missing useCallback | warning | Child re-renders, stale closures |
| 4. Missing useMemo | warning | Performance on expensive ops |
| 5. Missing cleanup | error | Memory leaks, duplicate subscriptions |
| 6. Stale closures | error | Bug — effect uses old state |
| 7. setState in render | error | Infinite loop |
| 8. Dangerous HTML | error | XSS security vulnerability |
| 9. No ErrorBoundary | warning | Unhandled errors crash app |
| 10. Prop drilling | info | Maintainability |
| 11. String actions | warning | Type safety, silent bugs |
| 12. Conditional hooks | error | React contract violation |
| 13. useLayoutEffect | warning | Performance |
| 14. No FC type | info | Consistency |
| 15. Magic numbers | info | Maintainability |
| 16. No dependency array | error | Performance, infinite loops |
| 17. Handler not memoized | warning | Child re-renders |
| 18. Array mutation | error | State corruption |
| 19. Object mutation | error | State corruption |
| 20. No memo | info | Performance |

## Already Covered by check-react.sh

These patterns are already checked by the existing script:

- `react-falsy-zero`: .length && renders 0 in UI
- `react-index-as-key`: Array index used as key
- `react-async-effect`: async function passed to useEffect
- `react-state-mutation`: .push() with setState
- `react-no-initial-state`: useState() without initial value
- `react-effect-no-deps`: useEffect without dependency array
- `react-no-cleanup`: addEventListener without removeEventListener
- `react-direct-dom`: Direct DOM manipulation

## References

- Epic React Training: https://epicreact.dev
- React Docs: https://react.dev
- Kent C. Dodds: https://kentcdodds.com