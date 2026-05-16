---
summary: TypeScript language plugin — checks for package.json, tsconfig, npm audit, outdated deps, linting.
status: proposed
---

# ADR-015: TypeScript Language Plugin

## Context

TypeScript/JavaScript is the most common language across our repos. The plugin should catch common issues that AI-generated code introduces: unpinned deps, missing strict mode, no test scripts, `any` types everywhere.

## Decision

### Checks

| Check | What | Severity | Autofix |
|-------|------|----------|---------|
| `check-package-json` | Required fields, pinned versions, test script | error/warning | Partial (npm pkg set) |
| `check-tsconfig-strict` | strict: true, noAny, noImplicitReturns | error | No |
| `check-npm-audit` | Known vulnerabilities | error | `npm audit fix` |
| `check-npm-outdated` | Stale dependencies | warning | `npm update` |
| `check-eslint` | Lint rules (if configured) | warning | `eslint --fix` |
| `check-biome` | Format + lint (if configured) | warning | `biome check --fix` |
| `check-node-version` | engines field matches .nvmrc/.node-version | warning | No |
| `check-lockfile` | package-lock.json or pnpm-lock.yaml exists | error | `npm install` |

### package.json required fields

| Field | Why | Fix |
|-------|-----|-----|
| `name` | Identity | `npm pkg set name="my-app"` |
| `version` | Versioning | `npm pkg set version="0.1.0"` |
| `description` | Discoverability | `npm pkg set description="..."` |
| `license` | Legal compliance | `npm pkg set license="MIT"` |
| `repository` | Traceability | `npm pkg set repository.url="..."` |
| `engines` | Reproducibility | `npm pkg set engines.node=">=20"` |
| `scripts.test` | Testability | `npm pkg set scripts.test="vitest"` |

### tsconfig.json strict settings

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### Dependency pinning

Unpinned versions (`^1.2.3`, `~1.2.3`) cause:
- Non-reproducible builds
- Silent breaking changes
- Security vulnerabilities from auto-updates

cpm checks for exact versions and reports violations.

### Integration with findings.sh

All checks use the shared findings library:

```bash
source lib/shell/findings.sh
findings_init "check-npm-audit"
# ... parse npm audit output ...
findings_add "error" "package.json" "CVE-2024-1234" "lodash prototype pollution" "npm audit fix" "https://nvd.nist.gov/..."
findings_finish  # → JUnit XML + JSONL
```

### Tool detection

Checks auto-detect which tools are available:
- ESLint OR Biome (not both)
- npm OR pnpm OR yarn
- .nvmrc OR .node-version OR engines field

## File structure

```text
checks/typescript/
├── check-package-json.sh
├── check-tsconfig-strict.sh
├── check-npm-audit.sh
├── check-npm-outdated.sh
├── check-eslint.sh
├── check-biome.sh
├── check-node-version.sh
└── check-lockfile.sh
```

## Consequences

- Any TypeScript repo gets 8 checks by adding `lang = "typescript"` to cpm.toml
- Findings tracked with first-seen commit (new vs existing debt)
- JUnit XML for CI integration
- Clear fix commands for every violation

## References

- @see lib/shell/findings.sh (shared findings library)
- @see docs/adrs/adr-014-findings-database.md (JSONL format)
- @see docs/adrs/adr-012-maturity-framework-research.md (framework coverage)
