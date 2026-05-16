# Engineering Knowledge Base

**150+ ADRs and patterns from proven projects**

## Quick Access

- [llama-cli ADRs](llama-cli/) — 118 ADRs (C++ project)
- [workspace-tui ADRs](workspace-tui/) — 30+ ADRs (TypeScript project)
- [CPM ADRs](../docs/adr/) — 7 ADRs (this project)

## Frameworks

- [Quality Framework](../docs/frameworks/quality-framework.md) — CMMI 0-3, V-Model, Three Pillars
- [V-Model Integration](llama-cli/adr-003-v-model-workflow.md)
- [AI-Guided Development](llama-cli/adr-047-ai-guided-development-qa.md)

## Patterns

- [Centralized UI](../docs/patterns/ui-pattern.md) — Single source for terminal output
- [Check Registry](../docs/patterns/registry-pattern.md) — JSON-driven quality gates
- [3-Tier Quality Gates](llama-cli/adr-002-quality-checks.md)
- [Registry-Driven Runners](workspace-tui/) — Git hooks from registry

## Principles

- **RTFM** — Respect The Framework's Model
- **KISS** — Keep It Simple Stupid
- **YAGNI** — You Aren't Gonna Need It
- **NBI** — Naming By Intention
- **HIPI** — Hide Implementation, Present Interface
- **C4C** — Coding For Clarity
- **C4I** — Code for Inclusivity

See [llama-cli/adr-048](llama-cli/adr-048-quality-framework.md) for full definitions.

## By Topic

### Testing
- [Test Framework](llama-cli/adr-008-test-framework.md)
- [Layered Test Strategy](llama-cli/adr-055-layered-test-strategy.md)
- [Mutation Testing](llama-cli/adr-067-mutation-testing.md)
- [HTTP Mock Testing](llama-cli/adr-058-http-mock-testing.md)
- [E2E Test Improvements](llama-cli/adr-032-e2e-test-improvements.md)

### Security
- [Secret Detection](llama-cli/adr-002-quality-checks.md)
- [PII Detection](llama-cli/adr-098-pii-detection.md)
- [Unicode Character Policy](llama-cli/adr-102-unicode-character-policy.md)
- [SonarCloud Integration](llama-cli/adr-074-sonarcloud-integration.md)

### Architecture
- [Module Layout](llama-cli/adr-018-module-layout.md)
- [Provider Abstraction](llama-cli/adr-020-provider-abstraction.md)
- [Centralized State](llama-cli/adr-082-centralized-state.md)
- [SOLID Refactoring](llama-cli/adr-066-solid-refactoring.md)

### Quality
- [Quality Framework](llama-cli/adr-048-quality-framework.md) ⭐
- [Bidirectional Traceability](llama-cli/adr-095-bidirectional-traceability.md)
- [Dead Code Enforcement](llama-cli/adr-064-dead-code-enforcement.md)
- [File Size Limits](llama-cli/adr-061-file-size-limits.md)

### AI/Automation
- [AI-Guided Development](llama-cli/adr-047-ai-guided-development-qa.md)
- [Model Selection](llama-cli/adr-048-quality-framework.md#12a-model-selection)
- [Scaffolding First](llama-cli/adr-100-scaffolding-first.md)

### Process
- [V-Model Workflow](llama-cli/adr-003-v-model-workflow.md)
- [Branching Strategy](llama-cli/adr-006-branching-strategy.md)
- [Version Pinning](llama-cli/adr-026-version-pinning.md)
- [Self-Documenting Processes](llama-cli/adr-023-self-documenting-processes.md)

## By CMMI Level

### Level 0 (Essentials)
- Conventional commits
- Branch naming
- Basic linting
- Secret detection
- Build compiles
- README exists

### Level 1 (Managed)
- Unit tests (≥60% coverage)
- SAST security
- TODO scraping
- Peer review
- E2E tests
- Complexity ≤10

### Level 2 (Defined)
- Coverage ≥80%
- Mutation testing
- C4 diagrams
- AI review
- Performance baseline
- SLA monitoring

### Level 3 (Optimizing)
- DORA metrics
- Predictive analysis
- Cross-team scanning
- Portfolio dashboard

See [Quality Framework](llama-cli/adr-048-quality-framework.md) for complete details.

## Search

```bash
# Find ADRs by keyword
grep -r "mutation testing" knowledge/

# Find by CMMI level
grep -r "CMMI 2" knowledge/

# Find by principle
grep -r "KISS" knowledge/
```

## Contributing

ADRs blijven in hun originele repo. CPM linkt ze via symlinks.

To add your repo:
```bash
cd cpm/knowledge
ln -s ../../your-repo/docs/adr your-repo
```

## Stats

- **llama-cli**: 118 ADRs
- **workspace-tui**: 30+ ADRs
- **cpm**: 7 ADRs
- **Total**: 155+ ADRs

Last updated: 2026-05-11
