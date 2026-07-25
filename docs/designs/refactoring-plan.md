# cpm Refactoring Plan — van 67/100 (C) naar 90+ (A)

## Huidige Score

```text
Code Health: 67/100 (C)

🍝 Spaghetti   67  █████████████░░░░░░░  god files, deep nesting, coupling
🍲 Lasagna     10  ██░░░░░░░░░░░░░░░░░░  OK
🟠 Ravioli      0  ░░░░░░░░░░░░░░░░░░░░  OK
🍕 Pizza       30  ██████░░░░░░░░░░░░░░  mixed concerns, flat structure
🌋 Lava Flow   58  ███████████░░░░░░░░░  TODOs, unsafe C, dead patterns
```

## God Files (de kern van het probleem)

| File | Lines | Verantwoordelijkheden | Probleem |
|------|-------|----------------------|----------|
| `scan_checks.cpp` | 1091 | 40+ scan functies | God function, alles in 1 file |
| `cmd_ops.cpp` | 703 | 15 commands | Elke cmd_* is een aparte verantwoordelijkheid |
| `commands.cpp` | 608 | init, new, coverage, clean | Nog meer commands |
| `checks.cpp` | 595 | CHECK_DEFS + runner + gate logic | Data + execution + UI gemixed |
| `regex_quality.cpp` | 495 | 12 check functies | Net aangemaakt, maar al groot |

## Design Patterns Toepassing

### 1. Strategy Pattern → Check Execution

**Probleem:** `checks.cpp` mixt check-definities (data), execution (runner), en output (UI).

**Nu:**

```cpp
// checks.cpp — 595 lines, alles door elkaar
static const CheckDef CHECK_DEFS[] = { ... };  // DATA
static int run_defs(...) { ... }                // EXECUTION
static void print_result(...) { ... }           // UI
int cmd_check(...) { ... }                      // ORCHESTRATION
```

**Beter (Strategy):**

```text
src/checks/
├── defs/           ← CHECK_DEFS arrays (pure data, geen logica)
│   ├── lint.cpp
│   ├── security.cpp
│   ├── format.cpp
│   └── supply_chain.cpp
├── runner.cpp      ← run_defs() (Strategy: parallel vs sequential)
├── gate.cpp        ← cmd_check_gate() (tiered: fast/default/full)
└── registry.cpp    ← registreert alle defs + native checks
```

### 2. Command Pattern → cmd_ops.cpp splitsen

**Probleem:** `cmd_ops.cpp` (703 lines) bevat 15 onafhankelijke commands.

**Nu:**

```cpp
// cmd_ops.cpp — 703 lines
int cmd_hook(...) { ... }      // 30 lines
int cmd_bump(...) { ... }      // 40 lines  
int cmd_coverage(...) { ... }  // 60 lines
int cmd_score(...) { ... }     // 100 lines
// ... 11 meer
```

**Beter (Command Pattern):**

```text
src/commands/
├── cmd_hook.cpp        ← 30 lines
├── cmd_bump.cpp        ← 40 lines
├── cmd_coverage.cpp    ← 60 lines
├── cmd_score.cpp       ← 100 lines
├── cmd_findings.cpp
├── cmd_issue.cpp
├── cmd_commit.cpp
└── commands.h          ← registry van alle commands
```

### 3. Composite Pattern → scan_checks.cpp splitsen

**Probleem:** `scan_checks.cpp` (1091 lines) heeft 40+ individuele scan functies die elk 1 kwaliteitsaspect meten.

**Beter (Composite):**

```text
src/scan/
├── scan.cpp            ← orchestrator
├── checks/
│   ├── readme.cpp      ← check_readme()
│   ├── ci.cpp          ← check_ci()
│   ├── testing.cpp     ← check_tests()
│   ├── docs.cpp        ← check_documentation()
│   ├── security.cpp    ← check_security()
│   ├── deps.cpp        ← check_dependencies()
│   └── architecture.cpp← check_architecture()
└── scoring.cpp         ← score berekening (nu in scan.cpp)
```

### 4. Template Method → Native checks

**Probleem:** Elke native check herhaalt hetzelfde boilerplate (file iteration, line scanning, finding creation).

**Al deels opgelost:** `line_scanner.h` is het Template Method. Maar `regex_quality.cpp` (495 lines) bewijst dat checks snel groeien als ze meerdere sub-checks bevatten.

**Beter:** Split regex_quality.cpp in:

```text
src/checks/quality/
├── regex_quality.cpp       ← orchestrator (50 lines)
├── regex/
│   ├── shell_quoting.cpp   ← check_shell_quoting()
│   ├── dialect.cpp         ← check_dialect_mismatch()
│   ├── redos.cpp           ← check_redos() + check_overlapping()
│   └── correctness.cpp     ← empty_alt, unescaped_dot, etc.
```

### 5. Facade Pattern → main.cpp

**Probleem:** `main.cpp` (282 lines) is een giant switch/if-else voor command routing.

**Beter:**

```cpp
// main.cpp — just routing, no logic
int main(int argc, char* argv[]) {
  CpmConfig cfg = parse_config();
  return dispatch_command(cfg, argc, argv);  // Facade
}
```

### 6. Builder Pattern → Findings/Reports

**Probleem:** Findings worden overal ad-hoc geconstrueerd met 7-8 velden.

**Beter:**

```cpp
findings.push_back(Finding::build("regex-quality")
  .severity("error")
  .file(file).line(line)
  .rule("redos-nested-quantifiers")
  .message("Nested quantifiers detected")
  .fix("Use atomic groups")
  .docs("https://owasp.org/...")
);
```

## Refactoring Volgorde (risico-arm → hoog impact)

| Stap | Wat | Impact | Risico | Pattern |
|------|-----|--------|--------|---------|
| 1 | Split `cmd_ops.cpp` → 1 file per command | -200 Spaghetti | Laag | Command |
| 2 | Split `scan_checks.cpp` → categorieën | -300 Spaghetti | Laag | Composite |
| 3 | Split `checks.cpp` → defs/runner/gate | -150 Spaghetti, -20 Pizza | Medium | Strategy |
| 4 | Fix C warnings (atoi→stoi, strcpy→string) | -30 Lava | Laag | - |
| 5 | Remove TODOs (fix of delete) | -20 Lava | Laag | - |
| 6 | Split `regex_quality.cpp` → sub-checks | -100 Spaghetti | Laag | Template |
| 7 | Builder voor Findings | -10 Pizza | Medium | Builder |

## Verwachte Score na Refactoring

```text
Code Health: 91/100 (A)

🍝 Spaghetti   10  ██░░░░░░░░░░░░░░░░░░  (was 67)
🍲 Lasagna     15  ███░░░░░░░░░░░░░░░░░  (iets meer abstractie = OK)
🟠 Ravioli     10  ██░░░░░░░░░░░░░░░░░░  (meer files, maar cohesief)
🍕 Pizza        5  █░░░░░░░░░░░░░░░░░░░  (was 30)
🌋 Lava Flow    5  █░░░░░░░░░░░░░░░░░░░  (was 58)
```

## Niet Doen (YAGNI)

- Geen abstracte base classes voor commands (overkill voor C CLI tool)
- Geen plugin systeem (checks zijn al shell scripts)
- Geen dependency injection framework (het is C++, niet Java)
- Geen shared libraries/DLLs (single binary is een feature)
- `main.cpp` hoeft geen framework te worden — het is gewoon routing
