# ADR-157: Migratie Shell Checks → Pluggable Rule Engine (Kwaliteitsborging)

**Date:** 2026-07-22
**Status:** Proposed
**Supersedes:** N/A (companion to ADR-145)
**Context:** 160 shell checks moeten gemigreerd worden naar de rule engine ZONDER kwaliteitsverlies. Elke regel moet maximaal configureerbaar zijn, suppress-baar, autofix-baar, en gedocumenteerd.

## Uitgangspunten

1. **Zero regression** — de rule engine moet minstens dezelfde findings produceren als de shell checks
2. **Maximaal pluggable** — elke rule is aan/uit/instelbaar per project
3. **Elke rule compleet** — detect + docs + suppress + fix (waar mogelijk)
4. **Battle-tested patterns behouden** — regex patterns uit shell checks 1:1 overnemen
5. **Incrementeel** — shell en engine draaien naast elkaar tot pariteit bewezen is
6. **eval-repo als gatekeeper** — ~/git/cpm-eval valideert elke migratie-stap

## Minimum eisen per .rule file

Elke gemigreerde regel MOET bevatten:

```yaml
# ─── Identificatie ────────────────────────────────────────────────
id: SEC-010                          # Uniek, stabiel ID
title: Hardcoded AWS Access Key      # Korte beschrijving (1 regel)
category: security                   # security|quality|k8s|deps|docs|style|process
severity: error                      # error|warning|info
tags: [secrets, aws, owasp-a07]      # Vrije tags voor filtering

# ─── Engine configuratie ──────────────────────────────────────────
engine: pattern                      # pattern|absence|presence|metric|external
target:
  extensions: [.ts, .js, .py, .java, .yaml, .json, .env, .sh]
  exclude_paths: [test/, vendor/, node_modules/, .git/]
  content_contains: AKIA             # Optioneel: literal pre-filter

# ─── Detectie ─────────────────────────────────────────────────────
patterns:
  - regex: 'AKIA[A-Z0-9]{16}'
    id: aws-access-key               # Sub-pattern ID (voor granulaire suppress)
    message: "AWS Access Key ID detected"

# ─── Suppress ─────────────────────────────────────────────────────
suppress:
  inline: "cpm:ignore SEC-010"       # Comment-patroon voor inline suppress
  config: "rules.SEC-010 = false"    # cpm.toml pad om hele rule uit te zetten

# ─── Autofix ──────────────────────────────────────────────────────
fix:
  description: "Use AWS_ACCESS_KEY_ID environment variable or secrets manager"
  safe: false                        # true = kan automatisch zonder review
  replacements:                      # Optioneel: regex-based autofix
    - match: 'AKIA[A-Z0-9]{16}'
      replace: '${AWS_ACCESS_KEY_ID}'
      confirm: true                  # Altijd bevestiging vragen
  command: ""                        # Optioneel: extern fix script aanroepen

# ─── Documentatie ─────────────────────────────────────────────────
docs:
  why: |
    Hardcoded AWS credentials in source code worden meegecommit in git history
    en zijn vrijwel onmogelijk volledig te verwijderen. Aanvallers scannen
    publieke repos actief op dit patroon.
  good_example: |
    const key = process.env.AWS_ACCESS_KEY_ID;
  bad_example: |
    const key = "AKIAIOSFODNN7EXAMPLE";
  references:
    - https://owasp.org/Top10/A07_2021/
    - https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

# ─── Tests (validatie dat de rule correct werkt) ──────────────────
tests:
  - input: 'aws_key = "AKIAIOSFODNN7EXAMPLE"'
    expect: match
    pattern: aws-access-key
  - input: 'key_ref = "${AWS_ACCESS_KEY_ID}"'
    expect: no_match
  - input: '# Example: AKIAIOSFODNN7EXAMPLE (docs)'
    expect: match                    # Bewuste keuze: ook in comments vinden
```

## Architectuur: Rule Engine v2

```
┌──────────────────────────────────────────────────────────────────────┐
│  cpm binary                                                          │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────┐    ┌──────────────┐    ┌───────────────────┐    │
│  │ Config Loader  │───▸│ Rule Filter  │───▸│ Engine Dispatch   │    │
│  │ (cpm.toml)     │    │ (enabled/    │    │ (pattern/absence/ │    │
│  │                │    │  disabled)   │    │  presence/metric) │    │
│  └────────────────┘    └──────────────┘    └────────┬──────────┘    │
│                                                      │              │
│  ┌────────────────┐                       ┌──────────▼──────────┐   │
│  │ Suppress Index │◂─────────────────────▸│ Scanner             │   │
│  │ (inline cmts)  │                       │ ├─ walk files       │   │
│  └────────────────┘                       │ ├─ apply rules      │   │
│                                            │ ├─ check suppress   │   │
│  ┌────────────────┐                       │ └─ emit findings    │   │
│  │ Fix Engine     │◂──────────────────────┤                     │   │
│  │ (regex-replace │                       └─────────────────────┘   │
│  │  + commands)   │                                                 │
│  └────────────────┘                                                 │
│                                                                      │
│  Output: terminal | JSONL | SARIF | markdown | AI-feedback           │
└──────────────────────────────────────────────────────────────────────┘
```

## cpm.toml v2 — Granulaire configuratie

```toml
[project]
name = "my-app"
version = "1.0.0"
lang = "typescript"
framework = "nextjs"         # Activeert framework-specifieke presets
preset = "strict"            # strict|standard|minimal

[rules]
# Globale instellingen
severity-minimum = "warning" # Negeer info-findings
autofix = false              # Globaal autofix aan/uit

# Per rule aan/uit/override
SEC-010 = true               # Aan (default)
SEC-011 = true
QUAL-011 = "warning"         # Override severity
QUAL-010 = false             # Uit
K8S-010 = true

# Per categorie
[rules.security]
enabled = true
severity = "error"           # Alle security rules minimaal error

[rules.quality]
enabled = true
severity = "warning"

[rules.style]
enabled = false              # Hele categorie uit (bijv. als je Biome gebruikt)

# Thresholds voor metric engine
[rules.QUAL-001]
max-lines = 250              # Override default 300
extensions = [".ts", ".tsx"] # Override target

[rules.QUAL-002]
min-comment-ratio = 15       # Project-specifiek

# External tool delegation
[rules.TOOL-001]
enabled = true
command = "yamllint -f parseable ."
skip-if-unavailable = true

# Exclude paths (globaal)
[scan]
exclude = [
  "vendor/",
  "node_modules/",
  "dist/",
  "generated/",
  ".next/",
  "coverage/",
]

# Suppress tracking
[suppress]
require-reason = true        # cpm:ignore MOET een reden hebben
audit-file = ".cpm/suppressions.jsonl"  # Track alle suppressies
```

## Stack Presets

Presets zijn gebundelde configuraties per stack. `cpm init --preset <naam>` genereert de juiste cpm.toml.

### Beschikbare presets:

| Preset | Activeert | Thresholds |
|--------|-----------|------------|
| `minimal` | Alleen security + secrets | Hoog (permissive) |
| `standard` | Security + quality + deps | Medium |
| `strict` | Alles aan, lage thresholds | Laag (streng) |
| `nextjs` | standard + Next.js specifiek | Next.js best practices |
| `react` | standard + React patterns | React hooks/a11y |
| `vue` | standard + Vue patterns | Vue reactivity |
| `angular` | standard + Angular patterns | Angular lifecycle |
| `nestjs` | standard + NestJS patterns | DI/DTO/guards |
| `django` | standard + Django security | OWASP Django |
| `spring` | standard + Java patterns | Spring Boot security |
| `laravel` | standard + PHP patterns | Laravel OWASP |
| `terraform` | standard + IaC hardening | CIS benchmarks |
| `k8s` | standard + K8s hardening | CIS K8s 5.x |
| `cpp` | standard + C++ patterns | Memory/perf |
| `monorepo` | standard + structure limits | Workspace rules |

### Preset definitie (TOML in rules/presets/):

```toml
# rules/presets/nextjs.toml
[meta]
name = "nextjs"
description = "Next.js 14-16 with App Router, React 19, TypeScript"
includes = ["standard"]  # Inherit from standard preset

[rules]
NEXT-001 = true   # No 'use client' without interactivity
NEXT-002 = true   # Server component by default
REACT-001 = true  # No forwardRef (React 19)
REACT-002 = true  # Proper Suspense boundaries
A11Y-001 = true   # Alt text on images
A11Y-002 = true   # Keyboard accessible
PERF-001 = true   # No barrel exports
PERF-002 = true   # Dynamic imports for heavy components
DEPS-001 = true   # No moment.js (use date-fns)
DEPS-002 = true   # No lodash (use native)

[rules.QUAL-001]
max-lines = 200   # Stricter for Next.js components
```

## Migratie-fases (Incrementeel, met kwaliteitsborging)

### Fase 0: Fundament (rule engine v2 features)

**Doel:** Engine geschikt maken voor productie-gebruik

| Feature | Implementatie | Effort |
|---------|--------------|--------|
| cpm:ignore inline suppress | Scan regel voor `cpm:ignore <id>`, skip finding | 1 avond |
| cpm.toml integratie | Lees [rules] sectie, filter rules enabled/disabled | 1 avond |
| Severity override | Per-rule severity uit config | Klein |
| Multi-line patterns | Sliding window of full-content regex | 1 avond |
| Absence engine | Match A + not-match B logic | 1 avond |
| Presence engine | File/path existence checks | Klein |
| Metric engine | Line count + threshold | 1 avond |
| Autofix (regex-replace) | Match → replace met confirm flag | 1 weekend |
| Test runner (`cpm rule test`) | Run tests: sectie per rule | 1 avond |
| Preset loader | Load preset TOML, merge met project config | 1 avond |

**Validatie:** eval-repo moet `make eval` op groen staan (engine >= shell)

### Fase 1: Security rules migreren (9 shell checks → ~25 .rule files)

**Bron:** checks/universal/security/
**Prioriteit:** Hoogst (zero false negatives vereist)

| Shell check | → Rule IDs | Engine |
|-------------|-----------|--------|
| check-secrets-fast.sh | SEC-010..SEC-019 (per secret type) | pattern |
| check-sast.sh | SEC-020..SEC-029 (semgrep wrapper) | external |
| check-pii.sh | SEC-030..SEC-039 (email, BSN, phone, etc.) | pattern |
| check-dangerous-shell.sh | SEC-040..SEC-049 (eval, rm -rf, etc.) | pattern |
| check-k8s-hardening.sh | SEC-050..SEC-059 (runAsNonRoot, etc.) | absence |
| check-regex-safety.sh | SEC-060..SEC-064 (ReDoS patterns) | pattern |
| check-zero-day-patterns.sh | SEC-070..SEC-079 (known vuln patterns) | pattern |
| check-gitignore.sh | SEC-080..SEC-084 (missing entries) | presence |
| check-sbom.sh | SEC-090 (SBOM generation) | external |

**Kwaliteitseis:** Elke rule moet passing tests hebben + eval-repo identieke findings produceren

### Fase 2: Quality rules (35 shell checks → ~80 .rule files)

| Shell check | → Rule IDs | Engine |
|-------------|-----------|--------|
| check-slop.sh | QUAL-020..QUAL-039 (AI slop markers) | pattern |
| check-clean-code.sh | QUAL-040..QUAL-055 (code smells) | pattern |
| check-file-size.sh | QUAL-001 (line count threshold) | metric |
| check-comment-ratio.sh | QUAL-002 (comment percentage) | metric |
| check-spaghetti-score.sh | QUAL-060..QUAL-069 (nesting, etc.) | metric |
| check-dora.sh | QUAL-070 (deployment frequency) | external |
| check-solid.sh | QUAL-080..QUAL-089 (SOLID violations) | pattern |
| check-ci-quality.sh | CI-001..CI-010 (pinning, timeout) | pattern+absence |
| ... | ... | ... |

### Fase 3: Framework-specifieke rules (~63 JS + 5 Python + 5 PHP + 1 Java)

Per framework een preset + bijbehorende rules:

| Framework | # Shell checks | → # Rules | Preset |
|-----------|---------------|-----------|--------|
| React/Next.js | 24 | ~60 | nextjs, react |
| Vue/Nuxt | 4 | ~15 | vue |
| Angular | 4 | ~12 | angular |
| NestJS | 3 | ~10 | nestjs |
| Express | 2 | ~8 | express |
| Django | 3 | ~12 | django |
| Laravel | 3 | ~10 | laravel |
| Java/Spring | 1 | ~8 | spring |
| Terraform | 4 | ~15 | terraform |

### Fase 4: Deps, Docs & Process rules

| Categorie | Shell checks | → Rules | Notes |
|-----------|-------------|---------|-------|
| Deps | 12 | ~20 | Lockfile, pinning, EOL, obsolete |
| Docs | 13 | ~15 | Comment ratio, dead docs, structure |
| Process | 5 | ~10 | Commit msg, hooks, changelog |
| Structure | 3 | ~8 | Max files/dir, folder naming |

### Fase 5: Autofix porten

| Fix script | → Rule fix: veld | Safe? |
|-----------|-----------------|-------|
| fix-safe.sh | PROJ-001..PROJ-010 (metadata) | ✅ |
| pin-deps.sh | DEPS-005 (remove ^/~) | ⚠️ |
| fix-mui-colors.sh | REACT-010 (theme tokens) | ⚠️ |
| nextjs-hardening.sh | NEXT-010 (security headers) | ✅ |
| fix-tanstack-config.sh | REACT-020 (query config) | ✅ |
| autofix.sh | Multiple | ✅ |

## Kwaliteitsborging per fase

Elke fase wordt pas "af" als:

```
1. ✅ Alle rules hebben tests: sectie met match + no_match cases
2. ✅ eval-repo (cpm-eval) toont >= findings dan shell checks
3. ✅ eval-repo timing toont >= 10x sneller dan shell
4. ✅ cpm:ignore werkt voor elke nieuwe rule
5. ✅ cpm.toml kan elke rule aan/uitzetten
6. ✅ docs: sectie bevat why + good_example + bad_example
7. ✅ Geen false negatives op security rules (handmatige review)
```

## Suppress mechanisme (volledig)

### Niveau 1: Inline (per regel code)

```typescript
const key = "AKIAIOSFODNN7EXAMPLE"; // cpm:ignore SEC-010 — test fixture
```

### Niveau 2: Bestandsniveau (bovenaan bestand)

```python
# cpm:ignore-file SEC-030 — PII detection test fixtures
```

### Niveau 3: Per rule in cpm.toml

```toml
[rules]
SEC-010 = false  # We gebruiken AWS Vault, geen hardcoded keys mogelijk
```

### Niveau 4: Per categorie in cpm.toml

```toml
[rules.style]
enabled = false  # Biome doet onze style checks al
```

### Niveau 5: Preset keuze

```toml
[project]
preset = "minimal"  # Alleen security, rest uit
```

### Audit trail

Alle suppressies worden gelogd:

```jsonl
{"rule":"SEC-010","file":"test/fixtures.ts","line":42,"reason":"test fixture","suppressed_at":"2026-07-22","by":"gius"}
```

## AI Feedback Output

Voor de "self-healing loop" met AI agents:

```bash
cpm check --format ai-feedback
```

Produceert:

```markdown
## CPM Findings (3 issues, 1 auto-fixable)

### ❌ SEC-010: Hardcoded AWS Access Key
- **File:** src/config.ts:4
- **Why:** Hardcoded credentials in git history are permanent and actively scanned by attackers
- **Fix:** Replace with `process.env.AWS_ACCESS_KEY_ID`
- **Auto-fix available:** No (requires manual verification of env var name)

### ⚠️ QUAL-011: Debug output left in code
- **File:** src/app.ts:7
- **Why:** console.log statements slow production and may leak sensitive data
- **Fix:** Remove or replace with structured logger
- **Auto-fix available:** Yes (`cpm fix --apply QUAL-011`)

### To suppress a finding:
- Inline: `// cpm:ignore QUAL-011 — intentional logging`
- Config: Set `QUAL-011 = false` in cpm.toml [rules]
```

## Tijdlijn

| Fase | Scope | Effort | Kwaliteits-gate |
|------|-------|--------|-----------------|
| 0 | Engine v2 features | 3 weekends | eval-repo groen, suppress werkt |
| 1 | Security (25 rules) | 2 weekends | Zero false negatives |
| 2 | Quality (80 rules) | 3 weekends | >= shell findings |
| 3 | Frameworks (130 rules) | 4 weekends | Per-preset eval |
| 4 | Deps/Docs/Process (53 rules) | 2 weekends | Full coverage |
| 5 | Autofix | 2 weekends | Before/after tests |
| **Totaal** | **~290 rules** | **~16 weekends** | **eval-repo gates** |

## Backwards compatibility

Tijdens migratie:
- Shell checks en rule engine draaien **naast elkaar**
- `cpm check` draait beide, deduplicates findings
- Per-check flag in cpm.toml: `migrated = true` schakelt shell versie uit
- Pas als eval-repo bewijst dat engine >= shell: shell versie deprecated

## Definition of Done

De migratie is compleet wanneer:
- [ ] 290+ rules in .rule formaat met volledige docs/tests/fix/suppress
- [ ] cpm-eval toont 0 regressies vs huidige shell checks
- [ ] Performance: volledige scan < 100ms (vs huidige 10-15s)
- [ ] 15+ presets voor populaire stacks
- [ ] `cpm init --preset <naam>` genereert werkende configuratie
- [ ] AI-feedback output werkt met Cursor/Aider/Claude Code
- [ ] Suppress audit trail werkt
- [ ] `cpm fix --apply` werkt voor alle safe fixes
