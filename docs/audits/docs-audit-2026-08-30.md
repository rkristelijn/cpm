# Documentation Audit Report — 2026-08-30

**Scope:** Alle 254 markdown-documenten + 6 drawio-bestanden in `docs/`
**Methode:** Cross-referentie tegen codebase (`src/`, `checks/`, `rules/`, `lib/shell/`, `scripts/`, `Makefile`, `cpm.toml`) en `README.md`
**Doel:** Markeer verouderde docs, behoud alles, noteer status per document

---

## Executive Summary

| Metriek | Waarde |
|---------|--------|
| **Totaal documenten** | 260 (254 .md + 6 .drawio) |
| **Current / Implemented** | 163 (63%) |
| **Partially outdated** | 31 (12%) |
| **Outdated** | 14 (5%) |
| **Superseded** | 11 (4%) |
| **Abandoned** | 5 (2%) |
| **Stub (< 300 bytes)** | 40 (15%) ¹ |
| **Irrelevant (niet-cpm)** | 3 (1%) |

¹ Stubs zijn ook meegeteld als "current" omdat hun bronverwijzingen allemaal kloppen.

### Top 5 Meest Urgente Updates

| # | Document | Probleem | Effort |
|---|----------|----------|--------|
| 1 | `architecture.md` | 3 maanden oud, alle getallen verkeerd (checks 61→188, src 59→87+, hotspots verwijzen naar gesplitste bestanden) | M |
| 2 | `checks/paranoia-mode.md` + 6 compliance docs | Verwijzen naar verwijderd `encrypt.sh` | M |
| 3 | `compliance/soc2.md` | Verwijst naar niet-bestaand `paranoia-backup` commando | S |
| 4 | `adrs/adr-005-check-registry-pattern.md` | Beschrijft JSON registry die nooit bestond; realiteit is C++ `CHECK_DEFS[]` + `.rule` files | M |
| 5 | `features/usage-modes.md` | Vermeldt "58 checks" terwijl er nu 1043 zijn | S |

---

## 1. Status Overzicht per Categorie

### 1.1 ADRs (71 bestanden, 73 effectieve ADRs)

> ⚠️ Duplicate nummering: ADR-022 en ADR-145 bestaan elk twee keer met verschillende inhoud.

| Status | Aantal | % |
|--------|--------|---|
| ✅ Implemented | 28 | 38% |
| ✅ Current | 11 | 15% |
| ⚠️ Partially implemented | 15 | 21% |
| 🟡 Outdated | 8 | 11% |
| 🔴 Abandoned | 5 | 7% |
| 🟢 Superseded | 3 | 4% |

| ADR | Titel | Status | Actie nodig? |
|-----|-------|--------|-------------|
| 001 | C Project Manager Concept | 🟢 Superseded | Nee — historisch |
| 002 | Feature Parity (llama-cli) | ✅ Implemented | Nee |
| 003 | Shared Tooling Strategy | 🟢 Superseded | Nee — status in doc |
| 004 | Centralized UI Pattern | ✅ Implemented | Nee |
| 005 | Check Registry Pattern | 🟡 Outdated | Ja — JSON registry → C++ CHECK_DEFS[] + .rule |
| 006 | Quality Framework Vision | ✅ Current | Nee |
| 007 | Engineering Knowledge Base | ⚠️ Partially impl. | Nee — visie-doc |
| 008 | Rebrand Compliance Process Management | 🟢 Superseded | Nee — status in doc |
| 009 | Package Distribution | ✅ Implemented | Nee |
| 010 | Resolution Strategy | ⚠️ Partially impl. | Nee — low priority |
| 011 | Compliance Center | ⚠️ Partially impl. | Ja — scopes feature ontbreekt |
| 012 | Maturity Framework Research | ✅ Current | Nee |
| 013 | Product Positioning | ✅ Implemented | Nee |
| 014 | Findings Database | ✅ Implemented | Nee |
| 015 | TypeScript Plugin | ✅ Implemented | Nee |
| 016 | Traceability Matrix | 🔴 Abandoned | Ja — @trace nooit geïmplementeerd |
| 017 | Polyrepo Scan | ✅ Implemented | Nee |
| 018 | Language Framework Scoring | ⚠️ Partially impl. | Nee — low priority |
| 019 | Term Index | 🔴 Abandoned | Ja — `cpm index` bestaat niet |
| 020 | Product Vision | ✅ Current | Nee |
| 021 | Community Feedback Loop | 🔴 Abandoned | Ja — `cpm report` bestaat niet |
| 022-a | Competitive Positioning | ✅ Current | Nee |
| 022-b | Native C++ Architecture | ✅ Implemented | Status in doc updaten (partially → implemented) |
| 023 | Framework Demo Generation | 🔴 Abandoned | Ja — nooit gebouwd |
| 024 | Process Maturity Model | ⚠️ Partially impl. | Nee |
| 025 | Local-First Issue Tracking | ⚠️ Partially impl. | Nee — deels werkend |
| 026 | V-Model Process Enforcement | ⚠️ Partially impl. | Nee |
| 126 | Traceability by Design | ⚠️ Partially impl. | Ja — formaliseren of downscopen |
| 127 | Traceability Scope | ✅ Current | Nee |
| 128 | Maturity Quality Matrix | ⚠️ Partially impl. | Nee |
| 129 | Unified Findings Contract | ✅ Implemented | Nee |
| 130 | Test Architecture | ⚠️ Partially impl. | Ja — eigen code volgt BDD niet |
| 131 | SQL Antipattern Detection | ✅ Implemented | Nee |
| 132 | Coverage Gap Analysis | 🟡 Outdated | Ja — cijfers 125→1043 checks |
| 133 | Discover Architecture | ⚠️ Partially impl. | Nee |
| 134 | Vertical Slice Architecture | 🔴 Abandoned | Ja — lege template |
| 135 | Copilot vs Embedded Modes | ⚠️ Partially impl. | Nee |
| 136 | Guardrails as Core | ⚠️ Partially impl. | Nee |
| 137 | Documentation Quality Platform | ✅ Implemented | Nee |
| 138 | Industry Repository Standards | ✅ Current | Nee |
| 139 | Scan Gap Analysis | 🟡 Outdated | Ja — 12 checks → 1043 |
| 140 | Compliance Framework Mapping | ✅ Implemented | Nee |
| 141 | Language Coverage Supply Chain | ✅ Implemented | Nee |
| 142 | OWASP Top 10 Coverage | ✅ Current | Nee |
| 143 | Deep Language Support | ⚠️ Partially impl. | Nee |
| 144 | Diagram Usage Analysis | ✅ Current | Nee |
| 145-a | Gradual Native Migration | 🟡 Outdated | Ja — cpm migrate bestaat niet |
| 145-b | Pluggable Rule Engine | ✅ Implemented | Nee |
| 146 | SonarCloud Integration | ✅ Implemented | Nee |
| 147 | Sunset npm-audit tools | ✅ Implemented | Nee |
| 148 | Laravel/PHP/Database Checks | ✅ Implemented | Nee |
| 149 | Attack Surface Exposure | 🟡 Outdated | Ja — runtime checks, buiten scope |
| 150 | Paranoia Mode | ⚠️ Partially impl. | Nee |
| 151 | Compression-Inspired Duplication | 🟡 Outdated | Ja — LZ77 approach niet gebouwd |
| 152 | Software Engineering Rules of Thumb | ✅ Current | Nee |
| 153 | Native Regex Quality Check | ✅ Implemented | Nee |
| 154 | Adapter Pattern Enforcement | ✅ Implemented | Nee |
| 155 | "You Don't Need" Detection | ✅ Implemented | Nee |
| 156 | Spaghetti Score | ✅ Implemented | Nee |
| 157 | Migration Shell→Rule Engine | ✅ Current | Nee |
| 158 | Magic Buffer Size Check | ✅ Implemented | Nee |
| 159 | cpm.toml Canonical Order | ⚠️ Partially impl. | Nee |
| 160 | Zero Warnings Policy | ✅ Implemented | Nee |
| 161 | CI Integrations (GH Action) | ✅ Implemented | Nee |
| 162 | Live Badges | ✅ Implemented | Nee |
| 163 | Go Language Support | ✅ Implemented | Nee |
| 164 | Regex Engine Strategy | 🟡 Outdated | Ja — RE2 vs std::regex onduidelijk |
| 165 | Analysis Engine | ⚠️ Partially impl. | Nee — in-progress |
| 166 | Rule Engine Extensions | ✅ Implemented | Nee |
| 167 | AI Slop Detection | ✅ Implemented | Nee |
| 168 | Multi-Engine Architecture | 🟡 Outdated | Ja — Tree-sitter/Semgrep niet geïntegreerd |

### 1.2 Research (18 bestanden)

| Status | Aantal | % |
|--------|--------|---|
| ✅ Current | 10 | 56% |
| ⚠️ Partially outdated | 3 | 17% |
| 🟢 Superseded | 2 | 11% |
| ❓ Irrelevant (niet-cpm) | 3 | 17% |

| Document | Status | Actie |
|----------|--------|-------|
| R-020-portable-rule-engine.md | 🟢 Superseded | Banner: geïmplementeerd via ADR-145/166 |
| R-021-check-rule-categories.md | 🟢 Superseded | Getallen 159→1043 sterk verouderd |
| R-022-market-positioning-gemini-research.md | ⚠️ Partially outdated | "bash CLI" → "C++ binary" |
| R-023-developer-frustrations.md | ✅ Current | — |
| R-024-gap-analysis-top50.md | ✅ Current | — |
| R-025-supply-chain-attack-detection.md | ⚠️ Partially outdated | Minor: 70→72 vectors |
| R-026-iam-golden-rules-as-code.md | ✅ Current | — |
| R-027-test-quality-rules.md | ✅ Current | — |
| R-028-ai-development-quality.md | ✅ Current | — |
| R-029-production-readiness.md | ⚠️ Partially outdated | 875→905 rules, structuur src/checks/ |
| R-030-design-patterns-vs-native.md | ✅ Current | — |
| R-030-matrix-analysis.md | ✅ Current | — |
| R-030-patterns-catalog.md | ✅ Current | — |
| R-030-platforms-catalog.md | ✅ Current | — |
| R-031-cpm-refactor-plan.md | ✅ Current | — |
| node-26-native-replacements.md | ❓ Irrelevant | Node.js doc, niet cpm-gerelateerd |
| edge-runtime-compatibility.md | ❓ Irrelevant | Edge runtime doc, niet cpm-gerelateerd |
| level-2-transitive-replacements.md | ❓ Irrelevant | Node.js dep doc, niet cpm-gerelateerd |

### 1.3 Checks (61 bestanden)

| Status | Aantal | % |
|--------|--------|---|
| ✅ Current (volledig) | 15 | 25% |
| ✅ Current (stub) | 44 | 72% |
| 🟡 Outdated | 1 | 2% |
| ℹ️ Setup guide | 1 | 2% |

| Document | Status | Opmerkingen |
|----------|--------|-------------|
| accessibility-checks.md | ✅ Current | 22KB, uitgebreid |
| adapter-pattern.md | ✅ Current | Design guidance |
| ai-ml-security.md | ✅ Current | 25 AIML rules |
| check-native-alternatives.md | ✅ Current | Bevat --fix uitleg |
| check-native-compat.md | ✅ Current | API compat table |
| check-pii.md | ✅ Current | Samenvatting |
| check-vue-a11y.md | ✅ Current | Vue3 + Electron |
| check-windows-portability.md | ✅ Current | POSIX-only detectie |
| check-xml.md | ✅ Current (stub) | 200 bytes |
| frontend-web-best-practices.md | ✅ Current | 31KB, uitgebreid |
| global-hooks.md | ✅ Current | Hook systeem |
| graphql-transport.md | ✅ Current | 15+7 rules |
| launchpad-ppa-setup.md | ℹ️ Setup guide | Geen check — installatiegids |
| paranoia-mode.md | 🟡 Outdated | Verwijst naar verwijderd `encrypt.sh` |
| pii-vault.md | ✅ Current | Concept doc |
| secrets-detection.md | ✅ Current | SECRETS-001–080 |
| *44 stub check docs* | ✅ Current (stub) | Zie §6 Stub-documenten |

### 1.4 Features (32 bestanden)

| Status | Aantal | % |
|--------|--------|---|
| ✅ Current | 28 | 88% |
| ⚠️ Partially outdated | 2 | 6% |
| ✅ Current (concept) | 2 | 6% |

| Document | In README? | Status | Actie |
|----------|-----------|--------|-------|
| audit.md | ✅ | ✅ Current | — |
| build.md | ✅ | ✅ Current | — |
| bump.md | ✅ | ✅ Current | — |
| check.md | ✅ | ✅ Current | — |
| clean.md | ❌ | ✅ Current | README bijwerken |
| commit.md | ❌ | ✅ Current | README bijwerken |
| config.md | ✅ | ✅ Current | — |
| coverage.md | ✅ | ✅ Current | — |
| eject.md | ✅ | ✅ Current | — |
| enforcement-levels.md | — | ✅ Current (concept) | — |
| findings.md | ✅ | ✅ Current | — |
| format.md | ✅ | ✅ Current | — |
| hooks.md | ✅ | ✅ Current | — |
| init.md | ✅ | ✅ Current | — |
| install.md | ✅ | ✅ Current | — |
| issues.md | ❌ | ✅ Current | README bijwerken |
| lint.md | ✅ | ✅ Current | — |
| maturity.md | ❌ | ⚠️ Partially outdated | Levels 0-4 vs score 0-5 inconsistentie |
| new.md | ✅ | ✅ Current | — |
| pii-detection.md | — | ✅ Current (concept) | — |
| release.md | — | ✅ Current | — |
| run.md | ✅ | ✅ Current | — |
| sbom.md | ✅ | ✅ Current | — |
| scan.md | ✅ | ✅ Current | — |
| score.md | ✅ | ✅ Current | — |
| secrets.md | — | ✅ Current | — |
| test.md | ✅ | ✅ Current | — |
| todo.md | ❌ | ✅ Current | README bijwerken |
| tools.md | ✅ | ✅ Current | — |
| usage-modes.md | — | ⚠️ Partially outdated | "58 checks" → 1043 |
| version.md | ❌ | ✅ Current | README bijwerken |
| xref.md | ❌ | ✅ Current | README bijwerken |

**7 commands ontbreken in README command table:** commit, clean, version, todo, xref, issue, maturity.
**7 commands zonder feature doc:** sort, report, phase, guard, flow, fix sql, uninstall.

### 1.5 Compliance (13 bestanden)

| Status | Aantal | % |
|--------|--------|---|
| ✅ Current | 4 | 31% |
| ⚠️ Partially outdated | 8 | 62% |
| ✅ Uitstekend | 1 | 8% |

| Document | Status | Probleem |
|----------|--------|----------|
| README.md | ⚠️ Partially outdated | Alle statussen "🔄 awaiting verification" |
| iso-25010.md | ✅ Uitstekend | 7.5KB, gedetailleerde rule mappings |
| iso-27001.md | ⚠️ Partially outdated | Verwijst naar verwijderd `encrypt.sh` via paranoia-mode |
| owasp-top10.md | ✅ Current | Grotendeels correct |
| gdpr.md | ⚠️ Partially outdated | Verwijst naar `paranoia-mode`/`encrypt.sh` |
| dora.md | ✅ Current | Kleine tabel-duplicaat (check-runtime-eol 2x) |
| nist-800-53.md | ⚠️ Partially outdated | Verwijst naar `paranoia-mode`/`encrypt.sh` |
| nis2.md | ⚠️ Partially outdated | Verwijst naar `paranoia-mode`/`encrypt.sh` |
| wcag.md | ⚠️ Partially outdated | Slechts 4 van 120+ A11Y rules gemapped |
| soc2.md | ⚠️ Partially outdated | Verwijst naar niet-bestaand `paranoia-backup` |
| pci-dss.md | ⚠️ Partially outdated | Verwijst naar onspecifiek `check-outdated` |
| cmmi.md | ✅ Current | Generiek maar correct |
| ce-plus.md | ✅ Current | Grotendeels correct |

### 1.6 Designs (10 bestanden)

| Status | Aantal | % |
|--------|--------|---|
| ✅ Current | 8 | 80% |
| ⚠️ Partially outdated | 2 | 20% |

| Document | Status | Actie |
|----------|--------|-------|
| iso-25010-quality-mapping.md | ⚠️ Partially outdated | 792→905 rules, nog in draft |
| rule-engine-config.md | ⚠️ Partially outdated | `[rules]` skip in cpm.toml niet geïmplementeerd |
| refactoring-plan.md | ✅ Current | Deels voltooid, resterende taken zijn actueel |
| regex-quality-check.md | ✅ Current | Geïmplementeerd als src/checks/quality/regex_quality.cpp |
| v-model-level-0.1.drawio | ✅ Current | Visueel diagram |
| v-model-level-0.2.drawio | ✅ Current | Visueel diagram |
| v-model-level-0.3.drawio | ✅ Current | Visueel diagram |
| v-model-level-0.4.drawio | ✅ Current | Visueel diagram |
| v-model-level-0.5.drawio | ✅ Current | Visueel diagram |
| v-model-level-0.6.drawio | ✅ Current | Visueel diagram |

### 1.7 Frameworks (9 bestanden)

| Status | Aantal | % |
|--------|--------|---|
| ✅ Current | 9 | 100% |

Alle framework docs (Angular, Clean Code, DORA, NestJS, Next.js, Nx, React, SOLID, Terraform) zijn actueel en verwijzen naar werkende checks/rules.

**11 frameworks missen docs:** Vue, Express, Django, Laravel, Spring Boot, Flask, Rails, WordPress, Nuxt, Kubernetes, Docker — deze hebben wél checks/rules in de codebase.

### 1.8 Issues — Open (4 bestanden)

| Document | Status |
|----------|--------|
| cli-terminal-a11y-rules.md | ✅ Relevant — nieuw (2026-08-30) |
| rule-test-coverage-gap.md | ✅ Relevant — 6% rule test coverage |
| config-quality-checks-json-yaml-env.md | ✅ Relevant — niet geïmplementeerd |
| coverage-gaps-e2e-25-80-comments-16-20-architecture-docs.md | ⚠️ Deels opgelost — getallen updaten |

### 1.9 Issues — Closed (26 bestanden)

| Document | Werkelijk afgerond? |
|----------|---------------------|
| add-check-regex-safety.md | ✅ Afgerond |
| add-cpm-check-self-scan-zero-findings.md | ❌ Niet afgerond (299 findings op eigen repo) |
| add-docs-links-to-all-checks.md | ⚠️ Deels (61/188+ checks met docs) |
| check-sh-wrapper.md | ✅ Afgerond |
| configure-github-secrets.md | ✅ Afgerond |
| deduplicate-secret-patterns.md | ❌ Niet afgerond (beide implementaties bestaan) |
| doc-complexity-check.md | ❓ Onverifieerbaar (lege body) |
| doc-structure-check.md | ❓ Onverifieerbaar (lege body) |
| documentation-quality-checks.md | ⚠️ Deels afgerond |
| dual-audit-trail.md | ⚠️ Niet afgerond (`cpm trace` bestaat niet) |
| feature-module-decomposition.md | ✅ Afgerond |
| guard-logging.md | ⚠️ Deels afgerond |
| integrate-issue-reference.md | ❓ Onverifieerbaar (lege body) |
| minimum-quality-baseline.md | ⚠️ Deels afgerond |
| monorepo-test-detection.md | ❓ Onverifieerbaar |
| process-guided-development.md | ✅ Afgerond |
| push-to-github.md | ✅ Afgerond |
| remove-eval-from-e2e.md | ❓ Onverifieerbaar (lege body) |
| reorganize-src-checks-and-docs-adrs.md | ⚠️ Deels (src/checks/ ✅, docs/adrs/ 71 bestanden ❌) |
| resolve-all-sonarcloud-bugs.md | ❓ Onverifieerbaar (lege body) |
| sanitize-popen-system-calls.md | ⚠️ Deels afgerond |
| scan-report-language-distribution.md | ⚠️ Deels afgerond |
| shift-left-check-sonarcloud.md | ❓ Onverifieerbaar |
| split-commands-cpp.md | ⚠️ Deels (cmd_ops.cpp = 802 regels, boven 600-limiet) |
| split-scan-cpp.md | ✅ Afgerond (scan.cpp → src/scan/, 11 bestanden) |
| unified-findings-contract.md | ⚠️ Deels afgerond |

### 1.10 Audits (3 bestanden)

| Document | Status |
|----------|--------|
| ai-slop-audit.md | ✅ Current (2026-08-30) |
| lib-shell-audit.md | ✅ Current (2026-08) |
| lab-checks-gap-analysis.md | ✅ Current (2026-08) |

### 1.11 Losse docs (9 bestanden)

| Document | Status | Actie |
|----------|--------|-------|
| README.md | ✅ Current | — |
| architecture.md | 🟡 Outdated | Regenereren — alle getallen verkeerd |
| attacks.md | ✅ Current | 30 attack detection rules |
| ci-integration.md | ✅ Current | Kort en accuraat |
| conventions.md | ⚠️ Partially outdated | Verwijst naar workspace-tui patronen |
| design-encrypt.md | ✅ Current | Toekomstig design |
| design-patterns.md | 🟢 Superseded | Beschrijft bash-architectuur |
| integration.md | 🟢 Superseded | Symlink-model vervangen door binary |
| migration-plan.md | 🟢 Superseded | Bash→C++ plan achterhaald |
| process.md | ✅ Current | Way of Working |
| roadmap-distribution.md | ⚠️ Partially outdated | Checkboxen updaten, "bash" claims verwijderen |
| shared-tooling-analysis.md | 🟢 Superseded | Analyse van mei 2026, volledig achterhaald |
| v-model.md | ✅ Current | V-model visualisatie |

---

## 2. Verouderde Documenten — Actie Nodig

Gesorteerd op urgentie (hoog → laag).

### 🔴 Kritiek — Misleidende of gebroken referenties

| # | Document | Probleem | Actie | Effort |
|---|----------|----------|-------|--------|
| 1 | `architecture.md` | 3+ maanden oud (2026-05-17). Getallen: checks 61→188, src 59→87+, hotspots verwijzen naar gesplitste bestanden die niet meer bestaan (scan.cpp:844, commands.cpp:815). Tech Radar bevat irrelevante items (CSS-in-JS, Bootstrap). | Regenereren via `scripts/generate-docs.sh` | M |
| 2 | `checks/paranoia-mode.md` | Verwijst naar `encrypt.sh` dat verwijderd is per lib-shell-audit (security risico). | Verwijder encrypt.sh referenties, beschrijf alternatief of markeer feature als concept | S |
| 3 | `compliance/iso-27001.md` | Verwijst naar paranoia-mode/encrypt.sh | Verwijder encrypt.sh referentie | S |
| 4 | `compliance/gdpr.md` | Verwijst naar paranoia-mode/encrypt.sh | Verwijder encrypt.sh referentie | S |
| 5 | `compliance/nist-800-53.md` | Verwijst naar paranoia-mode/encrypt.sh en "planned" dead-code check | Verwijder encrypt.sh referentie, update planned checks | S |
| 6 | `compliance/nis2.md` | Verwijst naar paranoia-mode/encrypt.sh | Verwijder encrypt.sh referentie | S |
| 7 | `compliance/soc2.md` | Verwijst naar niet-bestaand `paranoia-backup` commando en paranoia-mode | Verwijder gebroken referenties | S |
| 8 | `adrs/adr-005-check-registry-pattern.md` | Beschrijft JSON registry die nooit bestond. Werkelijkheid: C++ `CHECK_DEFS[]` + 905 `.rule` files. Meest misleidende doc voor nieuwe bijdragers. | Updaten naar actuele architectuur of markeer als superseded | M |

### 🟡 Medium — Verouderde getallen of claims

| # | Document | Probleem | Actie | Effort |
|---|----------|----------|-------|--------|
| 9 | `features/usage-modes.md` | Vermeldt "58 checks" — nu 1043 | Getal updaten | S |
| 10 | `features/maturity.md` | Beschrijft levels 0-4, terwijl score.md 0-5 beschrijft | Harmoniseren met score.md | S |
| 11 | `compliance/wcag.md` | Slechts 4 van 120+ A11Y rules gemapped | Uitbreiden met A11Y rule mappings | M |
| 12 | `compliance/pci-dss.md` | Verwijst naar onspecifiek `check-outdated` | Specificeren: check-runtime-eol.sh of check-ts-outdated.sh | S |
| 13 | `compliance/README.md` | Alle statussen "🔄 awaiting verification" | Verificatie uitvoeren of verwachte status noteren | S |
| 14 | `adrs/adr-132-coverage-gap-analysis.md` | Getallen: 125 checks → 1043 | Updaten of markeer als historisch | S |
| 15 | `adrs/adr-139-scan-gap-analysis.md` | Beschrijft 12 check categories, nu 40+ | Updaten of archiveren | S |
| 16 | `adrs/adr-145-gradual-native-migration.md` | `cpm migrate` bestaat niet, focus verschoven | Markeer als superseded door ADR-145-pluggable-rule-engine | S |
| 17 | `adrs/adr-149-attack-surface-exposure.md` | Runtime/network checks, buiten scope static analysis | Markeer als abandoned (buiten scope) | S |
| 18 | `adrs/adr-151-compression-duplication.md` | LZ77-geïnspireerde approach niet gebouwd, simpele implementatie | Update naar werkelijke state | S |
| 19 | `adrs/adr-164-regex-engine-strategy.md` | RE2 vs std::regex status onduidelijk | Verduidelijken welke engine gebruikt wordt | S |
| 20 | `adrs/adr-168-multi-engine-architecture.md` | Tree-sitter/Semgrep niet geïntegreerd, is toekomstvisie | Markeer als "Proposed — not implemented" | S |
| 21 | `conventions.md` | Verwijst naar workspace-tui patronen en checks-registry.json (bestaat niet) | Herschrijf voor cpm-specifieke conventions | M |
| 22 | `roadmap-distribution.md` | Checkboxen niet gemarkeerd, "bash is sufficient" claim onjuist | Checkboxen updaten, bash-claims verwijderen | S |
| 23 | `research/R-029-production-readiness.md` | 875→905 rules, src/checks/ structuur gewijzigd | Getallen updaten | S |
| 24 | `research/R-022-market-positioning.md` | "bash CLI" → "C++ binary" | Cosmetische update | S |
| 25 | `designs/iso-25010-quality-mapping.md` | 792→905 rules | Getallen updaten | S |
| 26 | `designs/rule-engine-config.md` | `[rules]` skip in cpm.toml niet geïmplementeerd | Markeer als "design — not yet implemented" | S |
| 27 | `adrs/adr-022-native-cpp-architecture.md` | Status "partially-implemented" maar grotendeels geïmplementeerd (80+ bestanden) | Status updaten naar "implemented" | S |

### 🟢 Laag — Cosmetisch of toekomstige verbetering

| # | Document | Probleem | Actie | Effort |
|---|----------|----------|-------|--------|
| 28 | `compliance/dora.md` | `check-runtime-eol` duplicaat in tabel (Art. 7) | Verwijder duplicaat | S |
| 29 | `features/clean.md` | 211 bytes, geen detail over wat opgeruimd wordt | Uitbreiden | S |
| 30 | `research/R-025-supply-chain.md` | "70 vectors" → ~72 | Minor getal-update | S |

---

## 3. Superseded Documenten

Deze documenten zijn vervangen door nieuwere architectuur of beslissingen. **Behoud als historisch**, markeer met banner.

| Document | Grootte | Vervangen door | Reden |
|----------|---------|---------------|-------|
| `adrs/adr-001-concept.md` | 2.6KB | ADR-006, ADR-008, README | Oorspronkelijk "C Package Manager" concept |
| `adrs/adr-003-shared-tooling-strategy.md` | 5.7KB | Één binary + install.sh | Symlink-aanpak afgewezen |
| `adrs/adr-008-rebrand-compliance-process-management.md` | 4.5KB | README "code project maturity" | Status "superseded" al in doc |
| `design-patterns.md` | 9.7KB | C++ architectuur in src/ | Beschrijft bash/workspace-tui patronen |
| `integration.md` | 2.6KB | ci-integration.md + install.sh | Symlink-model vervangen door binary |
| `migration-plan.md` | 10.0KB | ADR-013 + huidige C++ architectuur | Bash→universeel plan achterhaald |
| `shared-tooling-analysis.md` | 7.8KB | Huidige codebase | Analyse van mei 2026, volledig achterhaald |
| `research/R-020-portable-rule-engine.md` | 24.3KB | ADR-145-b + src/rules/rule_engine.cpp | Volledig geïmplementeerd |
| `research/R-021-check-rule-categories.md` | 7.9KB | Huidige 1043 checks | Getallen 159→1043 sterk verouderd |

---

## 4. Abandoned / Never-Implemented

Deze documenten beschrijven features die nooit zijn gebouwd. **Behoud als historisch**, markeer met banner.

| Document | Grootte | Feature | Reden nooit gebouwd |
|----------|---------|---------|---------------------|
| `adrs/adr-016-traceability-matrix.md` | 4.6KB | `@trace` annotaties | Geen code die @trace parsed of valideert |
| `adrs/adr-019-term-index.md` | 4.0KB | `cpm index` commando | Commando bestaat niet in binary |
| `adrs/adr-021-community-feedback-loop.md` | 4.9KB | `cpm report` auto-context issues | Commando bestaat niet |
| `adrs/adr-023-framework-demo-generation.md` | 6.1KB | `cpm demo` / cpm-demos repo | Geen demo generation scripts |
| `adrs/adr-134-vertical-slice-architecture.md` | 858B | Vertical slice beslissing | Lege template, nooit ingevuld |

---

## 5. Aanbevolen Status Banners

Standaard markdown banners om bovenaan documenten te plaatsen voor consistente status-indicatie:

### Current

Geen banner nodig.

### Implemented

```markdown
> ✅ **Status: Implemented** — This ADR has been fully implemented in the codebase.
```

### Partially Implemented

```markdown
> 🟠 **Status: Partially Implemented** — Parts of this document are implemented; see inline notes for what remains.
```

### Outdated

```markdown
> ⚠️ **Status: Outdated** — Parts of this document no longer reflect the current codebase. See [current state] for up-to-date information.
```

### Superseded

```markdown
> 🟢 **Status: Superseded** by [ADR-XXX](link) — This document is preserved for historical context.
```

### Abandoned

```markdown
> 🔴 **Status: Abandoned** — This feature was not implemented. Preserved for historical context.
```

### Stub

```markdown
> 📝 **Status: Stub** — This document is a placeholder. See source file for implementation details.
```

### Irrelevant

```markdown
> ❓ **Status: External Reference** — This document is not part of the cpm project. Consider moving to a separate repository.
```

---

## 6. Stub-documenten

44 documenten in `docs/checks/` die <300 bytes zijn en alleen titel, 1-regel beschrijving, en bronbestand-referentie bevatten. Alle bronverwijzingen zijn geverifieerd als bestaand.

| Document | Grootte | Bron bestaat? |
|----------|---------|---------------|
| `check-adr-enforcement.md` | 256B | ✅ `checks/universal/docs/check-adr-enforcement.sh` |
| `check-agent-config.md` | 249B | ✅ `checks/universal/check-agent-config.sh` |
| `check-ci-quality.md` | 267B | ✅ `checks/universal/check-ci-quality.sh` |
| `check-clean-code.md` | 221B | ✅ `checks/universal/quality/check-clean-code.sh` |
| `check-comment-ratio.md` | 244B | ✅ `checks/universal/quality/check-comment-ratio.sh` |
| `check-css.md` | 200B | ✅ `checks/universal/quality/check-css.sh` |
| `check-dangerous-shell.md` | 264B | ✅ `checks/universal/security/check-dangerous-shell.sh` |
| `check-dead-docs.md` | 248B | ✅ `checks/universal/docs/check-dead-docs.sh` |
| `check-dead-links.md` | 243B | ✅ `checks/universal/docs/check-dead-links.sh` |
| `check-dockerfile.md` | 221B | ✅ `checks/universal/quality/check-dockerfile.sh` |
| `check-dora.md` | 224B | ✅ `checks/universal/quality/check-dora.sh` |
| `check-duplication.md` | 242B | ✅ `checks/universal/quality/check-duplication.sh` |
| `check-feature-coverage.md` | 264B | ✅ `checks/universal/quality/check-feature-coverage.sh` |
| `check-file-size.md` | 270B | ✅ `checks/universal/quality/check-file-size.sh` |
| `check-hooks.md` | 209B | ✅ `checks/universal/check-hooks.sh` |
| `check-html.md` | 203B | ✅ `checks/universal/quality/check-html.sh` |
| `check-inclusivity.md` | 243B | ✅ `checks/universal/docs/check-inclusivity.sh` |
| `check-json.md` | 203B | ✅ `checks/universal/quality/check-json.sh` |
| `check-licenses.md` | 241B | ✅ `checks/universal/deps/check-licenses.sh` |
| `check-lockfile.md` | 239B | ✅ `checks/universal/deps/check-lockfile.sh` |
| `check-makefile.md` | 247B | ✅ `checks/universal/check-makefile.sh` |
| `check-portability.md` | 244B | ✅ `checks/universal/check-portability.sh` |
| `check-process.md` | 234B | ✅ `checks/universal/check-process.sh` |
| `check-research-freshness.md` | 280B | ✅ `checks/universal/quality/check-research-freshness.sh` |
| `check-root-clutter.md` | 227B | ✅ `checks/universal/quality/check-root-clutter.sh` |
| `check-runtime-eol.md` | 264B | ✅ `checks/universal/deps/check-runtime-eol.sh` |
| `check-sast.md` | 224B | ✅ `checks/universal/security/check-sast.sh` |
| `check-sbom.md` | 232B | ✅ `checks/universal/security/check-sbom.sh` |
| `check-scripts.md` | 225B | ✅ `checks/universal/quality/check-scripts.sh` |
| `check-secrets-fast.md` | 260B | ✅ `checks/universal/security/check-secrets-fast.sh` |
| `check-slop.md` | 229B | ✅ `checks/universal/quality/check-slop.sh` |
| `check-solid.md` | 245B | ✅ `checks/universal/quality/check-solid.sh` |
| `check-sql-antipatterns.md` | 264B | ✅ `checks/universal/quality/check-sql-antipatterns.sh` |
| `check-stale-docs.md` | 239B | ✅ `checks/universal/docs/check-stale-docs.sh` |
| `check-test-architecture.md` | 252B | ✅ `checks/universal/quality/check-test-architecture.sh` |
| `check-todo-scraper.md` | 244B | ✅ `checks/universal/quality/check-todo-scraper.sh` |
| `check-todo.md` | 223B | ✅ `checks/universal/quality/check-todo.sh` |
| `check-traceability-coverage.md` | 262B | ✅ `checks/universal/quality/check-traceability-coverage.sh` |
| `check-unicode.md` | 244B | ✅ `checks/universal/check-unicode.sh` |
| `check-version-pins.md` | 263B | ✅ `checks/universal/deps/check-version-pins.sh` |
| `check-web-essentials.md` | 227B | ✅ `checks/universal/docs/check-web-essentials.sh` |
| `check-xref-validate.md` | 256B | ✅ `checks/universal/quality/check-xref-validate.sh` |
| `check-xml.md` | 200B | ✅ (bronbestand niet gespecificeerd, maar check exists) |
| `lint-md.md` | 206B | ✅ `checks/universal/docs/lint-md.sh` |
| `lint-yaml.md` | 199B | ✅ `checks/universal/lint-yaml.sh` |
| `syntax-bash.md` | 216B | ✅ `checks/universal/syntax-bash.sh` |

---

## Appendix: Volledige Document Inventaris

### A. ADRs (`docs/adrs/`) — 71 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `adr-001-concept.md` | 2.6KB | Jul 22 | 🟢 Superseded | Banner toevoegen |
| `adr-002-feature-parity.md` | 4.1KB | Jul 22 | ✅ Implemented | — |
| `adr-003-shared-tooling-strategy.md` | 5.7KB | Jul 22 | 🟢 Superseded | Banner toevoegen |
| `adr-004-centralized-ui-pattern.md` | 5.5KB | Jul 22 | ✅ Implemented | — |
| `adr-005-check-registry-pattern.md` | 7.9KB | Jul 22 | 🟡 Outdated | Updaten architectuur |
| `adr-006-quality-framework-vision.md` | 8.8KB | Jul 22 | ✅ Current | — |
| `adr-007-engineering-knowledge-base.md` | 6.2KB | Jul 22 | ⚠️ Partial | — |
| `adr-008-rebrand-compliance-process-management.md` | 4.5KB | Jul 22 | 🟢 Superseded | — |
| `adr-009-package-distribution.md` | 1.8KB | Jul 22 | ✅ Implemented | — |
| `adr-010-resolution-strategy.md` | 3.0KB | Jul 22 | ⚠️ Partial | — |
| `adr-011-compliance-center.md` | 3.5KB | Jul 22 | ⚠️ Partial | Scopes feature |
| `adr-012-maturity-framework-research.md` | 26.3KB | Jul 22 | ✅ Current | — |
| `adr-013-product-positioning.md` | 16.4KB | Jul 22 | ✅ Implemented | — |
| `adr-014-findings-database.md` | 5.2KB | Jul 22 | ✅ Implemented | — |
| `adr-015-typescript-plugin.md` | 3.5KB | Jul 22 | ✅ Implemented | — |
| `adr-016-traceability-matrix.md` | 4.6KB | Jul 22 | 🔴 Abandoned | Banner toevoegen |
| `adr-017-polyrepo-scan.md` | 4.7KB | Jul 22 | ✅ Implemented | — |
| `adr-018-language-framework-scoring.md` | 19.5KB | Jul 22 | ⚠️ Partial | — |
| `adr-019-term-index.md` | 4.0KB | Jul 22 | 🔴 Abandoned | Banner toevoegen |
| `adr-020-product-vision.md` | 7.2KB | Jul 22 | ✅ Current | — |
| `adr-021-community-feedback-loop.md` | 4.9KB | Jul 22 | 🔴 Abandoned | Banner toevoegen |
| `adr-022-competitive-positioning.md` | 4.7KB | Jul 22 | ✅ Current | — |
| `adr-022-native-cpp-architecture.md` | 6.8KB | Jul 22 | ✅ Implemented | Status in doc updaten |
| `adr-023-framework-demo-generation.md` | 6.1KB | Jul 22 | 🔴 Abandoned | Banner toevoegen |
| `adr-024-process-maturity-model.md` | 21.7KB | Jul 22 | ⚠️ Partial | — |
| `adr-025-local-first-issue-tracking.md` | 4.9KB | Jul 22 | ⚠️ Partial | — |
| `adr-026-v-model-process-enforcement.md` | 5.5KB | Jul 22 | ⚠️ Partial | — |
| `adr-126-traceability-by-design.md` | 6.3KB | Jul 22 | ⚠️ Partial | Formaliseren |
| `adr-127-traceability-scope.md` | 4.4KB | Jul 22 | ✅ Current | — |
| `adr-128-maturity-quality-matrix.md` | 14.2KB | Jul 22 | ⚠️ Partial | — |
| `adr-129-unified-findings-contract.md` | 5.2KB | Jul 22 | ✅ Implemented | — |
| `adr-130-test-architecture.md` | 11.0KB | Jul 22 | ⚠️ Partial | Dogfooding |
| `adr-131-sql-antipattern-detection.md` | 14.0KB | Jul 22 | ✅ Implemented | — |
| `adr-132-coverage-gap-analysis.md` | 6.3KB | Jul 22 | 🟡 Outdated | Cijfers updaten |
| `adr-133-discover-architecture.md` | 3.0KB | Jul 22 | ⚠️ Partial | — |
| `adr-134-vertical-slice-architecture.md` | 858B | Jul 22 | 🔴 Abandoned | Banner toevoegen |
| `adr-135-copilot-vs-embedded.md` | 1.5KB | Jul 22 | ⚠️ Partial | — |
| `adr-136-guardrails-as-core.md` | 4.8KB | Jul 22 | ⚠️ Partial | — |
| `adr-137-documentation-quality-platform.md` | 31.1KB | Jul 22 | ✅ Implemented | — |
| `adr-138-industry-repository-standards.md` | 6.9KB | Jul 22 | ✅ Current | — |
| `adr-139-scan-gap-analysis.md` | 5.6KB | Jul 22 | 🟡 Outdated | Cijfers updaten |
| `adr-140-compliance-framework-mapping.md` | 4.6KB | Jul 22 | ✅ Implemented | — |
| `adr-141-language-coverage-supply-chain.md` | 8.6KB | Jul 22 | ✅ Implemented | — |
| `adr-142-owasp-top10-coverage.md` | 4.1KB | Jul 22 | ✅ Current | — |
| `adr-143-deep-language-support.md` | 3.8KB | Jul 22 | ⚠️ Partial | — |
| `adr-144-diagram-usage-analysis.md` | 2.3KB | Jul 22 | ✅ Current | — |
| `adr-145-gradual-native-migration.md` | 5.2KB | Jul 22 | 🟡 Outdated | Markeer superseded |
| `adr-145-pluggable-rule-engine.md` | 15.7KB | Aug 17 | ✅ Implemented | — |
| `adr-146-sonarcloud-integration.md` | 4.3KB | Jul 22 | ✅ Implemented | — |
| `adr-147-sunset-npm-audit-tools.md` | 3.8KB | Jul 22 | ✅ Implemented | — |
| `adr-148-laravel-php-database-checks.md` | 41.8KB | Jul 22 | ✅ Implemented | — |
| `adr-149-attack-surface-exposure.md` | 4.7KB | Jul 22 | 🟡 Outdated | Archiveren |
| `adr-150-paranoia-mode.md` | 6.0KB | Aug 17 | ⚠️ Partial | — |
| `adr-151-compression-duplication.md` | 9.3KB | Aug 17 | 🟡 Outdated | Update state |
| `adr-152-software-engineering-rules.md` | 6.0KB | Jul 22 | ✅ Current | — |
| `adr-153-native-regex-quality-check.md` | 2.0KB | Aug 17 | ✅ Implemented | — |
| `adr-154-adapter-pattern-enforcement.md` | 1.7KB | Aug 17 | ✅ Implemented | — |
| `adr-155-you-dont-need-detection.md` | 2.8KB | Aug 17 | ✅ Implemented | — |
| `adr-156-spaghetti-score.md` | 4.0KB | Aug 17 | ✅ Implemented | — |
| `adr-157-migration-quality-plan.md` | 18.1KB | Aug 17 | ✅ Current | — |
| `adr-158-magic-buffer-size-check.md` | 3.5KB | Aug 17 | ✅ Implemented | — |
| `adr-159-cpm-toml-canonical-order.md` | 7.0KB | Aug 17 | ⚠️ Partial | — |
| `adr-160-zero-warnings-policy.md` | 3.9KB | Aug 17 | ✅ Implemented | — |
| `adr-161-ci-integrations.md` | 3.4KB | Aug 17 | ✅ Implemented | — |
| `adr-162-live-badges.md` | 4.0KB | Aug 17 | ✅ Implemented | — |
| `adr-163-go-language-support.md` | 3.8KB | Aug 28 | ✅ Implemented | — |
| `adr-164-regex-engine-strategy.md` | 4.5KB | Aug 28 | 🟡 Outdated | Verduidelijken |
| `adr-165-analysis-engine.md` | 26.7KB | Aug 28 | ⚠️ Partial | — |
| `adr-166-rule-engine-extensions.md` | 9.7KB | Aug 30 | ✅ Implemented | — |
| `adr-167-ai-slop-detection.md` | 4.2KB | Aug 30 | ✅ Implemented | — |
| `adr-168-multi-engine-architecture.md` | 6.0KB | Aug 30 | 🟡 Outdated | Markeer als "Proposed" |

### B. Research (`docs/research/`) — 18 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `R-020-portable-rule-engine.md` | 24.3KB | Aug 17 | 🟢 Superseded | Banner |
| `R-021-check-rule-categories.md` | 7.9KB | Aug 17 | 🟢 Superseded | Banner |
| `R-022-market-positioning-gemini-research.md` | 19.3KB | Aug 17 | ⚠️ Partial | "bash" → "C++" |
| `R-023-developer-frustrations.md` | 75.6KB | Aug 28 | ✅ Current | — |
| `R-024-gap-analysis-top50.md` | 41.3KB | Aug 28 | ✅ Current | — |
| `R-025-supply-chain-attack-detection.md` | 39.4KB | Aug 28 | ⚠️ Partial | Minor: 70→72 |
| `R-026-iam-golden-rules-as-code.md` | 10.2KB | Aug 30 | ✅ Current | — |
| `R-027-test-quality-rules.md` | 10.2KB | Aug 30 | ✅ Current | — |
| `R-028-ai-development-quality.md` | 8.1KB | Aug 30 | ✅ Current | — |
| `R-029-production-readiness.md` | 7.5KB | Aug 30 | ⚠️ Partial | 875→905 |
| `R-030-design-patterns-vs-native.md` | 50.7KB | Aug 30 | ✅ Current | — |
| `R-030-matrix-analysis.md` | 54.0KB | Aug 30 | ✅ Current | — |
| `R-030-patterns-catalog.md` | 35.4KB | Aug 30 | ✅ Current | — |
| `R-030-platforms-catalog.md` | 51.4KB | Aug 30 | ✅ Current | — |
| `R-031-cpm-refactor-plan.md` | 40.4KB | Aug 30 | ✅ Current | — |
| `node-26-native-replacements.md` | 6.1KB | Jul 22 | ❓ Irrelevant | Verplaatsen |
| `edge-runtime-compatibility.md` | 7.8KB | Jul 22 | ❓ Irrelevant | Verplaatsen |
| `level-2-transitive-replacements.md` | 4.5KB | Jul 22 | ❓ Irrelevant | Verplaatsen |

### C. Checks (`docs/checks/`) — 61 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `accessibility-checks.md` | 21.9KB | Aug 28 | ✅ Current | — |
| `adapter-pattern.md` | 3.8KB | Aug 17 | ✅ Current | — |
| `ai-ml-security.md` | 4.1KB | Aug 28 | ✅ Current | — |
| `check-adr-enforcement.md` | 256B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-agent-config.md` | 249B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-ci-quality.md` | 267B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-clean-code.md` | 221B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-comment-ratio.md` | 244B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-css.md` | 200B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-dangerous-shell.md` | 264B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-dead-docs.md` | 248B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-dead-links.md` | 243B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-dockerfile.md` | 221B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-dora.md` | 224B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-duplication.md` | 242B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-feature-coverage.md` | 264B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-file-size.md` | 270B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-hooks.md` | 209B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-html.md` | 203B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-inclusivity.md` | 243B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-json.md` | 203B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-licenses.md` | 241B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-lockfile.md` | 239B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-makefile.md` | 247B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-native-alternatives.md` | 2.1KB | Jul 22 | ✅ Current | — |
| `check-native-compat.md` | 1.5KB | Jul 22 | ✅ Current | — |
| `check-pii.md` | 671B | Jul 22 | ✅ Current | — |
| `check-portability.md` | 244B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-process.md` | 234B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-research-freshness.md` | 280B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-root-clutter.md` | 227B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-runtime-eol.md` | 264B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-sast.md` | 224B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-sbom.md` | 232B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-scripts.md` | 225B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-secrets-fast.md` | 260B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-slop.md` | 229B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-solid.md` | 245B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-sql-antipatterns.md` | 264B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-stale-docs.md` | 239B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-test-architecture.md` | 252B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-todo-scraper.md` | 244B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-todo.md` | 223B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-traceability-coverage.md` | 262B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-unicode.md` | 244B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-version-pins.md` | 263B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-vue-a11y.md` | 2.9KB | Jul 22 | ✅ Current | — |
| `check-web-essentials.md` | 227B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-windows-portability.md` | 1.1KB | Jul 22 | ✅ Current | — |
| `check-xml.md` | 200B | Jul 22 | 📝 Stub | Uitbreiden |
| `check-xref-validate.md` | 256B | Jul 22 | 📝 Stub | Uitbreiden |
| `frontend-web-best-practices.md` | 30.7KB | Aug 28 | ✅ Current | — |
| `global-hooks.md` | 8.3KB | Aug 28 | ✅ Current | — |
| `graphql-transport.md` | 4.6KB | Aug 28 | ✅ Current | — |
| `launchpad-ppa-setup.md` | 3.0KB | Aug 17 | ℹ️ Setup guide | — |
| `lint-md.md` | 206B | Jul 22 | 📝 Stub | Uitbreiden |
| `lint-yaml.md` | 199B | Jul 22 | 📝 Stub | Uitbreiden |
| `paranoia-mode.md` | 5.7KB | Aug 30 | 🟡 Outdated | encrypt.sh refs |
| `pii-vault.md` | 7.2KB | Aug 28 | ✅ Current | — |
| `secrets-detection.md` | 7.1KB | Aug 28 | ✅ Current | — |
| `syntax-bash.md` | 216B | Jul 22 | 📝 Stub | Uitbreiden |

### D. Features (`docs/features/`) — 32 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `audit.md` | 330B | Jul 22 | ✅ Current | — |
| `build.md` | 339B | Jul 22 | ✅ Current | — |
| `bump.md` | 372B | Jul 22 | ✅ Current | — |
| `check.md` | 1.4KB | Jul 22 | ✅ Current | — |
| `clean.md` | 211B | Jul 22 | ✅ Current | Uitbreiden |
| `commit.md` | 383B | Jul 22 | ✅ Current | README bijwerken |
| `config.md` | 1.4KB | Jul 22 | ✅ Current | — |
| `coverage.md` | 361B | Jul 22 | ✅ Current | — |
| `eject.md` | 1.5KB | Aug 17 | ✅ Current | — |
| `enforcement-levels.md` | 1.9KB | Jul 22 | ✅ Current | — |
| `findings.md` | 1.4KB | Jul 22 | ✅ Current | — |
| `format.md` | 328B | Jul 22 | ✅ Current | — |
| `hooks.md` | 1.2KB | Jul 22 | ✅ Current | — |
| `init.md` | 1.4KB | Jul 22 | ✅ Current | — |
| `install.md` | 560B | Jul 22 | ✅ Current | — |
| `issues.md` | 3.1KB | Jul 22 | ✅ Current | README bijwerken |
| `lint.md` | 323B | Jul 22 | ✅ Current | — |
| `maturity.md` | 1.6KB | Jul 22 | ⚠️ Partial | Levels 0-4 vs 0-5 |
| `new.md` | 1.1KB | Jul 22 | ✅ Current | — |
| `pii-detection.md` | 4.4KB | Jul 22 | ✅ Current | — |
| `release.md` | 2.0KB | Jul 22 | ✅ Current | — |
| `run.md` | 140B | Jul 22 | ✅ Current | — |
| `sbom.md` | 458B | Jul 22 | ✅ Current | — |
| `scan.md` | 1.6KB | Jul 22 | ✅ Current | — |
| `score.md` | 716B | Jul 22 | ✅ Current | — |
| `secrets.md` | 1.1KB | Jul 22 | ✅ Current | — |
| `test.md` | 344B | Jul 22 | ✅ Current | — |
| `todo.md` | 338B | Jul 22 | ✅ Current | README bijwerken |
| `tools.md` | 305B | Jul 22 | ✅ Current | — |
| `usage-modes.md` | 2.6KB | Jul 22 | ⚠️ Partial | "58 checks" → 1043 |
| `version.md` | 210B | Jul 22 | ✅ Current | README bijwerken |
| `xref.md` | 592B | Jul 22 | ✅ Current | README bijwerken |

### E. Compliance (`docs/compliance/`) — 13 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `README.md` | 1.0KB | Aug 28 | ⚠️ Partial | Alle statussen "🔄" |
| `iso-25010.md` | 7.5KB | Aug 28 | ✅ Uitstekend | — |
| `iso-27001.md` | 1.3KB | Jul 22 | ⚠️ Partial | encrypt.sh refs |
| `owasp-top10.md` | 1.0KB | Jul 22 | ✅ Current | — |
| `gdpr.md` | 717B | Jul 22 | ⚠️ Partial | encrypt.sh refs |
| `dora.md` | 917B | Jul 22 | ✅ Current | Duplicaat rij |
| `nist-800-53.md` | 965B | Jul 22 | ⚠️ Partial | encrypt.sh refs |
| `nis2.md` | 794B | Jul 22 | ⚠️ Partial | encrypt.sh refs |
| `wcag.md` | 435B | Jul 22 | ⚠️ Partial | 4/120+ rules |
| `soc2.md` | 761B | Jul 22 | ⚠️ Partial | paranoia-backup |
| `pci-dss.md` | 614B | Jul 22 | ⚠️ Partial | check-outdated |
| `cmmi.md` | 560B | Jul 22 | ✅ Current | — |
| `ce-plus.md` | 531B | Jul 22 | ✅ Current | — |

### F. Designs (`docs/designs/`) — 10 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `iso-25010-quality-mapping.md` | 16.8KB | Aug 28 | ⚠️ Partial | 792→905 rules |
| `rule-engine-config.md` | 6.9KB | Aug 28 | ⚠️ Partial | [rules] niet impl. |
| `refactoring-plan.md` | 6.6KB | Aug 17 | ✅ Current | — |
| `regex-quality-check.md` | 9.5KB | Jul 22 | ✅ Current | — |
| `v-model-level-0.1.drawio` | 1.5KB | Jul 22 | ✅ Current | — |
| `v-model-level-0.2.drawio` | 2.4KB | Jul 22 | ✅ Current | — |
| `v-model-level-0.3.drawio` | 4.0KB | Jul 22 | ✅ Current | — |
| `v-model-level-0.4.drawio` | 4.9KB | Jul 22 | ✅ Current | — |
| `v-model-level-0.5.drawio` | 5.8KB | Jul 22 | ✅ Current | — |
| `v-model-level-0.6.drawio` | 8.7KB | Jul 22 | ✅ Current | — |

### G. Frameworks (`docs/frameworks/`) — 9 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `angular/patterns.md` | 9.1KB | Jul 22 | ✅ Current | — |
| `clean-code/patterns.md` | 3.7KB | Jul 22 | ✅ Current | — |
| `dora/patterns.md` | 6.0KB | Jul 22 | ✅ Current | — |
| `nestjs/patterns.md` | 9.5KB | Jul 22 | ✅ Current | — |
| `nextjs/patterns.md` | 8.4KB | Jul 22 | ✅ Current | — |
| `nx/patterns.md` | 6.9KB | Jul 22 | ✅ Current | — |
| `react/patterns.md` | 10.2KB | Jul 22 | ✅ Current | — |
| `solid/patterns.md` | 9.1KB | Jul 22 | ✅ Current | — |
| `terraform/patterns.md` | 11.3KB | Jul 22 | ✅ Current | — |

### H. Issues — Open (`docs/issues/open/`) — 4 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `cli-terminal-a11y-rules.md` | 5.9KB | Aug 30 | ✅ Open | — |
| `rule-test-coverage-gap.md` | 3.1KB | Aug 30 | ✅ Open | — |
| `config-quality-checks-json-yaml-env.md` | 748B | Jul 22 | ✅ Open | — |
| `coverage-gaps-e2e-25-80-comments-16-20-architecture-docs.md` | 1.3KB | Jul 22 | ⚠️ Open | Getallen updaten |

### I. Issues — Closed (`docs/issues/closed/`) — 26 bestanden

| Pad | Grootte | Laatste wijziging | Werkelijk af? | Actie |
|-----|---------|-------------------|---------------|-------|
| `add-check-regex-safety...md` | 965B | Jul 22 | ✅ Ja | — |
| `add-cpm-check-self-scan-zero-findings...md` | 283B | Jul 22 | ❌ Nee | Heropenen |
| `add-docs-links-to-all-checks.md` | 1.3KB | Jul 22 | ⚠️ Deels | Documenteren |
| `check-sh-wrapper...md` | 1.4KB | Jul 22 | ✅ Ja | — |
| `configure-github-secrets...md` | 505B | Jul 22 | ✅ Ja | — |
| `deduplicate-secret-patterns...md` | 1.2KB | Jul 22 | ❌ Nee | Heropenen |
| `doc-complexity-check...md` | 954B | Jul 22 | ❓ Lege body | — |
| `doc-structure-check...md` | 974B | Jul 22 | ❓ Lege body | — |
| `documentation-quality-checks...md` | 2.7KB | Jul 22 | ⚠️ Deels | — |
| `dual-audit-trail...md` | 1.5KB | Jul 22 | ⚠️ Niet af | Documenteren |
| `feature-module-decomposition...md` | 162B | Jul 22 | ✅ Ja | — |
| `guard-logging...md` | 950B | Jul 22 | ⚠️ Deels | — |
| `integrate-issue-reference...md` | 276B | Jul 22 | ❓ Lege body | — |
| `minimum-quality-baseline...md` | 1.1KB | Jul 22 | ⚠️ Deels | — |
| `monorepo-test-detection...md` | 609B | Jul 22 | ❓ Onverifieerbaar | — |
| `process-guided-development...md` | 1.3KB | Jul 22 | ✅ Ja | — |
| `push-to-github...md` | 197B | Jul 22 | ✅ Ja | — |
| `remove-eval-from-e2e...md` | 611B | Jul 22 | ❓ Lege body | — |
| `reorganize-src-checks-and-docs-adrs...md` | 1.2KB | Jul 22 | ⚠️ Deels | docs/adrs nog 71 bestanden |
| `resolve-all-sonarcloud-bugs...md` | 611B | Jul 22 | ❓ Lege body | — |
| `sanitize-popen-system-calls...md` | 1.4KB | Jul 22 | ⚠️ Deels | — |
| `scan-report-language-distribution...md` | 765B | Jul 22 | ⚠️ Deels | — |
| `shift-left-check-sonarcloud...md` | 978B | Jul 22 | ❓ Onverifieerbaar | — |
| `split-commands-cpp...md` | 1.0KB | Jul 22 | ⚠️ Deels | cmd_ops.cpp 802 regels |
| `split-scan-cpp...md` | 1.2KB | Jul 22 | ✅ Ja | — |
| `unified-findings-contract...md` | 1.7KB | Jul 22 | ⚠️ Deels | — |

### J. Audits (`docs/audits/`) — 3 bestanden (excl. dit rapport)

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `ai-slop-audit.md` | 6.0KB | Aug 30 | ✅ Current | — |
| `lib-shell-audit.md` | 10.4KB | Aug 28 | ✅ Current | — |
| `lab-checks-gap-analysis.md` | 5.3KB | Aug 28 | ✅ Current | — |

### K. Losse docs (`docs/`) — 9 bestanden

| Pad | Grootte | Laatste wijziging | Status | Actie |
|-----|---------|-------------------|--------|-------|
| `README.md` | 2.1KB | Aug 30 | ✅ Current | — |
| `architecture.md` | 5.2KB | Aug 17 | 🟡 Outdated | Regenereren |
| `attacks.md` | 21.7KB | Aug 28 | ✅ Current | — |
| `ci-integration.md` | 824B | Jul 22 | ✅ Current | — |
| `conventions.md` | 2.5KB | Aug 17 | ⚠️ Partial | Herschrijven |
| `design-encrypt.md` | 4.3KB | Aug 28 | ✅ Current | — |
| `design-patterns.md` | 9.7KB | Jul 22 | 🟢 Superseded | Banner |
| `integration.md` | 2.6KB | Jul 22 | 🟢 Superseded | Banner |
| `migration-plan.md` | 10.0KB | Jul 22 | 🟢 Superseded | Banner |
| `process.md` | 2.7KB | Aug 17 | ✅ Current | — |
| `roadmap-distribution.md` | 4.2KB | Jul 22 | ⚠️ Partial | Checkboxen updaten |
| `shared-tooling-analysis.md` | 7.8KB | Jul 22 | 🟢 Superseded | Banner |
| `v-model.md` | 9.7KB | Jul 22 | ✅ Current | — |

---

## Totalen

| Categorie | Bestanden | Current | Partial/Outdated | Superseded | Abandoned | Irrelevant | Stubs |
|-----------|-----------|---------|------------------|------------|-----------|------------|-------|
| ADRs | 71 | 39 (impl+current) | 23 (partial+outdated) | 3 | 5 | 0 | 1 |
| Research | 18 | 10 | 3 | 2 | 0 | 3 | 0 |
| Checks | 61 | 16 | 1 | 0 | 0 | 0 | 44 |
| Features | 32 | 28 | 2 | 0 | 0 | 0 | 0 |
| Compliance | 13 | 4 | 8 | 0 | 0 | 0 | 0 |
| Designs | 10 | 8 | 2 | 0 | 0 | 0 | 0 |
| Frameworks | 9 | 9 | 0 | 0 | 0 | 0 | 0 |
| Issues (open) | 4 | 3 | 1 | 0 | 0 | 0 | 0 |
| Issues (closed) | 26 | 7 | 12 | 0 | 0 | 7¹ | 0 |
| Audits | 3 | 3 | 0 | 0 | 0 | 0 | 0 |
| Losse docs | 13 | 7 | 2 | 4 | 0 | 0 | 0 |
| **Totaal** | **260** | **134** | **54** | **9** | **5** | **10** | **45** |

¹ 7 closed issues met lege body — onverifieerbaar

### Effort Schatting

| Effort | Aantal items | Geschatte tijd |
|--------|-------------|----------------|
| S (< 15 min) | 22 | ~5 uur |
| M (15-60 min) | 5 | ~3 uur |
| L (> 1 uur) | 0 | — |
| **Totaal** | **27** | **~8 uur** |

---

*Dit rapport is gegenereerd op 2026-08-30 als onderdeel van de documentatie-audit van het cpm-project. Alle 260 bestanden in `docs/` zijn geïnventariseerd. Geen documenten zijn verwijderd — alleen statussen zijn genoteerd voor toekomstige actie.*
