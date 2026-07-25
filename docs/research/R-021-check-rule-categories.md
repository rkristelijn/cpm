# R-021: Check Rule Categories & Engine Design

**Date:** 2026-07-21  
**Status:** Research  
**Context:** Determine which check types exist in cpm to design a pluggable rule engine

## Current Check Inventory (159 checks)

### Category Breakdown

| Type | Count | Description | YAML-able? |
|------|-------|-------------|------------|
| **Pattern grep** | 74 | Regex match in files (present = bad) | ✅ Trivial |
| **Mixed logic** | 45 | Combination of grep + file-exists + conditionals | ⚠️ Partially |
| **Scoring/metrics** | 36 | Count things, compute score, threshold | ❌ Needs engine |
| **External tool** | 4 | Wraps shellcheck, yamllint, etc. | ❌ Delegate |

### Rule Engine Types Needed

Based on analysis, we need **5 engine types** in the C++ core:

---

## Engine 1: Pattern Match (74 checks → YAML rules)

**What it does:** "Find this regex in these files = finding"

**Examples:**

- `check-secrets-fast` — regex for API keys in source
- `check-dutch` — Dutch word markers in files
- `check-pii` — email/phone patterns
- `check-dangerous-shell` — rm -rf, eval, etc.
- `check-k8s-hardening` — missing security fields
- `check-zero-day-patterns` — known vulnerable patterns

**YAML rule format:**

```yaml
id: SEC-001
severity: error
target:
  extensions: [".ts", ".js", ".py", ".yaml"]
  exclude: ["test/", "vendor/"]
patterns:
  - regex: 'AKIA[A-Z0-9]{16}'
    message: "AWS Access Key ID detected"
  - regex: 'sk-[a-zA-Z0-9]{20,}'
    message: "OpenAI API key detected"
```

---

## Engine 2: Presence Check (part of mixed, ~30 checks)

**What it does:** "Does file/field exist? Yes/no = finding"

**Examples:**

- `check-package-json` — has description? has engines? has lockfile?
- `check-gitignore` — does .gitignore exist? has certain entries?
- `check-process` — has CONTRIBUTING.md? CHANGELOG? CI pipeline?
- `check-lockfile` — lockfile exists?

**YAML rule format:**

```yaml
id: PROJ-001
severity: warning
type: presence
checks:
  - file_exists: "package-lock.json|pnpm-lock.yaml|yarn.lock"
    message: "No lockfile found"
    when_missing: true
  - file_contains:
      path: "package.json"
      pattern: '"engines"'
    message: "No engines field — Node.js version not pinned"
    when_missing: true
```

---

## Engine 3: Absence Check / "Match Without" (~20 checks)

**What it does:** "File has A but NOT B = finding"

**Examples:**

- `check-k8s-hardening` — has `containers:` but no `runAsNonRoot: true`
- `check-k8s-best-practices` — has `containers:` but no `resources:`
- `check-no-var` — has `var` but not in legacy file

**YAML rule format:**

```yaml
id: K8S-001
severity: error
type: match_without
target:
  extensions: [".yaml", ".yml"]
  content_match: "kind:\\s*(Deployment|Pod)"
requires:
  present: "containers:"
  absent: "runAsNonRoot:\\s*true"
message: "Pod runs as root (CIS 5.2.6)"
```

---

## Engine 4: Scoring/Metrics (~36 checks)

**What it does:** Count patterns, compute ratios, compare to threshold.

**Examples:**

- `check-spaghetti-score` — files >300 lines, nesting depth, import count → score
- `check-comment-ratio` — comments / total lines ratio
- `check-duplication` — similar blocks count
- `check-file-size` — files over threshold
- `check-test-quality` — assertions per test
- `check-neglect-score` — stale files, dead code

**NOT YAML-able as simple rules.** These need the C++ engine to:

1. Walk files
2. Count/measure
3. Compute score
4. Compare threshold

**YAML config (parameters only):**

```yaml
id: QUAL-001
type: metric
engine: file_size
params:
  max_lines: 300
  extensions: [".ts", ".js", ".cpp", ".py"]
  exclude: ["vendor/", "generated/"]
severity: warning
message: "File exceeds {lines} lines (max: {max_lines})"
```

Built-in metric engines in C++:

- `file_size` — lines per file
- `nesting_depth` — brace/indent depth
- `import_count` — import/require statements per file
- `comment_ratio` — comments vs code
- `pattern_density` — occurrences per file/LOC

---

## Engine 5: External Tool Delegation (4 checks)

**What it does:** Run external binary, parse output.

**Examples:**

- `lint-yaml` → yamllint
- `check-ts-audit` → npm audit
- `check-php-audit` → composer audit
- `check-sbom` → trivy/syft

**YAML config:**

```yaml
id: TOOL-001
type: external
command: "yamllint -c .config/yamllint.yml ."
available_check: "yamllint --version"
skip_if_unavailable: true
output_format: parseable  # or: json, sarif
severity: warning
```

---

## Architecture

```text
┌─────────────────────────────────────────────┐
│            cpm binary (C++)                  │
├─────────────────────────────────────────────┤
│  Core engines (compiled-in):                │
│  ├── PatternEngine      (regex match)       │
│  ├── PresenceEngine     (file/field exists) │
│  ├── AbsenceEngine      (A without B)       │
│  ├── MetricEngine       (count + threshold) │
│  └── ExternalEngine     (run tool, parse)   │
├─────────────────────────────────────────────┤
│  Rule loader:                               │
│  ├── Embedded rules (compiled-in via incbin)│
│  ├── ~/.cpm/rules/     (user global)        │
│  ├── .cpm/rules/       (project local)      │
│  └── --rules-dir       (CLI override)       │
├─────────────────────────────────────────────┤
│  File walker:                               │
│  ├── Respects .gitignore                    │
│  ├── Extension filtering                    │
│  ├── Path include/exclude                   │
│  └── Content pre-filter (fast reject)       │
├─────────────────────────────────────────────┤
│  Output:                                    │
│  ├── Terminal (colored)                     │
│  ├── JSON / JSONL                           │
│  ├── SARIF                                  │
│  └── Markdown                               │
└─────────────────────────────────────────────┘
```

## Migration Priority

| Phase | Checks | Effort | Impact |
|-------|--------|--------|--------|
| 1 | Pattern grep (74) → YAML | Medium | Biggest win, most checks portable |
| 2 | Presence (30) → YAML | Low | Simple engine addition |
| 3 | Absence (20) → YAML | Low | Small engine extension |
| 4 | Metrics (36) → C++ engines + YAML params | High | Complex but high value |
| 5 | External (4) → YAML config | Low | Minimal, just delegation |

## What stays in C++

- File walking + filtering (performance-critical)
- Regex engine (RE2 or std::regex)
- YAML parser (yaml-cpp or toml11 for TOML)
- Metric computation (counting, scoring, thresholds)
- Output formatting
- Rule loading + caching

## What becomes YAML/TOML config

- Pattern definitions (regex + message + severity)
- File targeting (extensions, paths, exclude)
- Thresholds (max lines, min ratio, etc.)
- External tool commands
- Metadata (id, title, description, category, references)

## Estimated Effort

- Phase 1-3 (124 checks → YAML + 3 engines): ~2-3 weekends
- Phase 4 (36 scoring checks → metric engines): ~2 weekends  
- Phase 5 (4 external tools): ~1 evening
- Cross-compile setup (Linux/macOS/Windows): ~1 weekend

Total: **~6 weekends** for full migration to pluggable architecture.
