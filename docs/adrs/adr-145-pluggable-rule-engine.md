# ADR-145: Pluggable Rule Engine (Performance-First Design)

**Date:** 2026-07-21  
**Status:** Proposed  
**Supersedes:** Shell-based check execution  
**Context:** 159 checks, need portability (Linux/macOS/Windows), max performance, easy rule contribution

## Decision

Replace shell script checks with a **YAML-configured, C++ rule engine** that maximizes throughput by:
1. Reading each file exactly once (single-pass scanning)
2. Evaluating all applicable rules per file in parallel
3. Zero process spawning (no `fork()`, no `grep`, no shell)
4. Memory-mapped I/O for large repos
5. Rules loaded from embedded + external YAML

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        cpm binary (~300KB)                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────────┐    │
│  │ Rule Loader │───▸│ Rule Index   │───▸│ Engine Dispatch  │    │
│  │ (YAML/TOML) │    │ (per ext/path)│    │                  │    │
│  └─────────────┘    └──────────────┘    └────────┬─────────┘    │
│        ↑                                          │              │
│  ┌─────┴──────────┐                    ┌─────────▼──────────┐   │
│  │ Embedded rules  │                    │ File Scanner       │   │
│  │ (incbin/xxd)    │                    │ ├─ mmap() file     │   │
│  │ + External dirs │                    │ ├─ run all rules   │   │
│  └────────────────┘                    │ │  for this ext    │   │
│                                         │ └─ collect findings│   │
│                                         └────────────────────┘   │
│                                                                  │
│  Engines (compiled-in):                                          │
│  ┌────────────┬────────────┬───────────┬──────────┬──────────┐  │
│  │ Pattern    │ Presence   │ Absence   │ Metric   │ External │  │
│  │ (RE2)     │ (stat)     │ (A !B)    │ (count)  │ (popen)  │  │
│  └────────────┴────────────┴───────────┴──────────┴──────────┘  │
│                                                                  │
│  Output: terminal | JSON | JSONL | SARIF | markdown              │
└──────────────────────────────────────────────────────────────────┘
```

## Performance Design

### 1. Single-Pass File Scanner (the big win)

Current: each of 159 shell scripts does its own `find` + `grep`. That's 159 directory walks + thousands of file reads.

New: **one walk, one read per file, all rules evaluated inline.**

```cpp
// Pseudocode
for (auto& file : walk_tree(root, gitignore)) {
    auto ext = extension(file);
    auto& rules = rule_index.for_extension(ext);  // O(1) lookup
    if (rules.empty()) continue;

    auto content = mmap_read(file);  // zero-copy memory map
    
    for (auto& rule : rules) {
        if (rule.precondition && !rule.precondition->matches(content))
            continue;  // fast reject
        rule.engine->evaluate(file, content, findings);
    }
}
```

**Expected speedup: 50-100x** over shell (no fork, no repeated I/O).

### 2. Rule Index (pre-computed dispatch table)

At startup, rules are indexed by file extension and path pattern:

```cpp
struct RuleIndex {
    // Extension → rules that apply
    std::unordered_map<std::string, std::vector<Rule*>> by_ext;
    // Rules that apply to all files (e.g. file-size check)
    std::vector<Rule*> universal;
    // Path-pattern rules (glob matching)
    std::vector<std::pair<Glob, Rule*>> by_path;
};
```

This means for a `.ts` file, we instantly know which 30 rules to check — not all 500+.

### 3. Regex Engine: RE2 (not std::regex)

`std::regex` is notoriously slow (10-100x slower than RE2). Use Google RE2:
- Linear time guarantee (no catastrophic backtracking)
- Pre-compiled regex set (`RE2::Set`) — match multiple patterns in single pass
- ~3GB/s throughput on modern CPUs

```cpp
// Compile all patterns for an extension into one RE2::Set
RE2::Set pattern_set(RE2::DefaultOptions, RE2::UNANCHORED);
for (auto& rule : rules_for_ts) {
    for (auto& pat : rule.patterns) {
        pattern_set.Add(pat.regex, nullptr);
    }
}
pattern_set.Compile();

// Single pass matches ALL patterns at once
std::vector<int> matched;
pattern_set.Match(file_content, &matched);
```

**One regex pass finds ALL pattern violations in a file.** Not one grep per rule.

### 4. Memory-Mapped I/O

```cpp
#include <sys/mman.h>  // POSIX
// Windows: CreateFileMapping + MapViewOfFile

StringView mmap_read(const std::string& path) {
    int fd = open(path.c_str(), O_RDONLY);
    struct stat st;
    fstat(fd, &st);
    void* ptr = mmap(nullptr, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    madvise(ptr, st.st_size, MADV_SEQUENTIAL);  // hint: we read front-to-back
    close(fd);
    return {(const char*)ptr, (size_t)st.st_size};
}
```

Zero copy, kernel handles page faulting. For small files (<64KB) fall back to `read()` (mmap overhead not worth it).

### 5. Parallel Directory Walk + Evaluation

```cpp
// Thread pool (hardware_concurrency threads)
ThreadPool pool(std::thread::hardware_concurrency());

for (auto& file : directory_entries) {
    pool.submit([&] {
        auto content = mmap_read(file);
        auto& rules = rule_index.for_extension(ext);
        // Each thread evaluates independently, findings collected lock-free
        thread_local std::vector<Finding> local_findings;
        for (auto& rule : rules) {
            rule->evaluate(file, content, local_findings);
        }
        findings_queue.push(std::move(local_findings));
    });
}
```

### 6. Pre-filter (Fast Reject)

Before running expensive regex, cheap byte-level checks:

```cpp
// Skip binary files (contains null bytes in first 512 bytes)
if (memchr(content.data(), 0, std::min(content.size(), 512UL)))
    continue;

// content_match: does this file even contain "containers:" ?
// Use memmem() — faster than regex for literal strings
if (rule.content_match && !memmem(content, rule.content_match))
    continue;  // skip this rule for this file
```

## Rule YAML Format (Final)

```yaml
# rules/security/SEC-001-hardcoded-secrets.yaml
id: SEC-001
title: Hardcoded secret detected
category: security
severity: error
engine: pattern

target:
  extensions: [.ts, .js, .py, .cpp, .java, .yaml, .json, .env]
  exclude_paths: ["test/", "vendor/", "node_modules/"]
  # Fast pre-filter: file must contain one of these literals
  # (checked with memmem, not regex — nanoseconds)
  content_contains_any: ["key", "secret", "token", "password", "AKIA"]

patterns:
  - regex: 'AKIA[A-Z0-9]{16}'
    id: aws-access-key
    message: "AWS Access Key ID"
  - regex: 'sk-[a-zA-Z0-9]{20,}'
    id: openai-key
    message: "OpenAI API key"
  - regex: 'ghp_[a-zA-Z0-9]{36}'
    id: github-pat
    message: "GitHub Personal Access Token"
  - regex: '-----BEGIN (RSA |EC )?PRIVATE KEY'
    id: private-key
    message: "Private key in source"

fix: "Use environment variables or a secrets manager"
references:
  - https://cpm.dev/rules/SEC-001
  - https://owasp.org/Top10/A07_2021/

# Inline test cases (validated by `cpm rule test`)
tests:
  - input: 'aws_key = "AKIAIOSFODNN7EXAMPLE"'
    expect: match
    pattern: aws-access-key
  - input: 'key_ref = "${AWS_KEY}"'
    expect: no_match
```

### Absence Rules (K8s-style)

```yaml
id: K8S-001
title: Pod runs as root
category: k8s-hardening
severity: error
engine: absence

target:
  extensions: [.yaml, .yml]
  content_contains_any: ["kind:"]

# File must match this to be relevant
precondition:
  regex: 'kind:\s*(Deployment|StatefulSet|DaemonSet|Pod|CronJob|Job)'

# Finding = A present WITHOUT B
match:
  present: 'containers:'
  absent: 'runAsNonRoot:\s*true'

message: "No runAsNonRoot: true — pods run as root by default (CIS 5.2.6)"
fix: "Add: securityContext: { runAsNonRoot: true }"
references:
  - https://kubernetes.io/docs/concepts/security/pod-security-standards/
```

### Metric Rules

```yaml
id: QUAL-001
title: God file detected
category: quality
severity: warning
engine: metric
metric: line_count

target:
  extensions: [.ts, .js, .tsx, .jsx, .cpp, .py, .java]
  exclude_paths: ["vendor/", "generated/", "*.test.*"]

threshold:
  max: 300
  # Graduated severity
  levels:
    - above: 500
      severity: error
      message: "File has {value} lines (critical, split immediately)"
    - above: 300
      severity: warning
      message: "File has {value} lines (consider splitting)"
```

### Presence Rules

```yaml
id: PROJ-001
title: Missing lockfile
category: deps
severity: warning
engine: presence

checks:
  - any_file_exists: ["package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb"]
    when_missing: true
    message: "No lockfile — builds are not reproducible"
    condition: file_exists("package.json")  # only check if it's a Node project
```

### External Tool Rules

```yaml
id: TOOL-001
title: YAML lint
category: quality
severity: warning
engine: external

tool:
  command: "yamllint -f parseable -c .config/yamllint.yml ."
  check_available: "yamllint --version"
  skip_if_unavailable: true
  parse_output: "(?P<file>[^:]+):(?P<line>\\d+).*\\[(?P<severity>error|warning)\\] (?P<message>.*)"
```

## File Structure

```
src/
├── main.cpp
├── engines/
│   ├── engine.h              // Base engine interface
│   ├── pattern_engine.cpp    // RE2::Set multi-pattern matching
│   ├── absence_engine.cpp    // A-without-B logic
│   ├── presence_engine.cpp   // File/field existence
│   ├── metric_engine.cpp     // Counting + thresholds
│   └── external_engine.cpp   // Tool delegation
├── rules/
│   ├── rule.h                // Rule struct (parsed from YAML)
│   ├── rule_loader.cpp       // YAML parser → Rule objects
│   ├── rule_index.cpp        // Extension/path dispatch table
│   └── rule_tester.cpp       // `cpm rule test` runner
├── scanner/
│   ├── file_walker.cpp       // gitignore-aware tree walk
│   ├── mmap_reader.cpp       // Memory-mapped file reading
│   └── thread_pool.cpp       // Work-stealing thread pool
├── output/
│   ├── terminal.cpp          // Colored terminal output
│   ├── json.cpp              // JSON/JSONL
│   ├── sarif.cpp             // SARIF 2.1
│   └── markdown.cpp          // Markdown table
└── checks/                   // (legacy native checks, migrate to rules/)
    └── ...

rules/                        // YAML rule files (embedded at compile time)
├── security/
│   ├── SEC-001-secrets.yaml
│   ├── SEC-002-pii.yaml
│   └── ...
├── k8s/
│   ├── K8S-001-run-as-non-root.yaml
│   └── ...
├── quality/
├── deps/
├── docs/
└── lang/
    ├── javascript/
    ├── python/
    └── ...
```

## Build & Embed

```makefile
# Embed all YAML rules into binary
RULES_BLOB := build/rules.o
$(RULES_BLOB): $(shell find rules -name '*.yaml')
	@echo "Embedding $(words $^) rules..."
	@tar czf build/rules.tar.gz -C rules .
	@ld -r -b binary -o $@ build/rules.tar.gz

cpm: src/*.cpp $(RULES_BLOB)
	$(CXX) -O2 -o $@ src/*.cpp $(RULES_BLOB) -lre2 -lpthread -lyaml-cpp
```

At runtime:
```cpp
// Access embedded rules (linked as binary blob)
extern char _binary_rules_tar_gz_start[];
extern char _binary_rules_tar_gz_end[];

void load_embedded_rules() {
    auto tar = decompress(start, end);
    for (auto& entry : tar) {
        rules.push_back(parse_rule_yaml(entry.content));
    }
}
```

## Cross-Compile Matrix

```makefile
# Linux (static, musl)
build-linux:
	CC=musl-gcc CXX=musl-g++ $(MAKE) LDFLAGS="-static"

# macOS (osxcross or native)
build-macos:
	$(MAKE) CXX=o64-clang++

# Windows (MinGW or Zig)
build-windows:
	$(MAKE) CXX=x86_64-w64-mingw32-g++ TARGET=cpm.exe

# All platforms via Zig (simplest cross-compile)
build-all:
	CC="zig cc -target x86_64-linux-musl" $(MAKE) TARGET=cpm-linux
	CC="zig cc -target x86_64-macos" $(MAKE) TARGET=cpm-macos
	CC="zig cc -target x86_64-windows" $(MAKE) TARGET=cpm.exe
```

## Performance Targets

| Metric | Current (shell) | Target (C++ engine) | Method |
|--------|----------------|--------------------|---------| 
| 1000-file repo scan | ~45s | <500ms | Single-pass, mmap, RE2 |
| Startup time | ~200ms (bash init) | <5ms | Static binary, no interp |
| Memory (100K LOC) | ~500MB (159 greps) | <50MB | mmap, no string copies |
| Rule loading | N/A | <10ms | Embedded tar, lazy parse |
| Binary size | N/A (needs bash+tools) | <2MB | Static + embedded rules |

## Dependencies (minimal)

| Library | Purpose | Size | Alternative |
|---------|---------|------|-------------|
| RE2 | Regex engine | ~500KB static | std::regex (10x slower) |
| yaml-cpp | YAML parsing | ~300KB static | toml11 (if switch to TOML) |
| miniz | Decompress embedded rules | ~50KB (header-only) | zlib |
| **Total** | | **<1MB added to binary** | |

## CLI for Rule Authors

```bash
# Create new rule from template
cpm rule new --id SEC-042 --engine pattern --category security

# Test rule against fixture files
cpm rule test rules/security/SEC-042.yaml

# Test all rules (CI)
cpm rule test-all

# Validate YAML schema
cpm rule lint

# Show which rules would fire on a file
cpm explain src/main.cpp

# Benchmark rule performance
cpm rule bench rules/security/
```

## Migration from Shell Scripts

Each shell check maps to a YAML rule:

```bash
# Extract: what does check-dutch.sh actually grep for?
# → MARKERS array → regex pattern
# → file extensions → target.extensions
# → exclusions → target.exclude_paths
# → severity → severity field
# Result: one YAML file replaces 130-line bash script
```

Automated migration script:
```bash
cpm migrate-checks checks/universal/security/check-secrets-fast.sh
# → Generates rules/security/SEC-001-secrets.yaml
# → Extracts regex patterns, file targets, severity
# → Creates test cases from existing fixtures
```

## Summary

| Goal | How |
|------|-----|
| **Performance** | Single-pass scan, RE2::Set, mmap, thread pool, zero fork |
| **Configurable** | YAML rules, external dirs, disable/override per-project |
| **Features** | 5 engines cover all 159 current checks + future growth |
| **Portable** | Static binary, Zig cross-compile, no runtime deps |
| **Contributable** | New check = new YAML file + `cpm rule test` |
