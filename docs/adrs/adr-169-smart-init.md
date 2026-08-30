# ADR-169: Smart Init — Idempotent Config with Rule Relevance Detection

**Status:** Proposed
**Date:** 2026-08-30
**Deciders:** @rkristelijn
**See also:** ADR-145 (rule engine), ADR-166 (engine extensions), enforcement-levels.md, maturity.md

## Context

`cpm init` currently generates a static `cpm.toml` with hardcoded checks for C++ projects. Running it twice fails ("already exists"). There are three problems:

1. **No project awareness** — init generates the same config for a React app, a Go microservice, and a Terraform repo. All 899 rules run regardless of whether the repo has `.go`, `.py`, or `.tf` files.

2. **No upgrade path** — when cpm adds new rules or deprecates old ones, existing projects don't benefit. Users must manually discover and enable new checks.

3. **No maturity awareness** — a weekend prototype gets the same checks as a production system. This creates noise and discourages adoption.

## Decision

Transform `cpm init` from a one-shot generator into an **idempotent config reconciler**. Running `cpm init` on an existing project is always safe — it merges, never overwrites.

### Core principle: detect → match → reconcile

```text
cpm init
  ├── detect: what's in this repo?
  ├── match: which rules apply?
  ├── reconcile: update cpm.toml (add new, flag deprecated, preserve user choices)
  └── report: show what changed
```

### Phase 1: Project detection

Scan the repo to build a project profile. This reuses and extends `cpm_detect_lang()`.

```c
struct ProjectProfile {
  // Languages (by file count, descending)
  char langs[8][32];        // ["typescript", "python", "shell"]
  int lang_count;

  // Frameworks (detected from config files + deps)
  char frameworks[16][64];  // ["nextjs", "express", "jest", "docker", "github-actions"]
  int framework_count;

  // Infrastructure
  bool has_docker;
  bool has_k8s;
  bool has_terraform;
  bool has_ci;              // .github/workflows, .gitlab-ci.yml, Jenkinsfile
  bool has_ansible;

  // Maturity signals
  bool has_tests;
  bool has_readme;
  bool has_contributing;
  bool has_security_md;
  bool has_license;
  bool has_lockfile;
  int  estimated_maturity;  // 0-4 based on signals
};
```

Detection heuristics (fast, no external tools):

| Signal | How | Maps to |
|--------|-----|---------|
| Language | Extension counting (existing `cpm_detect_lang`) | Rule directories: `go/`, `rust/`, `python/`, etc. |
| Next.js | `next.config.*` exists | `nextjs/`, `react/`, `web/`, `a11y/` |
| Express | `package.json` contains `"express"` | `express/`, `backend/`, `web/` |
| Spring | `pom.xml` contains `spring-boot` | `spring/`, `java/`, `backend/` |
| Django | `manage.py` or `settings.py` | `django/`, `python/`, `backend/` |
| Docker | `Dockerfile` or `docker-compose.yml` | `docker/` |
| Kubernetes | `*.yaml` with `kind: Deployment` or `helm/` | `k8s/` |
| Terraform | `*.tf` files | `iac/` |
| GitHub Actions | `.github/workflows/` | `cicd/`, `supply-chain/` |
| GraphQL | `*.graphql` or `schema.graphql` | `graphql/` |
| gRPC | `*.proto` files | `grpc/` |
| Tests | `test/`, `tests/`, `*_test.*`, `*.spec.*` | `test/`, `slop/` |
| README | `README.md` exists | maturity signal |
| CI | any CI config exists | maturity signal |

### Phase 2: Rule matching

Given the profile, determine which rule directories are relevant:

```text
Rule directories: 53 total
  Always active: security/, secrets/, supply-chain/, project/, quality/, style/, slop/
  Language-gated: go/, rust/, python/, java/, kotlin/, php/, ruby/, csharp/
  Framework-gated: nextjs/, react/, express/, django/, flask/, spring/, laravel/, rails/
  Infra-gated: k8s/, docker/, iac/, ansible/, serverless/, nginx/
  Content-gated: a11y/, web/, css/, graphql/, grpc/, api/, migration/, bundler/
```

A directory is "relevant" when the project has matching files. The match is cheap: we already know the languages and frameworks from Phase 1.

### Phase 3: Idempotent config reconciliation

This is the key design decision. `cpm init` becomes a **merge operation**:

```text
Existing cpm.toml  +  Detected profile  +  Rule catalog  →  Updated cpm.toml
```

Rules for merging:

| Situation | Action |
|-----------|--------|
| New project (no cpm.toml) | Generate fresh config with detected rules |
| Existing config, new rule directory relevant | Add `[rules.include]` entry, print "NEW: added go/ rules (35 rules)" |
| Existing config, directory no longer relevant | Keep but comment out, print "UNUSED: k8s/ rules — no k8s files detected" |
| User explicitly disabled a rule | **Never re-enable** — user intent is sacred |
| Rule deprecated in new cpm version | Add comment `# DEPRECATED in 0.9.0: use X instead`, print warning |
| New cpm version adds rules to existing directory | Silent — rules auto-load from directory |
| Maturity increased | Suggest stricter enforcement level |

#### Config format

```toml
# cpm.toml — auto-maintained by `cpm init`
# Last reconciled: 2026-08-30 by cpm 0.8.3
# Detected: typescript + nextjs + docker + github-actions
# Estimated maturity: 2 (Defined)

[project]
name = "my-app"
version = "1.2.0"
lang = "typescript"
build = "npm"

[enforcement]
level = "guide"

[rules]
# Active rule sets (based on detected project profile)
include = [
  "security",       # always active — 35 rules
  "secrets",        # always active — 80 rules
  "supply-chain",   # always active — 72 rules
  "quality",        # always active — 47 rules
  "style",          # always active — 28 rules
  "slop",           # always active — 14 rules
  "project",        # always active — 4 rules
  "test",           # always active — 35 rules
  "web",            # detected: .html/.tsx files — 13 rules
  "a11y",           # detected: .html/.tsx files — 120 rules
  "css",            # detected: .css/.scss files — 16 rules
  "nextjs",         # detected: next.config.* — 2 rules
  "react",          # detected: package.json has react — 1 rule
  "express",        # detected: package.json has express — 2 rules
  "docker",         # detected: Dockerfile — 3 rules
  "cicd",           # detected: .github/workflows/ — 17 rules
  "bundler",        # detected: webpack/vite config — 10 rules
  "backend",        # detected: server-side code — 17 rules
  "transport",      # detected: HTTP calls — 7 rules
]

# Inactive (not detected in this project — uncomment to enable)
# "go"             # no .go files detected
# "rust"           # no .rs files detected
# "k8s"            # no k8s manifests detected
# "terraform"      # no .tf files detected
# "ansible"        # no playbooks detected
# "django"         # no django project detected
# "spring"         # no spring project detected

[rules.disable]
# Explicitly disabled rules (cpm init will never re-enable these)
# SLOP-119 = "promotional headers are fine for our docs"

[maturity]
target = 2
estimated = 2
last-assessed = "2026-08-30"
```

### Phase 4: Upgrade detection

When cpm version changes, `cpm init` compares its rule catalog against the config:

```text
$ cpm init
cpm 0.9.0 — reconciling cpm.toml...

  Detected: typescript + nextjs + docker + github-actions (unchanged)
  Maturity: 2 → 3 (CI coverage added since last assessment)

  Changes:
    NEW     serverless/    10 rules — detected: serverless.yml
    NEW     SLOP-120       rule added in 0.9.0 (already in slop/ directory)
    MOVED   SEC-010        → SECRETS-081 (alias kept for backwards compat)
    REMOVED QUAL-018       deprecated in 0.9.0, replaced by SLOP-118

  Suggestion:
    Maturity reached 3 — consider: level = "guard" (currently "guide")

  Updated cpm.toml (3 changes). Review with: git diff cpm.toml
```

The key insight: **rules within an included directory auto-load**. So adding `SLOP-120.rule` to the `slop/` directory is automatically picked up — no config change needed. Config changes are only needed when:
- A new *directory* becomes relevant (new framework detected)
- A *directory* is no longer relevant (framework removed)
- The *enforcement level* should change (maturity progression)
- A *rule is deprecated* and needs flagging

### Phase 5: Maturity-aware rule behavior

Rules already have `severity: error | warning | info`. The enforcement level already controls blocking. The missing piece is connecting maturity to which severities are *visible*:

| Maturity | Enforcement | Errors | Warnings | Info |
|----------|-------------|--------|----------|------|
| 0-1 | learn | show | hide | hide |
| 2 | guide | show | show | hide |
| 3 | guard | block | show | hide |
| 4 | enforce | block | block | show |

This requires no rule changes — it's a filter in the output layer. A maturity-1 project still *runs* all rules but only *shows* errors. This means:
- You can always run `cpm check --full` to see everything
- `cpm check` respects your maturity level
- As maturity grows, more findings become visible naturally

## Implementation plan

| Phase | Effort | What changes |
|-------|--------|-------------|
| 1: Detection | S | New `detect_project_profile()` in `toml.cpp`, reuses existing lang detection |
| 2: Rule matching | S | Map profile → rule directories, count applicable rules |
| 3: Config reconciliation | M | Rewrite `cmd_init()` to merge instead of create, add `[rules]` section |
| 4: Upgrade detection | M | Compare rule catalog version, detect added/deprecated rules |
| 5: Maturity-aware output | S | Filter findings by maturity level in `run_rules()` output |

Phases 1-3 can ship together. Phase 4 requires a rule catalog version (simple: embed rule count + hash at build time). Phase 5 is independent.

## Consequences

### Positive
- `cpm init` is always safe to re-run — makes upgrades trivial
- New projects get a tailored config — less noise from irrelevant rules
- Existing projects automatically benefit from new rules
- Maturity progression is visible and guided
- User overrides (disables) are permanently respected

### Negative
- Detection heuristics can be wrong (e.g., `.ts` files in a non-web project)
- The `[rules.include]` list in cpm.toml adds complexity vs "just run everything"
- Rule catalog versioning needs maintenance

### Mitigations
- Include/exclude is optional — omitting `[rules]` section means "run all" (backwards compatible)
- Detection can be overridden: `cpm init --lang go --framework gin`
- `cpm init --force` regenerates from scratch (current behavior, escape hatch)

## Alternatives considered

### A: Per-rule maturity field
Add `maturity: 2` to each `.rule` file. Rules only activate at that maturity level.

**Rejected:** Too granular. 899 rules × 5 maturity levels = maintenance nightmare. The directory-based grouping with severity filtering achieves the same effect with less complexity.

### B: Separate config per maturity level
`cpm-learn.toml`, `cpm-guide.toml`, `cpm-enforce.toml`.

**Rejected:** Config proliferation. One file with a level setting is simpler.

### C: Never filter rules, let the user deal with noise
Run all 899 rules on every project.

**Rejected:** A React project doesn't need 35 Go rules, 31 Rust rules, 26 K8s rules, and 15 Ansible rules. That's 107 irrelevant rules slowing down the scan and cluttering findings.
