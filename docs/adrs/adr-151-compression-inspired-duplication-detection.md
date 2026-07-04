---
summary: Compression-inspired approach to code duplication detection for cpm.
status: accepted
---

# ADR-151: Compression-Inspired Duplication Detection

## Context

Zip/LZ77 compression and code duplication detection solve the same fundamental problem: **finding repeated sequences in a stream of symbols**.

### The LZ77 Analogy

LZ77 (1977, Lempel-Ziv) works by maintaining a sliding window over input bytes:

1. **Tokenize** — the input is a stream of bytes
2. **Sliding window** — scan ahead, look back for matches in previously seen data
3. **Back-reference** — when a repeated sequence is found, replace it with `(offset, length)` pointer
4. **Minimum match** — only compress if the match exceeds a threshold (typically 3+ bytes)

This maps directly to code duplication:

| Compression concept | Code duplication equivalent |
|--------------------|-----------------------------|
| Byte stream | Token stream (lexed source code) |
| Sliding window | File/project scope |
| Repeated sequence | Copy-pasted code block |
| Back-reference | "This is a clone of X at line Y" |
| Minimum match length | Minimum tokens/lines threshold |
| Compression ratio | Duplication percentage |

The insight: **a file with high duplication compresses well**. A file with zero duplication is incompressible. This is not just an analogy — it's the same algorithm applied to different alphabets.

### Current State in cpm

SonarCloud handles duplication detection in CI (see ADR-146). The settings in `sonar-project.properties`:

```properties
sonar.cpd.minimumTokens=80
sonar.cpd.minimumLines=15
sonar.cpd.exclusions=src/checks.cpp,src/scan/learn.h,src/scan/compliance.h,**/*_test.*,checks/javascript/**
```

But this is CI-only. cpm has no local duplication check — a gap in the shift-left philosophy.

## Analysis of Existing Tools

| Tool | Algorithm | Languages | License | Speed | Min threshold | Local CLI | CI integration |
|------|-----------|-----------|---------|-------|---------------|-----------|----------------|
| **SonarCloud CPD** | Token-based (Rabin-Karp hashing) | 30+ | Proprietary (free for OSS) | Medium | 100 tokens / 10 lines default | No (cloud) | Native |
| **PMD CPD** | Token-based (match algorithm) | Java, C/C++, JS, Go, Swift, 20+ | BSD-4 | Fast | Configurable tokens | Yes (Java CLI) | Gradle/Maven plugin |
| **jscpd** | Token-based (Rabin-Karp) | 223 formats | MIT | Medium | Configurable (min-lines, min-tokens) | Yes (Node.js) | JSON/XML/HTML reports |
| **Simian** | Token-based | Java, C#, C/C++, JS, Ruby | Commercial ($) | Fast | Configurable lines | Yes | Limited |
| **Duplo** | Line-based (suffix tree) | C/C++ focused | GPL | Fast | Configurable | Yes (C++ binary) | Manual |
| **MOSS** | Winnowing (k-gram fingerprinting) | 26 languages | Academic (service) | N/A (remote) | N/A | No (web service) | No |

### Algorithm Taxonomy

1. **Token-based** (PMD CPD, jscpd, SonarCloud) — Lexes source into language-aware tokens, ignoring whitespace/comments. Finds exact and near-exact clones. The standard approach.

2. **Line-based** (Duplo, Simian) — Compares normalized lines. Faster but misses clones with reformatting.

3. **Fingerprinting** (MOSS) — Hashes k-grams of tokens, uses winnowing to select representative fingerprints. Designed for pairwise comparison of student submissions rather than intra-project detection.

4. **Compression-based** (novel) — Leverage actual LZ77/zstd compression: tokenize source, compress, measure ratio. High ratio = high duplication. Can pinpoint repeated sequences by analyzing the back-references emitted by the compressor.

## Proposed Approach for cpm

### Design Principles

1. **Local-first** — runs in milliseconds on developer machine (pre-push)
2. **Language-aware** — uses token streams, not raw bytes (skip comments/whitespace)
3. **Configurable thresholds** — match SonarCloud settings for consistency
4. **Findings contract** — outputs to unified findings format (ADR-129)
5. **Incremental** — only analyze changed files (git diff integration)

### Architecture

```text
Source files → Tokenizer → Token stream → Duplicate finder → Findings
                  │                              │
                  ├─ C++ tokenizer               ├─ suffix array approach
                  ├─ JS/TS tokenizer             │   (O(n log n) construction)
                  └─ generic (whitespace-split)  │
                                                 └─ sliding window + hash table
                                                     (LZ77-inspired, O(n) average)
```

### The Compression-Inspired Algorithm

```
1. Tokenize source file into token IDs (normalize identifiers optionally)
2. Build hash table of token n-grams (window size = min_tokens / 4)
3. For each position, find longest match in hash table
4. If match length ≥ min_tokens threshold → record as clone pair
5. Output: [(file_a, offset_a, file_b, offset_b, length)]
```

This is essentially what LZ77 does, but instead of emitting compressed output, we emit clone reports.

## Implementation Options

### Option A: Wrap jscpd (Quick Win)

```bash
# Already Node.js, easy to integrate
npx jscpd src/ --min-lines 15 --min-tokens 80 --reporters json
```

**Pros:**
- Immediate (zero development time)
- 223 language support
- Configurable thresholds matching SonarCloud
- JSON output → easy to convert to findings

**Cons:**
- Node.js dependency (cpm is moving toward native C++)
- Slower than native (~5s for medium project)
- No incremental mode
- External dependency risk

### Option B: Wrap PMD CPD (Java)

```bash
pmd cpd --minimum-tokens 80 --language cpp --dir src/ --format csv
```

**Pros:**
- Battle-tested (20+ years)
- Excellent C++ support
- Multiple output formats

**Cons:**
- Java dependency (JRE required)
- Heavy for a CLI tool
- Licensing considerations for redistribution

### Option C: Build Native (C++ LZ77-Inspired)

Implement a lightweight duplicate finder in C++ using the compression analogy:

```cpp
// Simplified: sliding window hash-based clone detection
struct ClonePair {
    std::string file_a, file_b;
    size_t offset_a, offset_b, length;
};

std::vector<ClonePair> detect_clones(
    const std::vector<Token>& tokens,
    size_t min_tokens = 80
) {
    // Rolling hash (Rabin-Karp) over token windows
    // Hash table maps hash → vector of positions
    // For each position: probe hash table, extend match
    // Record if match ≥ min_tokens
}
```

**Pros:**
- Zero external dependencies
- Blazing fast (native C++, single binary)
- Full control over thresholds and output
- Incremental analysis possible
- Aligns with native migration strategy (ADR-145)

**Cons:**
- Development effort (~2-4 days for basic, ~2 weeks for production)
- Must build tokenizers per language
- Testing burden

### Option D: Hybrid — jscpd Now, Native Later

Use jscpd as a shell check (`checks/duplication/check.sh`) immediately, then replace with native implementation when the C++ architecture matures.

**Pros:**
- Immediate value
- Migration path to native
- No blocking on C++ tokenizer development

**Cons:**
- Temporary Node.js dependency
- Two implementations to maintain during transition

## Decision

**Option D: Hybrid approach.**

### Phase 1 (Now): Shell check wrapping jscpd

```bash
# checks/duplication/check.sh
jscpd "${PROJECT_ROOT}/src" \
  --min-lines 15 \
  --min-tokens 80 \
  --reporters json \
  --output "${FINDINGS_DIR}/duplication"
```

- Matches SonarCloud thresholds (80 tokens, 15 lines)
- Outputs JSON → convert to unified findings format
- Runs in pre-push hook (acceptable speed for CI-local)
- `--ignore` patterns from `.jscpd.json` for intentional repetition

### Phase 2 (Future): Native C++ implementation

When the C++ codebase matures (post ADR-145 migration):

- Build tokenizer using tree-sitter grammars (already C, easy to integrate)
- Implement Rabin-Karp rolling hash over token streams
- Suffix array for cross-file detection
- Sub-100ms for typical project size

### Threshold Alignment

| Parameter | SonarCloud | cpm (jscpd) | cpm (native, future) |
|-----------|-----------|-------------|---------------------|
| Min tokens | 80 | 80 | 80 |
| Min lines | 15 | 15 | 15 |
| Exclusions | check structs, tests | same | same |
| Max duplication | 3% (quality gate) | 3% (warning), 5% (error) | same |

## Consequences

- Developers get local duplication feedback before pushing
- Consistent thresholds between local and CI (SonarCloud)
- Compression analogy provides intuitive mental model for the team
- Native migration path keeps long-term architecture clean
- The algorithm research (LZ77, Rabin-Karp, suffix arrays) feeds into potential novel optimizations

## References

- @see sonar-project.properties (CPD thresholds)
- @see ADR-146 (SonarCloud integration)
- @see ADR-145 (gradual native migration)
- @see ADR-129 (unified findings contract)
- @see <https://en.wikipedia.org/wiki/LZ77_and_LZ78>
- @see <https://pmd.github.io/pmd/pmd_userdocs_cpd>
- @see <https://github.com/kucherenko/jscpd>
- @see <http://cs.stanford.edu/~aiken/moss> (MOSS — academic fingerprinting)
- @see Ziv, J. & Lempel, A. (1977). "A Universal Algorithm for Sequential Data Compression"
