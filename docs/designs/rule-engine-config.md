# Design: Rule Engine Configuration

**Status**: Draft
**Date**: 2026-08-27
**Author**: Kiro (AI-assisted)
**Related**: ADR-145 (Pluggable Rule Engine), ADR-159 (cpm.toml canonical order)

## Problem

Running `cpm rule-scan` on the cpm repo itself produces 269 findings, of which ~33 are false positives:

| Finding | Count | Why it's a FP |
|---------|-------|---------------|
| `BUILD-042` (require() in ESM) | 14 | `checks/javascript/*.js` are CJS scripts, not ESM |
| `SCA-028` (hook network call) | 5 | `.githooks/pre-commit` is our own hook |
| `QUAL-052` (6+ params) | 14 | Tooling scripts, not application code |

Rules themselves are correct — the patterns are real risks. But projects need a way to say "I know, this is intentional here."

Currently the only suppression mechanism is `cpm:ignore <category>` inline annotations. There's no project-level configuration for the rule engine.

## Requirements

1. Project-level rule skip (without modifying source files)
2. Project-level path exclusions (beyond what rules define)
3. Category-level skip (disable entire rule groups)
4. Baseline support (ignore known findings, alert on new ones)
5. Zero config by default — works without any `[rules]` section
6. Inline `cpm:ignore` continues to work alongside project config

## Proposal

### cpm.toml syntax

```toml
[rules]
# Skip specific rules by ID (exact match)
skip = [
  "BUILD-042",   # CJS project, require() is fine
  "SCA-028",     # Our own git hooks, not malicious
]

# Skip entire categories
skip_categories = [
  "bundler",     # No webpack/vite in this project
]

# Additional paths to exclude (merged with per-rule exclude_paths)
exclude_paths = [
  "fixtures/",
  "testdata/",
  ".githooks/",
]

# Minimum severity to report (default: all)
# Options: "error", "warning", "info"
min_severity = "warning"

# Baseline file — findings in baseline are suppressed
# Generate with: cpm rule-scan --baseline > .cpm/baseline.jsonl
baseline = ".cpm/baseline.jsonl"
```

All fields are optional. Missing `[rules]` section = no filtering (current behavior).

### Baseline workflow

```bash
# First run: accept current findings as baseline
cpm rule-scan --baseline > .cpm/baseline.jsonl

# Subsequent runs: only new findings reported
cpm rule-scan
# → reads baseline from cpm.toml, suppresses known findings

# After fixing findings: regenerate baseline
cpm rule-scan --baseline > .cpm/baseline.jsonl
```

Baseline matches on `(rule_id, file, message)` — not line number (lines shift with edits).

### Implementation

#### Data structures (rule_engine.h)

```cpp
/** @brief Configuration for rule engine filtering. */
struct RuleConfig {
  std::vector<std::string> skip_rules;       // exact rule IDs to skip
  std::vector<std::string> skip_categories;  // categories to skip
  std::vector<std::string> exclude_paths;    // additional path exclusions
  std::string min_severity;                  // "error", "warning", "info", "" (all)
  std::string baseline_path;                 // path to baseline JSONL file
};
```

#### Filter entry points

**1. Rule loading** — filter at load time (cheapest):

```cpp
// In rules_load(), after parsing:
if (config.skip_rules contains rule.id) → skip
if (config.skip_categories contains rule.category) → skip
```

**2. File matching** — add config paths to exclude list:

```cpp
// In rule_matches_file(), merge config exclude_paths:
for (auto& excl : config.exclude_paths) {
  if (rel_path.find(excl) != std::string::npos) return false;
}
```

**3. Severity filter** — after scanning, before output:

```cpp
// In rules_scan() or caller:
if (severity_rank(finding.severity) < severity_rank(config.min_severity)) → skip
```

**4. Baseline** — after scanning, before output:

```cpp
// Load baseline: set of (rule_id, file, message) tuples
// For each finding: if in baseline set → suppress
```

#### Config loading

Extend `toml.cpp` to parse `[rules]` section. The TOML parser already handles arrays of strings for `[checks]`.

```
[rules]
skip = ["BUILD-042", "SCA-028"]
```

Parsed into `RuleConfig` and passed to `rules_scan()`.

#### API change

```cpp
// Before:
std::vector<RuleFinding> rules_scan(
    const std::vector<Rule>& rules,
    const std::string& root);

// After:
std::vector<RuleFinding> rules_scan(
    const std::vector<Rule>& rules,
    const std::string& root,
    const RuleConfig& config = {});
```

Default-constructed `RuleConfig` has empty vectors = no filtering = backward compatible.

### Inline suppression (already exists)

```cpp
// cpm:ignore secret
auto key = "sk-12345678901234567890";
```

Extends to rule engine: scanner checks each line for `cpm:ignore <rule-id>` or `cpm:ignore <category>`.

```cpp
// In line scanning loop:
if (line contains "cpm:ignore " + rule.id) → skip this finding
if (line contains "cpm:ignore " + rule.category) → skip this finding
```

### Priority order

Most specific wins:

1. Inline `cpm:ignore BUILD-042` — suppresses one finding on one line
2. `[rules] skip = ["BUILD-042"]` — suppresses rule across project
3. `[rules] skip_categories = ["build"]` — suppresses all BUILD-* rules
4. `[rules] min_severity = "warning"` — hides all info-level findings
5. `[rules] baseline = "..."` — suppresses known findings

### CLI flags

```bash
cpm rule-scan                        # uses cpm.toml config
cpm rule-scan --no-config            # ignore cpm.toml [rules] section
cpm rule-scan --skip BUILD-042       # ad-hoc skip (merged with config)
cpm rule-scan --min-severity error   # override min severity
cpm rule-scan --baseline > file.jsonl  # generate baseline
```

## Alternatives considered

### 1. Hardcoded exclude_paths in .rule files

Rejected — rules should be generic. Project-specific exclusions belong in project config.

### 2. .cpmignore file (gitignore-style)

Rejected — adds another config file. `cpm.toml` is the single source of truth (ADR-159).

### 3. Comments in .rule files for project overrides

Rejected — rules are shared/upstream, not project-specific.

## Migration

- No breaking changes — `[rules]` section is optional
- Existing `cpm:ignore` inline annotations continue to work
- Existing `cpm.toml` files without `[rules]` behave identically

## Test plan

1. Unit test: `RuleConfig` with `skip_rules` → skipped rules not loaded
2. Unit test: `RuleConfig` with `skip_categories` → category filtered
3. Unit test: `RuleConfig` with `exclude_paths` → paths excluded
4. Unit test: `RuleConfig` with `min_severity` → low-severity filtered
5. Unit test: baseline load + match → known findings suppressed
6. Unit test: inline `cpm:ignore RULE-ID` → single finding suppressed
7. E2E test: `cpm rule-scan` with `[rules] skip` in cpm.toml
8. E2E test: `--baseline` flag generates JSONL
9. Dogfood: cpm repo itself with `[rules]` config → 0 FP's
