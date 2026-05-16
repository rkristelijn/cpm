<!-- Origin: workspace-tui -->
<!-- Status: Proposed (imported) -->

# ADR-003: Quality-Driven Development

*Status*: Accepted · *Date*: 2026-05-07
*Based on*: llama-cli ADR-002 (quality checks)

## Context

Quality is not an afterthought — it is built in from day one. For workspace-tui, quality means:

- Code is readable, maintainable, and consistent
- Security issues are caught before they reach production
- Tests cover the codebase
- Documentation is always up to date

## Decision

### Quality gates (enforced on every PR)

| Tool | Purpose | Threshold |
|------|---------|-----------|
| **ESLint** | TypeScript linting, style, complexity | 0 errors |
| **Prettier** | Code formatting | Auto-format |
| **TypeScript** | Type checking | 0 errors (`strict: true`) |
| **Vitest** | Unit + integration tests | ≥ 80% coverage |
| **Cucumber** | BDD/E2E tests | All scenarios pass |
| **gitleaks** | Secret detection | 0 secrets |
| **npm audit** | Dependency vulnerabilities | 0 high/critical |
| **rumdl** | Markdown linting | 0 errors |

### Local commands

```bash
npm run lint          # ESLint + TypeScript check
npm run format        # Prettier
npm test              # Unit + integration
npm run test:e2e      # BDD/Cucumber
npm run test:coverage # Coverage report
npm run check         # All quality gates
```

### Pre-commit hook

```bash
#!/bin/sh
# .git/hooks/pre-commit
npm run lint && npm run format:check && npm test
```

### CI pipeline

```yaml
# .github/workflows/ci.yml
jobs:
  quality:
    steps:
      - lint
      - type-check
      - test (unit + integration)
      - test:e2e
      - coverage (≥ 80%)
      - security (gitleaks + npm audit)
      - markdown lint
```

### ESLint config

```json
{
  "extends": [
    "eslint:recommended",
    "@typescript-eslint/recommended",
    "plugin:@typescript-eslint/strict"
  ],
  "rules": {
    "complexity": ["error", 10],
    "max-lines-per-function": ["error", 50],
    "no-console": "error"
  }
}
```

### TypeScript config

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### Version pinning

All dependencies pinned to exact versions:

```json
{
  "dependencies": {
    "blessed": "0.1.81",
    "googleapis": "144.0.0"
  }
}
```

### Documentation

- Every public function has JSDoc comment
- Every module has a `@module` comment
- ADRs document all architectural decisions
- `docs/` contains design docs and guides

### Leave the campground cleaner

Every PR must:
- Not decrease coverage
- Not introduce new lint errors
- Not introduce new TypeScript errors
- Update docs if behavior changes

## Rationale

- **Readable**: ESLint complexity limits keep functions simple
- **Secure**: gitleaks + npm audit catch vulnerabilities early
- **Correct**: TypeScript strict mode + tests catch bugs at compile time
- **Documented**: JSDoc + ADRs ensure knowledge is captured
- **Consistent**: Prettier + ESLint enforce style automatically

## Alternatives considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| TSLint | TypeScript-specific | Deprecated | Rejected |
| **ESLint + @typescript-eslint** | Active, extensible | More config | **Chosen** |
| Biome | Fast, all-in-one | Less mature | Considered |
| **Prettier** | Opinionated, zero-config | Less flexible | **Chosen** |

## Consequences

- Contributors need: `node`, `npm`, `git`
- CI enforces all quality gates
- Coverage may slow down initial development — acceptable tradeoff
- Strict TypeScript may require more type annotations

## References

- llama-cli [ADR-002](../../llama-cli/docs/adrs/adr-002-quality-checks.md)
- [ESLint](https://eslint.org)
- [Prettier](https://prettier.io)
- [TypeScript strict mode](https://www.typescriptlang.org/tsconfig#strict)
- [gitleaks](https://github.com/gitleaks/gitleaks)
