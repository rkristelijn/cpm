---
summary: cpm absorbs npm-audit-plus-plus and npm-outdated-junit — one binary replaces two npm packages.
status: accepted
---

# ADR-147: Sunset npm-audit-plus-plus and npm-outdated-junit

## Context

We maintain two separate npm packages for CI pipeline reporting:

| Package | What it does |
|---------|-------------|
| [npm-audit-plus-plus](https://github.com/rkristelijn/npm-audit-plus-plus) | `npm audit --json` → JUnit XML |
| [npm-outdated-junit](https://github.com/rkristelijn/npm-outdated-junit) | `npm outdated --json` → JUnit XML |

### Problems

1. **Two extra dependencies** per project with their own node_modules, CI, releases
2. **Pipe-based** — fragile (`npm audit --json | npx npm-audit-plus-plus`)
3. **Node-only** — can't use in non-JS projects that still have package.json
4. **No trend tracking** — fire-and-forget XML
5. **Maintenance burden** — two repos for what is JSON→XML transformation

### What cpm already does

cpm's scan runs `deps-npm-audit`, `deps-npm-outdated`, `deps-npm-license` and writes findings to JSONL. It has a JUnit renderer. It just doesn't expose them as standalone commands yet.

## Decision

Port the functionality into cpm and sunset both npm packages.

### What cpm will provide

```bash
cpm audit              # npm audit → findings (console)
cpm audit --junit      # npm audit → JUnit XML
cpm outdated           # npm outdated → findings (console)
cpm outdated --junit   # npm outdated → JUnit XML
cpm license            # license check → findings (console)
cpm license --junit    # license check → JUnit XML
```

### Why NOT npx/npm distribution

cpm is a native C++ binary. Wrapping it in npm would:

- Add Node.js startup overhead to every invocation
- Require a download-wrapper package (complexity for no gain)
- Tie a language-agnostic tool to one ecosystem

Instead, cpm is distributed via:

- `brew install cpm` (macOS)
- `curl -fsSL .../install.sh | bash` (any platform)
- GitHub Action: `uses: rkristelijn/cpm-action@v1`

### CI pipeline migration

Before:

```yaml
- run: npm audit --json | npx npm-audit-plus-plus > npm-audit.junit.xml
- run: npm outdated --json | npx npm-outdated-junit > npm-outdated.junit.xml
```

After:

```yaml
- uses: rkristelijn/cpm-action@v1
- run: cpm audit --junit > npm-audit.junit.xml
- run: cpm outdated --junit > npm-outdated.junit.xml
```

### Deprecation plan

| Phase | When | Action |
|-------|------|--------|
| 1. Build | Now | Implement `cpm audit --junit` and `cpm outdated --junit` |
| 2. Deprecate | cpm 0.5.0 | Add deprecation warning to npm packages pointing to cpm |
| 3. Archive | cpm 0.6.0 | Archive repos, mark npm packages deprecated |

### Deprecation warning

```text
⚠ DEPRECATED: npm-audit-plus-plus is superseded by cpm.
  Install: brew install cpm  (or: curl -fsSL https://cpm.dev/install.sh | bash)
  Usage:   cpm audit --junit
  Info:    https://github.com/rkristelijn/cpm
```

## Implementation

| Component | Status | Needed |
|-----------|--------|--------|
| npm audit JSON parsing | ✅ in scan_checks.cpp | Extract to command |
| npm outdated JSON parsing | ✅ in scan_checks.cpp | Extract to command |
| JUnit XML renderer | ✅ in src/report/junit.cpp | Wire to commands |
| `--junit` flag | ✅ on `cpm findings` | Add to new commands |

Estimated effort: ~2 days.

## Consequences

- One binary replaces two npm packages
- Works in any project (not just Node.js)
- Trend tracking via JSONL findings database
- Faster (no Node.js startup, no npx download)
- Two fewer repos to maintain

## References

- @see <https://github.com/rkristelijn/npm-audit-plus-plus>
- @see <https://github.com/rkristelijn/npm-outdated-junit>
- @see src/scan/scan_checks.cpp (existing parsing)
- @see src/report/junit.cpp (JUnit renderer)
- @see ADR-020 (product vision: one binary, zero friction)
