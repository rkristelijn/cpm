# R-031: cpm Refactor Plan — Consistency, Quality & Pattern Alignment

**Date:** 2026-08-30
**Status:** Plan
**Related:** [R-029 Production Readiness](R-029-production-readiness.md) | [R-030 Design Patterns vs Native](R-030-design-patterns-vs-native.md)

---

## Executive Summary

Een diepgaande analyse van de cpm codebase — 80+ C++ bestanden, 188 shell scripts en 885 rule bestanden — heeft **17 inconsistenties** blootgelegd waarvan 5 met hoge ernst. De problemen variëren van dode code en bugs (Django finding-counters die niet incrementeren) tot structurele uitdagingen (drie co-existerende shell-framework-generaties met 62 scripts op het oude systeem). Het project evolueert actief maar elke migratie is ~60-80% compleet: oude patronen worden niet opgeruimd.

De aanpak is een gefaseerd refactor-plan in **5 fasen over 8-10 weken**. Fase 1-3 (weken 1-3) pakken bugs, dode code, output-standaardisatie en portabiliteit aan — laag risico, hoog rendement. Fase 4 (weken 4-6) is de grote Gen1→Gen2 migratie van 62 shell scripts. Fase 5 bevat architectuurbeslissingen die menselijke beoordeling vereisen.

Om de refactor meetbaar te maken zijn **9 CPM-INT rules** geïmplementeerd die samen **299 findings** op cpm zelf detecteren. Na voltooiing van fase 1-3 moeten CPM-INT-002, CPM-INT-003, CPM-INT-006, CPM-INT-009 en CPM-INT-011 op 0 findings staan. Daarnaast zijn **10 PATTERN rules** geïmplementeerd op basis van R-030 Design Patterns vs Native, waarmee het project zijn eigen RTFM-principes afdwingt op de projecten die het scant.

---

## 1. Scope & Methodologie

### 1.1 Hoe de analyse is uitgevoerd

Drie parallelle deep-dive analyses zijn uitgevoerd op de drie lagen van cpm:

1. **C++ analyse** — Alle bestanden in `src/` (80+ .cpp/.h/.hpp) per-bestand doorgelopen op: naming conventions, error handling, string handling, include style, memory management, en design patterns.
2. **Shell analyse** — Alle 188 `.sh` bestanden in `checks/` gescand op: framework generatie, shebang, strict mode, finding() signatures, ANSI codes, FINDINGS counters, exit codes, REPO argument handling, guard clauses, variabele naming, quoting, find/grep patronen, file existence checks, wc -l patronen, SRC resolution, en sourcing patronen.
3. **Rule analyse** — Alle 885 `.rule` bestanden in `rules/` gescand op: ID format, bestandsnaming, title stijl, category waarden, severity waarden, engine types, target patronen, regex stijl, message stijl, fix stijl, `# @see` commentaar, en trailing newline.

De resultaten zijn gecombineerd in een synthese-analyse die cross-layer patronen identificeert.

### 1.2 Wat is gescand

| Laag | Bestanden | Locatie |
|------|-----------|---------|
| C++ | 80+ | `src/**/*.{cpp,h,hpp}` |
| Shell | 188 | `checks/**/*.sh` |
| Rules | 885 | `rules/**/*.rule` |
| **Totaal** | **1153+** | |

### 1.3 Classificatiesysteem

| Ernst | Criteria | Aantal |
|-------|----------|--------|
| **HOOG** | Correctheidsproblemen, dode code, semantische fouten | 5 |
| **MIDDEN** | Portabiliteit, onderhoud, inconsistente output | 10 |
| **LAAG** | Cosmetisch, stijl, documentatie | 5 |

---

## 2. Huidige Staat

### 2.1 Wat goed werkt (patronen om te behouden)

#### C++ — te behouden patronen

| Patroon | Beschrijving | Waarom behouden |
|---------|-------------|-----------------|
| `cpm_*` / `cmd_*` / `ui_*` prefix-conventie | Publieke API's consistent geprefixed per domein | Sterke naming conventie, maakt scope direct duidelijk |
| Fork-Join parallelisme | POSIX `fork()`/`waitpid()` voor parallel check-executie | Past bij "zero deps" filosofie, bewezen performant |
| Enige externe dep = RE2 | Rule engine is enig onderdeel met externe library | Bewuste minimalisatie van dependencies |
| Write-then-rename | Atomaire file updates via temp-file-then-rename | Voorkomt corrupte bestanden bij crashes |
| `snake_case` overal | Consistent snake_case voor functies, geen camelCase | Eenduidig, geen mix |
| NO_COLOR + theme systeem (`ui.h`) | Centraal theme-systeem met role-based styling | Correcte aanpak voor terminal output |
| Mockable interfaces (FileSystem, ToolRunner) | DI voor testbaarheid in check systeem | Goede testarchitectuur |

#### Shell — te behouden patronen

| Patroon | Beschrijving | Waarom behouden |
|---------|-------------|-----------------|
| `REPO="${1:-.}"` contract | 113/188 scripts gebruiken dit universele argument-formaat | Sterkste contract in de shell-laag |
| `findings_add()` via check.sh (Gen2) | Gestructureerde output (JSONL + JUnit XML) | De beoogde richting — 85 scripts al gemigreerd |
| `cpm_check_enabled` guard | 68 scripts gebruiken dit voor check-level override | Correcte opt-in/opt-out mechanisme |
| `cpm_grep` wrapper | 113 plaatsen — abstraheert grep met standaard exclusions | Elimineert inline grep-exclusie duplicatie |
| UPPER_CASE variabelen | Dominant: `REPO`, `FINDINGS`, `SRC`, `FILES`, `IS_WEB` | Consistent met bash conventies |
| `#!/usr/bin/env bash` shebang | 185/188 scripts (98.4%) | Portabel, correct |

#### Rules — te behouden patronen

| Patroon | Beschrijving | Waarom behouden |
|---------|-------------|-----------------|
| Declaratief .rule formaat | Stabiel YAML-achtig key-value formaat met 6 engine types | Kern van het detectie-systeem |
| `pattern` engine dominant | 780/885 rules (88%) — regex-match is de primaire modus | Simpel, snel, begrijpelijk |
| Spatie-gescheiden extensions | `.ts .js .py .java` — consistent, geen komma's | Sterkste format-contract in rule-laag |
| Imperatieve fix-teksten | "Use" (170×), "Add" (115×), "Remove" (51×) — actiegericht | Bruikbare output voor ontwikkelaars |
| Semantische severity | `error` = exploiteerbaar, `warning` = best practice, `info` = marker | Correcte ernst-indeling |

### 2.2 Wat inconsistent is (alle 17 bevindingen)

| ID | Ernst | Beschrijving | Laag | Locatie | Status |
|----|-------|-------------|------|---------|--------|
| HOOG-1 | 🔴 | OO check systeem nooit aangeroepen (migratie-in-progress) | C++ | `src/checks/*.cpp` vs `src/checks.cpp` | Architectuurbeslissing |
| HOOG-2 | 🔴 | Django `finding()` zonder FINDINGS counter increment | Shell | `checks/python/django/check-django*.sh` (2) | Handmatige fix |
| HOOG-3 | 🔴 | `constants.h2` duplicaat van `constants.h` | C++ | `src/common/constants.h2` | Rule: CPM-INT-002 |
| HOOG-4 | 🔴 | `main.c` dode stub met niet-bestaande include | C++ | `src/main.c` | Handmatige fix |
| HOOG-5 | 🔴 | Category `accessibility` vs `a11y` in 2 rules | Rules | `rules/css/CSS-A11Y-01{0,1}.rule` | Rule: CPM-INT-003 |
| MIDDEN-1 | 🟡 | `wc -l` zonder `tr -d ' '` (macOS portabiliteit) | Shell | 46 scripts verspreid | Rule: CPM-INT-004 |
| MIDDEN-2 | 🟡 | Unquoted `$REPO`/`$SRC`/`$DIR` in find commando's | Shell | 81 locaties verspreid | Rule: CPM-INT-005 |
| MIDDEN-3 | 🟡 | ANSI hardcoded macros in `cmd_rule_scan.cpp` bypass `ui.h` | C++ | `src/rules/cmd_rule_scan.cpp` | Rule: CPM-INT-006 |
| MIDDEN-4 | 🟡 | `#!/bin/bash` i.p.v. `#!/usr/bin/env bash` (3 scripts) | Shell | 3 quality-check scripts | Handmatige fix |
| MIDDEN-5 | 🟡 | Strict mode — 9 varianten, 50 scripts zonder | Shell | 50 scripts verspreid | Handmatig (migratie) |
| MIDDEN-6 | 🟡 | `strcasestr` portability workaround gedupliceerd | C++ | `scan_classify.cpp`, `scan_universal.cpp` | Rule: CPM-INT-012 |
| MIDDEN-7 | 🟡 | finding() column width verschilt (%-25s..%-36s) | Shell | 4 scripts + scripts/ | Rule: CPM-INT-009 |
| MIDDEN-8 | 🟡 | ID prefix mix in supply-chain/ rules (SCA- vs SC-SEC-) | Rules | `rules/supply-chain/` | Architectuurbeslissing |
| MIDDEN-9 | 🟡 | REPO argument default `src` i.p.v. `.` (5 scripts) | Shell | 5 check-scripts | Rule: CPM-INT-011 |
| MIDDEN-10 | 🟡 | `has_file()` naamconflict (commands.cpp vs scan.h) | C++ | `src/commands/commands.cpp`, `src/scan/scan.h` | Handmatige fix |
| LAAG-1 | 🔵 | IS_WEB detectie copy-paste in 14 scripts | Shell | 14 javascript/universal scripts | Handmatig (extract) |
| LAAG-2 | 🔵 | Source path resolution — twee methoden | Shell | Alle scripts | Stijlkeuze |
| LAAG-3 | 🔵 | 144 rule bestanden zonder slug in bestandsnaam | Rules | secrets/, nginx/, kotlin/, rust/ | Handmatig (batch) |
| LAAG-4 | 🔵 | 127 rule titles met kleine letter | Rules | go/, k8s/, shell/, transport/ | Rule: CPM-INT-010 |
| LAAG-5 | 🔵 | Category ≠ directory in rules (style→inclusivity, etc.) | Rules | style/, 12factor/, slop/, patterns/ | Documentatie |

> **Telling**: 17 unieke issues plus 3 aanvullende laag-prioriteit observaties uit de detail-analyses.

---

## 3. Geïmplementeerde Detectie

### 3.1 CPM-INT Rules (9 rules, 299 findings)

Alle 9 CPM-INT rules zijn geïmplementeerd als `.rule` bestanden in `rules/quality/` en gevalideerd op de cpm codebase zelf.

| Rule | ID | Detecteert | Severity | Findings op cpm |
|------|-----|-----------|----------|----------------|
| CPM-INT-002 | Duplicate .h2 header | `constants.h2` aanwezigheid | error | **1** |
| CPM-INT-003 | Category accessibility | `category: accessibility` i.p.v. `a11y` | warning | **2** |
| CPM-INT-004 | wc -l no trim | `wc -l)` zonder `tr -d ' '` | warning | **47** |
| CPM-INT-005 | Unquoted find var | `find $REPO` zonder quotes | warning | **81** |
| CPM-INT-006 | Hardcoded ANSI C++ | `#define RED "\033["` in C++ | warning | **6** |
| CPM-INT-009 | Column width | Printf format ≠ `%-30s` | info | **32** |
| CPM-INT-010 | Rule title lowercase | `^title: [a-z]` | info | **123** |
| CPM-INT-011 | Non-root default | `DIR="${1:-src}"` i.p.v. `REPO="${1:-.}"` | warning | **5** |
| CPM-INT-012 | strcasestr duplicated | Portability workaround in meerdere bestanden | info | **2** |
| | | **Totaal** | | **299** |

### 3.2 PATTERN Rules (10 rules)

Gebaseerd op R-030 sectie 10.2 "Aanbevolen nieuwe cpm rules". Deze detecteren over-engineering en RTFM-schendingen.

| Rule | Detecteert | R-030 onderbouwing | Severity |
|------|-----------|-------------------|----------|
| PATTERN-001 | `getInstance()` Singleton in module-based taal | §10.1 regel 3: "Module-scope = Singleton" | warning |
| PATTERN-002 | DI-container library in framework met native DI | §10.1 regel 6: "DI-container alleen als framework het biedt" | warning |
| PATTERN-003 | `IFoo` + `FooImpl` zonder tweede implementatie | §10.1 regel 10: "Eén implementatie = geen interface nodig" | info |
| PATTERN-004 | Lege catch-blocks / geslikte exceptions | §10.1 regel 7: "Onderschatte patterns — Result types" | warning |
| PATTERN-005 | Handmatige Observer in reactive framework | §10.1 regel 2: "Het framework IS het pattern" | info |
| PATTERN-006 | Externe service call zonder circuit breaker/timeout | §10.1 regel 7: "Onderschatte patterns — Circuit Breakers" | info |
| PATTERN-007 | Repository wrapper om ORM dat al repository biedt | §10.1 regel 2: "Het framework IS het pattern" | info |
| PATTERN-008 | Builder pattern voor klasse met <4 velden | §8.1: "Builder voor 3 velden = over-engineering" | info |
| PATTERN-009 | Abstract Factory met slechts 1 concrete factory | §8.2: "Factory die altijd hetzelfde teruggeeft" | info |
| PATTERN-010 | Strategy interface met slechts 1 implementatie | §8.2: "Meer interfaces dan implementaties" | info |

> **Noot**: PATTERN rules produceren 0 findings op cpm zelf — correct, want cpm is C++ (geen module-based taal), gebruikt geen DI-containers, en heeft geen Java/TypeScript patterns.

---

## 4. Refactor Plan

### Fase 1: Bugs & Dode Code (week 1)

**Doel**: Correctheidsproblemen en verwarrende dode code elimineren.
**Risico**: Laag — geen functionele wijzigingen aan werkende code.
**Bestanden geraakt**: 5

#### HOOG-2: Django FINDINGS counter fix

- **Bestanden**: `checks/python/django/check-django-security.sh`, `checks/python/django/check-django.sh`
- **Actie**: Voeg `FINDINGS=$((FINDINGS+1))` toe aan de `finding()` en `error()` functies, of migreer beide scripts naar het `check.sh` framework (Gen2).
- **Voorkeur**: Migreer naar Gen2 — deze scripts gaan toch in fase 4 gemigreerd worden.
- **Effort**: 30 min per script = **1 uur**
- **Verificatie**: Run beide scripts op een Django project en controleer dat FINDINGS > 0 als er bevindingen zijn.

#### HOOG-3: constants.h2 verwijderen

- **Bestand**: `src/common/constants.h2`
- **Actie**: `rm src/common/constants.h2`. Controleer dat geen enkel bestand `#include "constants.h2"` bevat (grep bevestigt 0 matches).
- **Effort**: **5 min**
- **Verificatie**: `make build` slaagt. CPM-INT-002 geeft 0 findings.

#### HOOG-4: main.c verwijderen

- **Bestand**: `src/main.c`
- **Actie**: `rm src/main.c`. Controleer dat `Makefile`/`CMakeLists.txt` dit bestand niet refereren.
- **Effort**: **5 min**
- **Verificatie**: `make build` slaagt. Geen compilatie-waarschuwingen.

**Fase 1 totaal**: ~1,5 uur | 5 bestanden | 0 risico

---

### Fase 2: Output Standaardisatie (week 2)

**Doel**: Consistente output over alle lagen — noodzakelijk voor machine-parsing (CI, JUnit, SARIF).
**Risico**: Laag — alleen output-formatting wijzigt, geen logica.
**Bestanden geraakt**: ~40

#### HOOG-5: Category accessibility → a11y (2 rules)

- **Bestanden**: `rules/css/CSS-A11Y-010-focus.rule`, `rules/css/CSS-A11Y-011-interaction.rule`
- **Actie**: Vervang `category: accessibility` door `category: a11y` in beide bestanden.
- **Effort**: **5 min**
- **Verificatie**: CPM-INT-003 geeft 0 findings. `grep -r "category: accessibility" rules/` retourneert niets.

#### MIDDEN-7: Column width standaardisatie

- **Bestanden** (32 findings, top files):
  - `checks/universal/quality/check-dora.sh` (7 findings)
  - `scripts/report-autofix-status.sh` (6 findings)
  - `scripts/fixes/fix-safe.sh` (3 findings)
  - `checks/universal/check-makefile.sh` (3 findings)
  - en ~10 andere bestanden
- **Actie**: Vervang alle `%-25s`, `%-35s`, `%-36s`, `%-40s` door `%-30s` in printf-statements van finding()/error() functies.
- **Effort**: **2 uur** (sed-script + manuele verificatie)
- **Verificatie**: CPM-INT-009 geeft 0 findings.

#### MIDDEN-3: ANSI hardcoding → ui.h (1 bestand)

- **Bestand**: `src/rules/cmd_rule_scan.cpp`
- **Actie**:
  1. Verwijder de `#define RED`, `#define GREEN`, `#define YELLOW`, `#define RESET`, `#define DIM` macros (regels 16-20)
  2. Voeg `#include "common/ui.h"` toe
  3. Vervang alle `RED`, `GREEN`, etc. door `ui_theme()->error`, `ui_theme()->success`, etc.
- **Effort**: **1 uur**
- **Verificatie**: CPM-INT-006 geeft 0 findings. `build/rule-scan` produceert identieke output. NO_COLOR=1 onderdrukt kleuren.

#### LAAG-4: Rule title capitalisatie (123 findings)

- **Bestanden**: 123 .rule bestanden in `go/`, `k8s/`, `shell/`, `transport/`, `supply-chain/`, etc.
- **Actie**: Batch-script dat `^title: [a-z]` vindt en de eerste letter capitaliseert. Handmatige review voor afkortingen (`os.Exit` → `Os.Exit` is fout, maar `curl with` → `Curl with` is correct).
- **Effort**: **2 uur** (script + review edge cases)
- **Verificatie**: CPM-INT-010 geeft 0 findings.

**Fase 2 totaal**: ~5 uur | ~40 bestanden | Laag risico

---

### Fase 3: Portabiliteit (week 3)

**Doel**: Shell scripts laten werken op macOS, Linux, Alpine/BusyBox zonder verrassingen.
**Risico**: Laag-midden — wc-l fixes zijn mechanisch, quoting-fixes vereisen context-check.
**Bestanden geraakt**: ~60

#### MIDDEN-1: wc -l trim (47 findings)

- **Bestanden** (top 5):
  - `checks/javascript/check-dry-patterns.sh` (10 findings)
  - `checks/universal/quality/check-dora.sh` (7 findings)
  - `checks/universal/docs/check-inclusivity.sh` (4 findings)
  - `checks/javascript/check-adapter-pattern.sh` (4 findings)
  - `checks/javascript/check-code-hygiene.sh` (3 findings)
- **Actie**: Vervang `wc -l)` door `wc -l | tr -d ' ')` of gebruik `wc -l < file` waar mogelijk.
- **Effort**: **3 uur** (sed-script + manuele verificatie van edge cases)
- **Verificatie**: CPM-INT-004 geeft 0 findings. Test op macOS: `echo test | wc -l | tr -d ' '` = `1`.

#### MIDDEN-2: Unquoted vars in find (81 findings)

- **Bestanden** (top 5):
  - `checks/javascript/express/check-express-security.sh` (10 findings)
  - `checks/javascript/angular/check-angular-17.sh` (10 findings)
  - `checks/javascript/vue/check-vue.sh` (9 findings)
  - `checks/javascript/react19/check-react19.sh` (8 findings)
  - `checks/javascript/nextjs/check-nextjs-15.sh` (8 findings)
- **Actie**: Quote alle variabelen in find-commando's: `find $REPO` → `find "$REPO"`, `find $SRC` → `find "$SRC"`, `find $DIR` → `find "$DIR"`.
- **Effort**: **4 uur** (sed-script + manuele verificatie dat quotes correct zijn in context)
- **Let op**: Sommige `$SRC` variabelen worden in find-expressies gebruikt waar quoting de semantiek kan wijzigen (bijv. bij glob-expansie). Elke wijziging handmatig controleren.
- **Verificatie**: CPM-INT-005 geeft 0 findings.

#### MIDDEN-4: Shebang standaardisatie (3 scripts)

- **Bestanden**:
  - `checks/universal/quality/check-xref-validate.sh`
  - `checks/universal/quality/check-todo-scraper.sh`
  - `checks/universal/quality/check-traceability-coverage.sh`
- **Actie**: Vervang `#!/bin/bash` door `#!/usr/bin/env bash` op regel 1.
- **Effort**: **5 min**
- **Verificatie**: `grep -r "#!/bin/bash" checks/` retourneert niets.

#### MIDDEN-9: REPO default (5 scripts)

- **Bestanden**:
  - `checks/universal/check-centralize-patterns.sh`
  - `checks/universal/check-shared-separation.sh`
  - `checks/universal/check-magic-literals.sh`
  - `checks/universal/check-logging-centralized.sh`
  - `checks/javascript/check-js-lint.sh`
- **Actie**: Vervang `DIR="${1:-src}"` door `REPO="${1:-.}"` en wijzig `$DIR` naar `"$REPO/src"` of `"$REPO"` in de rest van het script. Controleer dat de check-logica correct blijft.
- **Effort**: **1 uur** (5 scripts × ~10 min elk)
- **Verificatie**: CPM-INT-011 geeft 0 findings. Elk script functioneert correct met zowel `.` als een expliciet pad.

**Fase 3 totaal**: ~8 uur | ~60 bestanden | Laag-midden risico

---

### Fase 4: Migratie Gen1→Gen2 (week 4-6)

**Doel**: Alle shell checks naar het `check.sh` framework brengen voor gestructureerde output.
**Risico**: Midden — scripts wijzigen van framework, output-formaat verandert.
**Bestanden geraakt**: ~80

Dit is de grootste fase. De 62 Gen1-scripts (inline `finding()`) moeten gemigreerd worden naar het Gen2 `findings_add()` framework. Daarnaast moeten ~20 shared patronen geëxtraheerd worden.

#### Stap 4.1: MIDDEN-5 — Strict mode standaardisatie (50 scripts)

- **Actie**: Voeg `set -o nounset -o pipefail` toe aan alle scripts die geen strict mode hebben en geen `check.sh` sourcen.
- **Aanpak**: Batch-script dat na de shebang-regel `set -o nounset -o pipefail` toevoegt als het ontbreekt.
- **Effort**: **2 uur**
- **Verificatie**: `grep -rL "set -o\|source.*check.sh" checks/**/*.sh` retourneert alleen scripts waar dit bewust ontbreekt (bijv. `check-slop.sh` met `set +e`).

#### Stap 4.2: Gen1 finding()→Gen2 findings_add() (62 scripts)

De migratie per script volgt dit patroon:

```bash
# Gen1 (oud):
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Gen2 (nieuw):
source "$(dirname "$0")/../../lib/shell/check.sh"
# findings_add "severity" "file" "rule" "message" ["fix"] ["docs_url"]
```

**Aanpak per batch**:

| Batch | Scripts | Directory | Effort |
|-------|---------|-----------|--------|
| 1 | 5 | `checks/python/` (incl. Django fix uit fase 1) | 4 uur |
| 2 | 5 | `checks/php/` | 4 uur |
| 3 | 4 | `checks/terraform/` | 3 uur |
| 4 | 1 | `checks/java/` | 1 uur |
| 5 | 15 | `checks/universal/` (top-level) | 12 uur |
| 6 | 15 | `checks/universal/docs/` + `checks/universal/security/` | 12 uur |
| 7 | 17 | `checks/javascript/` (top-level + subdirs) | 14 uur |
| **Totaal** | **62** | | **~50 uur** |

**Per script** (~45 min gemiddeld):

1. Vervang init.sh source door check.sh source (5 min)
2. Verwijder inline `finding()`/`error()` definities (2 min)
3. Vervang alle `finding "rule" "message"` door `findings_add "warning" "$file" "rule" "message"` (15 min)
4. Vervang alle `error "rule" "message"` door `findings_add "error" "$file" "rule" "message"` (10 min)
5. Verwijder `FINDINGS` counter en exit-logica (5 min)
6. Test het script (10 min)

#### Stap 4.3: Extract shared functies

- **IS_WEB detectie** (14 scripts): Extract naar `cpm_is_web_project()` in `lib/shell/init.sh`
- **SRC resolution** (~50 scripts): Promoot `cpm_find_src` — vervang inline `[ -d "$REPO/src" ] && SRC=` patronen
- **Effort**: **4 uur**
- **Verificatie**: `grep -r "IS_WEB=false" checks/` retourneert 0 resultaten na extractie.

**Fase 4 totaal**: ~56 uur (~2-3 weken) | ~80 bestanden | Midden risico

---

### Fase 5: Architectuurbeslissingen (backlog)

**Doel**: Beslissingen nemen over structurele items die menselijke beoordeling vereisen.
**Risico**: Hoog — deze beslissingen beïnvloeden de roadmap.
**Bestanden geraakt**: Afhankelijk van beslissingen.

#### HOOG-1: OO check systeem — integreren of verwijderen?

**Situatie**: `src/checks/` bevat 18+ C++ klassen met `virtual run()`, DI, mocking, en unit tests. Ze worden nergens in de main flow aangeroepen. `checks.cpp` dispatcht via shell scripts.

**Optie A: Integreren**

| Pro | Con |
|-----|-----|
| Investering in OO systeem wordt benut | Significant werk (wiring, registratie, output-formaat) |
| Snellere checks (native C++ vs shell fork/exec) | Twee systemen moeten co-existeren tijdens migratie |
| Unit-testbaar met mocking | Verhoogt complexiteit van de binary |
| Past bij R-029 fase 4 (shell check migratie) | |

**Optie B: Verwijderen**

| Pro | Con |
|-----|-----|
| Simpelere codebase | Investering verloren (18+ bestanden, tests, DI-infra) |
| Eén mentaal model (shell checks + rules) | Verlies van type-safe C++ checks |
| Minder compilatie-tijd | Bepaalde checks (architectuur, import graph) passen beter in C++ |

**Aanbeveling**: **Optie A — integreren**, maar gefaseerd:

1. Wire de bestaande C++ checks in de main flow (checks die regex kan't: architectuur, dead code, shadow vars, doc complexity)
2. Migreer overige shell checks naar rules (waar regex volstaat)
3. Dit sluit aan bij R-029 fase 1 (integrate rule engine) en fase 4 (shell check migration)

#### MIDDEN-8: supply-chain ID prefix

**Situatie**: `rules/supply-chain/` bevat zowel `SCA-NNN` als `SC-SEC-NNN` prefixen.

**Opties**:

1. `SCA-NNN` voor alles (simpel, maar verliest security-markering)
2. `SCA-NNN` generiek + `SCA-SEC-NNN` voor security-gerelateerd (consistent met `GO-SEC-NNN`, `BE-SEC-NNN`)
3. Behoud huidige mix (geen actie, maar verwarrend)

**Aanbeveling**: Optie 2 — `SCA-NNN` + `SCA-SEC-NNN`. Hernoem bestaande `SC-SEC-*` naar `SCA-SEC-*`.

#### MIDDEN-10: has_file() naamconflict

**Situatie**: Twee functies `has_file()` met verschillende signatures in `commands.cpp` (static, `const char*`) en `scan.h` (inline, `const string&, const char*`).

**Opties**:

1. Hernoem naar `cmd_has_file()` en `repo_has_file()` — consistent met `cmd_*`/`cpm_*` prefixen
2. Unificeer tot één functie in een shared header
3. Behoud (werkt door scope-isolatie)

**Aanbeveling**: Optie 1 — past bij het bestaande prefix-systeem.

---

## 5. Impact Analyse

### 5.1 Bestanden geraakt per fase

| Fase | Bestanden | % van codebase |
|------|-----------|---------------|
| Fase 1: Bugs & Dode Code | 5 | 0.4% |
| Fase 2: Output Standaardisatie | ~40 | 3.5% |
| Fase 3: Portabiliteit | ~60 | 5.2% |
| Fase 4: Gen1→Gen2 Migratie | ~80 | 6.9% |
| Fase 5: Architectuurbeslissingen | TBD | TBD |
| **Totaal fase 1-4** | **~185** | **~16%** |

### 5.2 Risico-inschatting per fase

| Fase | Risico | Reden |
|------|--------|-------|
| Fase 1 | 🟢 Laag | Verwijderen van dode code, geen functionele impact |
| Fase 2 | 🟢 Laag | Alleen output-formatting, geen logica-wijzigingen |
| Fase 3 | 🟡 Laag-Midden | wc -l en quoting fixes zijn mechanisch, maar edge cases mogelijk |
| Fase 4 | 🟡 Midden | Framework-migratie wijzigt output-formaat en error handling |
| Fase 5 | 🔴 Hoog | Architectuurbeslissingen met langetermijn-impact |

### 5.3 Wat breekt er als we niks doen

| Issue | Gevolg van inactie |
|-------|-------------------|
| HOOG-2: Django FINDINGS | Django checks rapporteren altijd "0 findings" — gebruikers missen beveiligingsproblemen |
| HOOG-3/4: Dode code | Verwarring voor contributors, hogere onboarding-tijd |
| MIDDEN-1: wc -l | Arithmetic failures op macOS bij checks die counts vergelijken |
| MIDDEN-2: Unquoted vars | Checks falen op paden met spaties (realistisch voor repos in `My Documents/`) |
| MIDDEN-5: Strict mode | Silent failures — variabelen die ongemerkt leeg zijn |
| Gen1→Gen2 migratie | Twee output-formaten (printf vs JSONL) — CI-integratie wordt complexer |
| OO check systeem | 18+ C++ bestanden die meecompileren maar nooit draaien — technische schuld groeit |

---

## 6. Verificatie

### 6.1 CPM-INT rules als success metrics

Na elke fase moeten specifieke CPM-INT rules 0 findings geven:

| Fase | CPM-INT rules → 0 findings | Huidig → Doel |
|------|---------------------------|---------------|
| Fase 1 | CPM-INT-002 | 1 → 0 |
| Fase 2 | CPM-INT-003, CPM-INT-006, CPM-INT-009, CPM-INT-010 | 2+6+32+123 → 0 |
| Fase 3 | CPM-INT-004, CPM-INT-005, CPM-INT-011 | 47+81+5 → 0 |
| Fase 4 | CPM-INT-012 (en niet-rule items) | 2 → 0 |
| **Totaal** | **Alle 9 rules** | **299 → 0** |

### 6.2 Verificatie-strategie per fase

| Fase | Verificatie-methode |
|------|-------------------|
| Fase 1 | `make build` slaagt; `build/rule-scan 2>&1 \| grep CPM-INT-002` = 0; handmatige test Django scripts op Django project |
| Fase 2 | `build/rule-scan 2>&1 \| grep CPM-INT-00[369]` = 0; `build/rule-scan 2>&1 \| grep CPM-INT-010` = 0; `NO_COLOR=1 build/rule-scan` toont geen ANSI codes |
| Fase 3 | `build/rule-scan 2>&1 \| grep CPM-INT-00[45]` = 0; `build/rule-scan 2>&1 \| grep CPM-INT-011` = 0; `shellcheck` op gewijzigde scripts |
| Fase 4 | Alle gemigreerde scripts produceren JSONL output; `cpm check` integratietest op testproject; `cpm check --junit` produceert valide XML |

### 6.3 Regressiepreventie

- Voeg `build/rule-scan 2>&1 | grep -c "\[CPM-INT-"` toe aan CI — blok merge als count > 0 na fase 4.
- Overweeg een `cpm check --self` command dat de CPM-INT rules op de eigen codebase draait.

---

## 7. Relatie tot R-029 Production Readiness

### 7.1 Wat dit plan oplost

| R-029 Item | Dit plan | Fase |
|-----------|----------|------|
| "Fix 110 shallow test assertions" (Phase 0.1) | Niet direct, maar fase 4 verbetert testbaarheid via Gen2 framework | — |
| "Delete 8 deprecated native checks" (Phase 0.2) | Gerelateerd aan HOOG-1 (OO check systeem integreren/verwijderen) | Fase 5 |
| "Split scan_checks.cpp" (Phase 0.3) | Niet in scope — apart refactor-item | — |
| "Add strict mode to 62 shell scripts" (Phase 0.4) | **Ja — fase 4, stap 4.1** (MIDDEN-5) | Fase 4 |
| "Validate rules on 5 real-world repos" (Phase 0.5) | Niet in scope — apart validatie-item | — |
| "Static-link RE2 into main binary" (Phase 1.1) | Gerelateerd aan HOOG-1 — integratie van de twee systemen | Fase 5 |
| "Reduce external dependencies" (Phase 2) | Niet in scope — apart item | — |
| "Test quality" (Phase 3) | Fase 4 migratie naar Gen2 maakt scripts individueel testbaar | Fase 4 |
| "Shell check migration to rules" (Phase 4) | Fase 4 is de voorbereidende stap — Gen2 scripts zijn makkelijker te analyseren voor rule-migratie | Fase 4 |

### 7.2 Wat overblijft na dit plan

De volgende R-029 items worden **niet** door dit plan geadresseerd:

1. Rule engine integratie in main binary (R-029 Phase 1)
2. Externe dependency reductie (R-029 Phase 2)
3. Test quality — shallow assertion fixes (R-029 Phase 3)
4. Shell→rule migratie (R-029 Phase 4) — dit plan bereidt voor, maar voert niet uit
5. Community readiness (R-029 Phase 5)
6. scan_checks.cpp monolith decomposition

---

## 8. Relatie tot R-030 Design Patterns

### 8.1 PATTERN rules relevant voor cpm zelf

cpm is een C++ project met shell scripts — geen TypeScript/Java framework. De 10 PATTERN rules zijn primair bedoeld voor de projecten die cpm scant, niet voor cpm zelf. Dit is correct: cpm's PATTERN rules produceren 0 findings op de eigen codebase.

Echter, de R-030 principes zijn wél van toepassing op cpm's **architectuurbeslissingen**:

| R-030 Principe | Toepassing op cpm |
|---------------|-------------------|
| "Module-scope = Singleton" (regel 3) | cpm gebruikt correct `static local` singletons (`ui_theme()`, `get_compliance_tags()`) — geen getInstance() |
| "Het framework IS het pattern" (regel 2) | cpm's `check.sh` framework IS het output-pattern — scripts moeten het niet omzeilen met eigen `finding()` |
| "DI-container alleen als framework het biedt" (regel 6) | cpm's OO check systeem gebruikt correct constructor injection (`FileSystem&`, `ToolRunner&`) — geen DI-container |
| "Eén implementatie = geen interface nodig" (regel 10) | cpm's `FileSystem` en `ToolRunner` interfaces zijn gerechtvaardigd — ze hebben zowel Real als Mock implementaties |
| "RTFM > SOLID" (kernprincipe) | cpm's function-pointer dispatch (`scan_lang.cpp`) is correct — geen inheritance hierarchy voor iets dat een map + functie oplost |

### 8.2 RTFM-principes die cpm zelf toepast

De C++ analyse toont bewuste anti-OOP keuzes:

1. **Geen inheritance hierarchie voor commands** — `main.cpp` gebruikt een simpele if/else chain. R-030 §9.1: "< 50 regels → simpele functie/module"
2. **Function pointer dispatch** in `scan_lang.cpp` — `std::unordered_map<string, LangCheckFn>`. R-030 §9.2: "Go idioom: explicit > magic" — van toepassing op C++ hier
3. **Geen DI-container** — constructor injection waar nodig, rest is proceduraal. R-030 §7.2: "Manual DI voor kleine tools"
4. **Commentaar in code**: `"RTFM > SOLID > code flex"` — het R-030 principe is al gedocumenteerd in de broncode zelf

---

## Appendix A: Alle CPM-INT Rule Definities

### CPM-INT-002 — Duplicate header file with .h2 extension

```rule
# @see R-030 synthesis: HOOG-3
id: CPM-INT-002
title: Duplicate header file with .h2 extension
category: quality
severity: error
engine: file-presence
target:
  filenames: constants.h2
  exclude_paths: .git/ build/ dist/
fix: Remove constants.h2 and ensure all includes reference constants.h (the constexpr version).
```

### CPM-INT-003 — Inconsistent accessibility category name in rule

```rule
# @see R-030 synthesis: HOOG-5
id: CPM-INT-003
title: Inconsistent accessibility category name in rule
category: quality
severity: warning
engine: pattern
target:
  extensions: .rule
  exclude_paths: .git/
patterns:
  - regex: ^category:\s*accessibility\s*$
    message: "Rule uses 'category: accessibility' instead of the standard 'category: a11y' — 120 rules use a11y"
fix: Replace 'category: accessibility' with 'category: a11y' for consistency.
```

### CPM-INT-004 — wc -l without whitespace trim (macOS portability)

```rule
# @see R-030 synthesis: MIDDEN-1
id: CPM-INT-004
title: wc -l without whitespace trim (macOS portability)
category: quality
severity: warning
engine: pattern
target:
  extensions: .sh
  exclude_paths: node_modules/ vendor/ .git/ build/ dist/
patterns:
  - regex: wc -l\)$
    message: "wc -l without tr -d ' ' — output contains leading spaces on macOS which breaks arithmetic"
  - regex: wc -l\s*\|?\s*$
    message: "wc -l at end of pipeline without whitespace trim — add | tr -d ' '"
fix: "Use $(... | wc -l | tr -d ' ') or redirect: $(wc -l < file)"
```

### CPM-INT-005 — Unquoted variable in find command

```rule
# @see R-030 synthesis: MIDDEN-2
id: CPM-INT-005
title: Unquoted variable in find command
category: quality
severity: warning
engine: pattern
target:
  extensions: .sh
  exclude_paths: node_modules/ vendor/ .git/ build/ dist/
patterns:
  - regex: find \$REPO[/ ]
    message: "Unquoted $REPO in find — breaks on paths with spaces. Use find \"$REPO\""
  - regex: find \$DIR[/ ]
    message: "Unquoted $DIR in find — breaks on paths with spaces. Use find \"$DIR\""
  - regex: find \$SRC[/ ]
    message: "Unquoted $SRC in find — breaks on paths with spaces. Use find \"$SRC\""
fix: Quote all variables in find commands, e.g., find "$REPO" instead of find $REPO.
```

### CPM-INT-006 — Hardcoded ANSI escape in C++ bypasses ui.h theme

```rule
# @see R-030 synthesis: MIDDEN-3
id: CPM-INT-006
title: Hardcoded ANSI escape in C++ bypasses ui.h theme
category: quality
severity: warning
engine: pattern
target:
  extensions: .cpp .h .hpp
  exclude_paths: test/ tests/ vendor/ .git/ build/ dist/
patterns:
  - regex: #define\s+\w+\s+"\\033\[
    message: "Hardcoded ANSI escape macro — use ui_theme() from ui.h for NO_COLOR support"
  - regex: #define\s+\w+\s+"\\x1[bB]\[
    message: "Hardcoded ANSI escape macro — use ui_theme() from ui.h for NO_COLOR support"
fix: Replace hardcoded ANSI macros with ui_theme()->error, ui_theme()->success, etc. from ui.h.
```

### CPM-INT-009 — finding() column width deviates from %-30s standard

```rule
# @see R-030 synthesis: MIDDEN-7
id: CPM-INT-009
title: finding() column width deviates from %-30s standard
category: quality
severity: info
engine: pattern
target:
  extensions: .sh
  exclude_paths: node_modules/ vendor/ .git/ build/ dist/
patterns:
  - regex: printf.*%-25s
    message: "finding() uses %-25s — standard is %-30s for consistent terminal output alignment"
  - regex: printf.*%-35s
    message: "finding() uses %-35s — standard is %-30s for consistent terminal output alignment"
  - regex: printf.*%-36s
    message: "finding() uses %-36s — standard is %-30s for consistent terminal output alignment"
  - regex: printf.*%-40s
    message: "finding() uses %-40s — standard is %-30s for consistent terminal output alignment"
fix: Standardize the printf column width to %-30s in all finding()/error() functions.
```

### CPM-INT-010 — Rule title starts with lowercase letter

```rule
# @see R-030 synthesis: LAAG-4
id: CPM-INT-010
title: Rule title starts with lowercase letter
category: quality
severity: info
engine: pattern
target:
  extensions: .rule
  exclude_paths: .git/
patterns:
  - regex: ^title:\s+[a-z]
    message: "Rule title starts with lowercase — use sentence case (capitalize first letter) for consistency"
fix: Capitalize the first letter of the title field in the rule file.
```

### CPM-INT-011 — Check script defaults to non-root directory

```rule
# @see R-030 synthesis: MIDDEN-9
id: CPM-INT-011
title: Check script defaults to non-root directory
category: quality
severity: warning
engine: pattern
target:
  extensions: .sh
  exclude_paths: node_modules/ vendor/ .git/ build/ dist/ lib/
patterns:
  - regex: DIR="\$\{1:-src\}"
    message: "Script defaults DIR to 'src' instead of repo root — breaks the REPO=${1:-.} contract"
  - regex: DIR="\$\{1:-app\}"
    message: "Script defaults DIR to 'app' instead of repo root — breaks the REPO=${1:-.} contract"
  - regex: DIR="\$\{1:-lib\}"
    message: "Script defaults DIR to 'lib' instead of repo root — breaks the REPO=${1:-.} contract"
fix: "Use REPO=\"${1:-.}\" and derive subdirectories: SRC=\"$REPO/src\""
```

### CPM-INT-012 — Duplicated strcasestr portability workaround

```rule
# @see R-030 synthesis: MIDDEN-6
id: CPM-INT-012
title: Duplicated strcasestr portability workaround
category: quality
severity: info
engine: pattern
target:
  extensions: .cpp .h .hpp
  exclude_paths: test/ tests/ vendor/ .git/ build/ dist/
patterns:
  - regex: static const char\* strcasestr\(
    message: "strcasestr portability workaround — should be in compat.h, not duplicated per file"
fix: Move the strcasestr shim to src/common/compat.h and include compat.h where needed.
```

---

## Appendix B: Alle Findings per Rule (samenvatting)

### B.1 CPM-INT-002 — Duplicate .h2 header (1 finding)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `src/common/constants.h2` | 1 |

### B.2 CPM-INT-003 — Category accessibility (2 findings)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `rules/css/CSS-A11Y-010-focus.rule` | 1 |
| 2 | `rules/css/CSS-A11Y-011-interaction.rule` | 1 |

### B.3 CPM-INT-004 — wc -l no trim (47 findings)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `checks/javascript/check-dry-patterns.sh` | 10 |
| 2 | `checks/universal/quality/check-dora.sh` | 7 |
| 3 | `checks/universal/docs/check-inclusivity.sh` | 4 |
| 4 | `checks/javascript/check-adapter-pattern.sh` | 4 |
| 5 | `checks/javascript/check-code-hygiene.sh` | 3 |
| | *+ 15 andere bestanden* | 19 |

### B.4 CPM-INT-005 — Unquoted find var (81 findings)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `checks/javascript/express/check-express-security.sh` | 10 |
| 2 | `checks/javascript/angular/check-angular-17.sh` | 10 |
| 3 | `checks/javascript/vue/check-vue.sh` | 9 |
| 4 | `checks/javascript/react19/check-react19.sh` | 8 |
| 5 | `checks/javascript/nextjs/check-nextjs-15.sh` | 8 |
| | *+ ~20 andere bestanden* | 36 |

### B.5 CPM-INT-006 — Hardcoded ANSI C++ (6 findings)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `src/rules/cmd_rule_scan.cpp` | 6 |

### B.6 CPM-INT-009 — Column width deviation (32 findings)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `checks/universal/quality/check-dora.sh` | 7 |
| 2 | `scripts/report-autofix-status.sh` | 6 |
| 3 | `scripts/fixes/fix-safe.sh` | 3 |
| 4 | `checks/universal/check-makefile.sh` | 3 |
| 5 | `lib/shell/fix-sql.sh` | 2 |
| | *+ ~10 andere bestanden* | 11 |

### B.7 CPM-INT-010 — Rule title lowercase (123 findings)

| # | Bestand (voorbeeld) | Findings |
|---|---------|----------|
| 1 | `rules/supply-chain/SCA-075-npm-postinstall-obfuscated.rule` | 2 |
| 2 | `rules/ansible/ANS-010-become-without-user.rule` | 2 |
| 3 | `rules/a11y/A11Y-055-reset-button-present.rule` | 2 |
| 4 | `rules/transport/TRANS-003-wget-no-check.rule` | 1 |
| 5 | `rules/transport/TRANS-002-curl-insecure.rule` | 1 |
| | *+ ~115 andere bestanden* | 115 |

### B.8 CPM-INT-011 — Non-root default (5 findings)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `checks/universal/check-centralize-patterns.sh` | 1 |
| 2 | `checks/universal/check-shared-separation.sh` | 1 |
| 3 | `checks/universal/check-magic-literals.sh` | 1 |
| 4 | `checks/universal/check-logging-centralized.sh` | 1 |
| 5 | `checks/javascript/check-js-lint.sh` | 1 |

### B.9 CPM-INT-012 — strcasestr duplicated (2 findings)

| # | Bestand | Findings |
|---|---------|----------|
| 1 | `src/scan/scan_classify.cpp` | 1 |
| 2 | `src/scan/scan_universal.cpp` | 1 |

---

## Appendix C: Cross-referentie met R-029

| R-029 Fase | R-029 Item | R-031 Dekking | R-031 Fase |
|-----------|-----------|---------------|------------|
| Phase 0.1 | Fix 110 shallow test assertions | ❌ Niet in scope | — |
| Phase 0.2 | Delete 8 deprecated native checks | 🔶 Gerelateerd (HOOG-1 OO systeem) | Fase 5 |
| Phase 0.3 | Split scan_checks.cpp monolith | ❌ Niet in scope | — |
| Phase 0.4 | Add strict mode to 62 shell scripts | ✅ **Volledig** (MIDDEN-5) | Fase 4.1 |
| Phase 0.5 | Validate rules on 5 real-world repos | ❌ Niet in scope | — |
| Phase 1.1 | Static-link RE2 into main binary | 🔶 Gerelateerd (HOOG-1 integratie) | Fase 5 |
| Phase 1.2 | Add `cpm check --rules` | ❌ Niet in scope | — |
| Phase 1.3 | Bundle rules in binary | ❌ Niet in scope | — |
| Phase 1.4 | Remove rule-scan as separate binary | ❌ Niet in scope | — |
| Phase 2 | Reduce external dependencies | ❌ Niet in scope | — |
| Phase 3 | Test quality | 🔶 Fase 4 maakt scripts testbaar | Fase 4 |
| Phase 4 | Shell check migration to rules | 🔶 Fase 4 is voorbereidend | Fase 4 |
| Phase 5 | Community readiness | ❌ Niet in scope | — |

**Legenda**: ✅ = volledig gedekt | 🔶 = gedeeltelijk/voorbereidend | ❌ = niet in scope

### Samenvatting overlap

- **1 van 12** R-029 items volledig gedekt door dit plan (strict mode)
- **4 van 12** R-029 items gedeeltelijk gedekt of voorbereid
- **7 van 12** R-029 items buiten scope (infrastructuur, community, validatie)

Dit plan is complementair aan R-029: R-031 focust op **interne consistentie en kwaliteit**, R-029 focust op **externe productie-gereedheid**. Samen dekken ze de volledige roadmap naar een production-grade tool.
