---
summary: Auto-generated term index from repo content — tag cloud, concept mapping, ADR linking.
status: proposed
---

# ADR-019: Term Index & Concept Map

## Context

As cpm grows (18 ADRs, 37+ checks, multiple languages), it becomes hard to find where a concept is discussed. "Where did we decide about maturity levels?" "Which ADR talks about DORA?" A term index solves this — scan all files, count terms, map to ADRs.

## Decision

### `cpm index` command

Scans all `.md`, `.sh`, `.cpp`, `.h`, `.toml` files and builds a term frequency index:

```text
$ cpm index

  Term Index (top 30)
  ─────────────────────────────────────────────
  maturity        47  → ADR-012, ADR-013, ADR-018
  compliance      38  → ADR-011, ADR-013
  findings        35  → ADR-014, ADR-017
  scan            28  → ADR-017
  severity        24  → ADR-014, ADR-013
  traceability    19  → ADR-016
  typescript      18  → ADR-015, ADR-018
  enforcement     15  → ADR-011, ADR-013
  junit           14  → ADR-014
  spinner         12  → (lib/shell/ui.sh)
  ...
```

### How it works

1. Walk all tracked files (respect .gitignore)
2. Tokenize: split on whitespace/punctuation, lowercase, strip common words
3. Count frequency per term
4. Map terms to files where they appear most
5. Auto-link to ADRs (grep ADR titles for matching terms)

### Stop words (excluded)

Common words that add noise: the, is, a, an, to, for, in, of, and, or, not, this, that, with, from, are, was, be, has, have, will, can, should, would, etc.

Also exclude: code syntax (`if`, `else`, `return`, `function`, `const`, `var`, `int`, `void`)

### Term categories

| Category | Examples | Source |
|----------|----------|--------|
| Architecture | adapter, hexagonal, ports, domain, layer | ADR-013 |
| Quality | maturity, compliance, severity, finding | ADR-011, ADR-014 |
| Process | commit, push, hook, pipeline, CI | ADR-013 |
| Security | secret, PII, vulnerability, CVE | ADR-014 |
| Testing | unit, e2e, mutation, coverage, pyramid | ADR-012 |
| Tools | gitleaks, semgrep, eslint, clang | ADR-018 |

### Output formats

```bash
cpm index                    # terminal tag cloud (sized by frequency)
cpm index --json             # JSON for tooling
cpm index --link             # show ADR links per term
cpm index --term maturity    # show all files mentioning "maturity"
```

### Tag cloud rendering (terminal)

Larger terms = higher frequency (using bold/normal/dim):

```text
  MATURITY  compliance  FINDINGS  scan  severity
  traceability  typescript  enforcement  junit
  spinner  hook  pipeline  adapter  hexagonal
```

Bold = top 10, normal = top 30, dim = rest.

### Implementation (C++ for speed)

```cpp
struct TermEntry {
    std::string term;
    int count;
    std::vector<std::string> files;    // top 3 files
    std::vector<std::string> adrs;     // linked ADRs
};

// Scan all files, build index, render
int cmd_index(int argc, char *argv[]);
```

Fast: tokenize with `strtok`, hash map for counting. Should handle 1000 files in < 1s.

### Auto-linking to ADRs

For each ADR, extract title keywords. When a term matches an ADR title keyword, link them:

```text
ADR-014 "Findings Database" → terms: findings, database
ADR-017 "Polyrepo Scan" → terms: polyrepo, scan
```

### Use cases

1. **Onboarding**: "what concepts does this project use?" → `cpm index`
2. **Finding ADRs**: "where is X discussed?" → `cpm index --term X`
3. **Consistency**: detect when same concept uses different words
4. **Documentation gaps**: important terms without an ADR

## Consequences

- Quick overview of project vocabulary
- Auto-discovery of related ADRs
- Helps maintain consistent terminology
- Zero deps (C++ tokenizer + hash map)

## References

- Inspired by: TF-IDF, tag clouds, concept maps
- @see docs/adrs/adr-016-traceability-matrix.md (linking artifacts)
- @see docs/adrs/adr-014-findings-database.md (JSONL storage)
