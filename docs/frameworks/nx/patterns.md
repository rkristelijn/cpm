# Nx Monorepo Patterns

15 checkable patterns for healthy Nx workspaces.

## Project Boundaries

### 1. enforce-module-boundaries Rule

**What**: ESLint rule `@nx/enforce-module-boundaries` must be enabled.

**Why**: Prevents circular dependencies and enforces public API usage through `index.ts` barrels.

**Check**: `.eslintrc.json` contains `"@nx/enforce-module-boundaries"` in `overrides[].rules`.

**Fix**:

```json
{
  "rules": {
    "@nx/enforce-module-boundaries": [
      "error",
      {
        "allowCircleDependency": false,
        "banTransitiveDependencies": true
      }
    ]
  }
}
```

**Docs**: <https://nx.dev/recipes/enforce-module-boundaries>

---

### 2. Consistent Library Naming

**What**: Libraries follow consistent naming convention (`@scope/<type>-<name>`).

**Why**: Makes imports predictable and enables tag-based constraints.

**Check**: `libs/` directories match pattern `feature-*`, `ui-*`, `data-access-*`, `util-*`.

**Fix**: Rename libraries or use tags to categorize:

```json
// project.json
{
  "tags": ["type:feature", "scope:store"]
}
```

---

### 3. Tags for Scope/Type Enforcement

**What**: Every `project.json` has `tags` array defining scope and type.

**Why**: Enables lint rules like "type:feature can depend on type:ui but not vice versa".

**Check**: `find libs -name project.json -exec grep -L '"tags"' {} \;` returns empty.

**Fix**:

```json
{
  "tags": ["type:ui", "scope:shared"]
}
```

**Docs**: <https://nx.dev/concepts/more-concepts/tags-reasons>

---

## Implicit Dependencies

### 4. implicitDependencies Configuration

**What**: `nx.json` or `project.json` defines implicit dependencies for non-TypeScript relationships.

**Why**: Nx can't infer deps between .NET/Java projects; explicit config needed.

**Check**: `nx.json` contains `"implicitDependencies"` section.

**Fix**:

```json
{
  "implicitDependencies": {
    "package.json": "*",
    ".env": "*"
  }
}
```

---

### 5. No Circular Dependencies Between Projects

**What**: Dependency graph has no cycles.

**Why**: Circular deps cause build failures and make changes unpredictable.

**Check**: Run `npx nx graph` and verify no backward edges, or use `nx dep-graph`.

**Fix**: Refactor shared code into a new library, use barrel exports.

---

## Cacheable Operations

### 6. cacheableOperations Defined

**What**: `nx.json` lists operations that produce deterministic outputs.

**Why**: Enables local and remote caching for `build`, `test`, `lint`, `e2e`.

**Check**: `nx.json` contains `"cacheableOperations"` array.

**Fix**:

```json
{
  "tasksRunnerOptions": {
    "default": {
      "options": {
        "cacheableOperations": ["build", "lint", "test", "e2e"]
      }
    }
  }
}
```

---

### 7. targetDefaults with outputs

**What**: Build/test targets declare `outputs` paths.

**Why**: Nx uses outputs to determine cache hits; missing outputs = no caching.

**Check**: `project.json` targets have `"outputs": ["dist/..."]`.

**Fix**:

```json
{
  "targets": {
    "build": {
      "outputs": ["{projectRoot}/dist"],
      "dependsOn": ["^build"]
    }
  }
}
```

---

### 8. namedInputs for Cache Granularity

**What**: `nx.json` defines named input groups for file matching.

**Why**: Controls cache invalidation; e.g., "only invalidate on source changes".

**Check**: `nx.json` contains `"namedInputs"` section.

**Fix**:

```json
{
  "namedInputs": {
    "default": ["{projectRoot}/**/*"],
    "production": ["default", "!{projectRoot}/**/*.spec.ts"]
  }
}
```

---

## Affected Commands

### 9. defaultBase for Affected Commands

**What**: `nx.json` sets `"affected": { "defaultBase": "main" }`.

**Why**: `nx affected` needs a baseline branch to compare against.

**Check**: `nx.json` contains `"defaultBase"`.

**Fix**:

```json
{
  "affected": {
    "defaultBase": "main"
  }
}
```

---

### 10. CI Uses nx affected, Not --all

**What**: CI pipelines use `nx affected` instead of `nx run-many --all`.

**Why**: Running all projects defeats the purpose of affected-based builds.

**Check**: `.github/workflows/*.yml` doesn't contain `run-many.*--all`.

**Fix**:

```yaml
- name: Run affected tests
  run: npx nx affected --target=test --base=origin/main
```

---

## Generators

### 11. Workspace Generators Configured

**What**: `nx.json` or `project.json` has custom generator defaults.

**Why**: Ensures consistent code generation across the workspace.

**Check**: `nx.json` contains `"generators"` section.

**Fix**:

```json
{
  "generators": {
    "@nx/angular:component": {
      "style": "scss",
      "standalone": true
    }
  }
}
```

---

## Shared Library Structure

### 12. Library Type Organization

**What**: Libraries are organized by type: `feature-*`, `ui-*`, `data-access-*`, `util-*`.

**Why**: Clear separation enables tag-based constraints and better encapsulation.

**Check**: `ls libs/` matches type prefixes.

**Fix**: Move libraries to appropriate directories:

```text
libs/
  feature-auth/
  ui-components/
  data-access-api/
  util-formatting/
```

---

### 13. Barrel Exports (index.ts)

**What**: Every library exports public API through `index.ts`.

**Why**: Enforces encapsulation; consumers use `@org/lib` not `libs/lib/src/...`.

**Check**: `find libs -name "index.ts" | wc -l` equals library count.

**Fix**: Create `libs/<name>/index.ts`:

```typescript
export * from './lib/my-lib.component';
export { MyService } from './lib/my-lib.service';
```

---

### 14. No Deep Relative Imports

**What**: No imports like `../../../other-lib/src/internal`.

**Why**: Breaks encapsulation and causes refactoring pain.

**Check**: `grep -r "from.*libs/.*src" apps/ libs/` returns empty.

**Fix**: Use path aliases in `tsconfig`:

```json
{
  "paths": {
    "@print-marketplace/auth": ["libs/feature-auth/src/index.ts"]
  }
}
```

---

## Naming Consistency

### 15. Consistent Project Naming

**What**: All projects follow `<app|lib>-<name>` or `<type>-<name>` convention.

**Why**: Predictable naming aids discovery and `nx list` output.

**Check**: `nx show projects` output follows consistent pattern.

**Fix**: Rename projects using `nx move`:

```bash
npx nx g move libs/old-name libs/feature-new-name
```

---

## Quick Reference

| Pattern | Check Command | Severity |
|---------|---------------|----------|
| enforce-module-boundaries | `grep -r "enforce-module-boundaries" .eslintrc*` | error |
| cacheableOperations | `cat nx.json | grep cacheableOperations` | warning |
| defaultBase | `cat nx.json | grep defaultBase` | warning |
| tags in project.json | `find libs -name project.json -exec grep -L tags {} \;` | warning |
| target outputs | `grep -L outputs project.json` | warning |
| CI uses affected | `grep "run-many.*--all" .github/workflows/` | warning |
| index.ts per lib | `[ $(find libs -name index.ts | wc -l) -eq $(find libs -mindepth 1 -maxdepth 1 -type d | wc -l) ]` | warning |
| No deep imports | `grep -r "from.*libs/.*src" apps/ libs/` | warning |
