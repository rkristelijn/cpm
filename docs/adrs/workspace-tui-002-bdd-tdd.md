<!-- Origin: workspace-tui -->
<!-- Status: Proposed (imported) -->

# ADR-002: BDD + TDD Strategy

*Status*: Accepted · *Date*: 2026-05-07
*Based on*: llama-cli ADR-017 (integration tests), ADR-008 (test framework)

## Context

Quality software requires tests at multiple levels. For workspace-tui:

- **BDD** (Behaviour Driven Development) — E2E tests written as user stories in Gherkin, living documentation
- **TDD** (Test Driven Development) — unit tests written before implementation, drives design

Both approaches are complementary:
- BDD defines *what* the system should do (user perspective)
- TDD defines *how* each unit should behave (developer perspective)

## Decision

### Test pyramid

```
        ┌─────────────────┐
        │   E2E / BDD     │  ← Cucumber .feature files
        │   (few, slow)   │
        ├─────────────────┤
        │  Integration    │  ← Vitest, multi-module flows
        │  (some, medium) │
        ├─────────────────┤
        │   Unit / TDD    │  ← Vitest, one module at a time
        │   (many, fast)  │
        └─────────────────┘
```

### BDD — Cucumber.js

E2E tests written in Gherkin, living documentation:

```gherkin
# tests/e2e/features/calendar.feature
Feature: Calendar management

  Scenario: View today's events
    Given I am connected to Google Workspace
    When I open the calendar panel
    Then I should see today's events

  Scenario: Create a new event
    Given I am connected to Google Workspace
    When I create an event "Team standup" at "09:00"
    Then the event should appear in the calendar
```

Step definitions in TypeScript:

```typescript
// tests/e2e/steps/calendar.steps.ts
import { Given, When, Then } from '@cucumber/cucumber';

Given('I am connected to Google Workspace', async () => {
  // setup mock provider
});

When('I open the calendar panel', async () => {
  // simulate keypress
});

Then('I should see today\'s events', async () => {
  // assert panel content
});
```

### TDD — Vitest

Unit tests written before implementation:

```typescript
// src/providers/google/calendar.test.ts
import { describe, it, expect, vi } from 'vitest';
import { GoogleCalendarProvider } from './calendar';

describe('GoogleCalendarProvider', () => {
  it('returns events for date range', async () => {
    const provider = new GoogleCalendarProvider(mockAuth);
    const events = await provider.getEvents(today, tomorrow);
    expect(events).toHaveLength(2);
    expect(events[0].title).toBe('Team standup');
  });

  it('throws on auth failure', async () => {
    const provider = new GoogleCalendarProvider(expiredAuth);
    await expect(provider.getEvents(today, tomorrow))
      .rejects.toThrow('Authentication failed');
  });
});
```

### Naming conventions

| File | Type | What |
|------|------|------|
| `*.test.ts` | Unit test | One module in isolation |
| `*.integration.test.ts` | Integration test | Multi-module flow |
| `tests/e2e/features/*.feature` | BDD spec | User story in Gherkin |
| `tests/e2e/steps/*.steps.ts` | BDD steps | Step definitions |

### Test commands

```bash
npm test              # unit + integration
npm run test:e2e      # BDD/Cucumber
npm run test:coverage # coverage report
npm run test:watch    # watch mode (TDD)
```

### Coverage targets

| Layer | Target |
|-------|--------|
| Providers | ≥ 80% |
| Workflows | ≥ 80% |
| AI layer | ≥ 70% |
| TUI components | ≥ 60% |

### TDD workflow

1. Write failing test
2. Write minimal code to pass
3. Refactor
4. Repeat

```bash
# TDD cycle
npm run test:watch -- src/providers/google/calendar.test.ts
```

### BDD workflow

1. Write `.feature` file (user story)
2. Run Cucumber → pending steps
3. Implement step definitions
4. Implement feature code
5. All steps pass

```bash
# BDD cycle
npm run test:e2e -- --tags @calendar
```

## Alternatives considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Jest | Mature, popular | Slower than Vitest | Rejected |
| Mocha + Chai | Flexible | More boilerplate | Rejected |
| **Vitest** | Fast, ESM-native, Vite-compatible | Newer | **Chosen** |
| Playwright | Great E2E for web | Not for TUI | Rejected |
| **Cucumber.js** | Real BDD, Gherkin, living docs | More setup | **Chosen** |

## Consequences

- `.feature` files serve as living documentation
- Tests drive design (TDD) and specification (BDD)
- Coverage enforced in CI
- Mock providers needed for unit/integration tests

## References

- llama-cli [ADR-017](../../llama-cli/docs/adr/adr-017-integration-tests.md)
- [Vitest](https://vitest.dev)
- [Cucumber.js](https://cucumber.io/docs/installation/javascript/)
- [BDD in Action — John Ferguson Smart](https://www.manning.com/books/bdd-in-action)
