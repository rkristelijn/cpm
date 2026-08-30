# ADR-143: Deep Language Support — Parse Manifests, Not Just Detect Files

*Status*: partially-implemented · *Date*: 2026-05-21 · *Author*: kiro

## Context

Top 500 scan reveals cpm's language-specific checks are shallow for Go, Rust, C++, and Java. JS/TS has 98% detection because we parse package.json content. Other languages only check file presence.

| Language | Detection rate | Why |
|----------|---------------|-----|
| JS/TS | 98% | Parse package.json: deps, scripts, versions |
| Python | 44% | Only check file existence |
| Go | 3% | Only check go.sum presence |
| Rust | 6% | Only check Cargo.lock presence |
| C++ | 37% | Only check .clang-format presence |
| Java | 36% | Parse pom.xml but miss Gradle |

## Decision

For each language, parse the manifest file and extract actionable findings — same depth as package.json.

### Go (go.mod)

```text
Parse: go.mod
Extract:
  - Go version (go 1.21) → EOL check (< 1.21 is EOL)
  - Module count → dependency complexity
  - Indirect deps without go.sum → integrity risk
Checks:
  - go-version-eol: Go < 1.21 is EOL
  - go-mod-tidy: indirect deps not in go.sum
  - go-no-vendor: no vendor/ without go.sum (reproducibility)
```

### Rust (Cargo.toml)

```text
Parse: Cargo.toml
Extract:
  - edition (2015/2018/2021/2024) → EOL/outdated
  - rust-version field → minimum supported
  - [dependencies] count → complexity
  - features usage
Checks:
  - rust-edition-outdated: edition < 2021
  - rust-no-msrv: no rust-version field (compatibility unknown)
  - rust-unsafe-usage: grep for unsafe blocks in src/
```

### C++ (CMakeLists.txt)

```text
Parse: CMakeLists.txt
Extract:
  - cmake_minimum_required → CMake version
  - CMAKE_CXX_STANDARD → C++ standard (11/14/17/20/23)
  - target_link_libraries → dependency count
Checks:
  - cpp-standard-outdated: C++ < 17
  - cpp-no-cmake-minimum: no cmake_minimum_required (build breaks)
  - cpp-no-sanitizers: no AddressSanitizer/UBSan in debug
```

### Python (pyproject.toml / setup.cfg)

```text
Parse: pyproject.toml
Extract:
  - requires-python → version constraint
  - [project.dependencies] → dep count
  - [tool.ruff] / [tool.black] → formatter configured
Checks:
  - python-version-constraint: no requires-python (any version accepted)
  - python-no-formatter: no ruff/black/autopep8 config
  - python-no-type-checker: no mypy/pyright config
```

### Java (build.gradle / build.gradle.kts)

```text
Parse: build.gradle(.kts)
Extract:
  - sourceCompatibility / jvmTarget → Java version
  - dependencies block → dep count
  - plugins → what's configured
Checks:
  - java-gradle-version-eol: Java < 17
  - java-no-dependency-check: no OWASP plugin
  - java-no-spotbugs: no static analysis plugin
```

## Implementation

All checks go in `scan_checks.cpp` in the language-specific section. Pattern:

```cpp
// === Go ===
if (lang == "go") {
  std::string gomod = repo.path + "/go.mod";
  FILE* f = fopen(gomod.c_str(), "r");
  if (f) {
    char buf[8192];
    size_t n = fread(buf, 1, sizeof(buf)-1, f);
    buf[n] = 0;
    fclose(f);
    // Parse "go 1.XX"
    char* gover = strstr(buf, "go ");
    if (gover) {
      int minor = 0;
      sscanf(gover + 3, "1.%d", &minor);
      if (minor < 21) { /* EOL finding */ }
    }
  }
}
```

## Priority

| Language | Repos in top 500 | Current gap | Effort |
|----------|-----------------|-------------|--------|
| Go | 33 | 97% miss | Medium |
| Rust | 32 | 94% miss | Medium |
| Python | 102 | 56% miss | Low (pyproject.toml simple) |
| C++ | 19 | 63% miss | Medium (CMake parsing) |
| Java/Gradle | 14 | 64% miss | Medium |

## Consequences

- ~15 new findings per language
- Detection rate target: >80% for all languages
- Manifest parsing is fast (file I/O only, no tool invocation)
- Aligns with cpm philosophy: zero external tools needed for basic checks
