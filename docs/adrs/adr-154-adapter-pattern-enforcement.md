# ADR-154: Adapter Pattern Enforcement for External Libraries

## Status

Accepted (implemented 2026-07-19)

## Context

Projects accumulate tight coupling to external libraries. When a lib is deprecated (moment.js), has a security issue, or a better alternative appears, swapping requires changing every file that imports it. This is the #1 cause of "we can't upgrade because it's everywhere."

## Decision

Enforce the adapter/wrapper pattern via static analysis:

- **Threshold:** If a library is imported in **3+ source files**, flag it
- **75 libraries** tracked across 15 categories
- **Exclude:** test files, config files, the adapter itself

### When to Wrap (✅)

Infrastructure libs where you call their API:
- HTTP (axios, ky), Date (dayjs, date-fns), DB (prisma, drizzle)
- Logging, analytics, email, payments, auth, cache, queues

**Why:** You use 3-5 functions. Swap takes <1 day. No UI impact.

### When NOT to Wrap (❌)

UI/framework libs where your code IS the lib:
- MUI components, TanStack Query hooks, Next.js primitives, React

**Why:** "Wrapping" `<Button>` adds a useless passthrough. Swapping means rewriting all UI regardless of wrapper.

### Grey Area (🟡)

Wrap the config, not the component:
- MUI → theme tokens are your adapter (don't hardcode hex)
- TanStack → queryFn is your adapter (service layer)
- Env vars → config adapter with validation

## Consequences

- Projects have a clear `src/lib/` directory with one adapter per concern
- Library swaps are 1-file changes (e.g., dayjs → Temporal)
- Usage is tracked: you know exactly which functions you need
- Bundle is controlled: adapter re-exports only what's used
- Documentation at `docs/checks/adapter-pattern.md`
