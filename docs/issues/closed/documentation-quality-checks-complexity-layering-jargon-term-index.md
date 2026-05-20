---
title: documentation quality checks — complexity, layering, jargon, term index
type: feat
created: 2026-05-19T10:15:00+00:00
labels: [feat, quality, docs]
remote:
---

## What

Apply code-quality patterns to documentation:

### Checks to build

| Check | What | Like code equivalent |
|-------|------|---------------------|
| **doc-file-size** | Max lines per .md file | file-size check |
| **doc-complexity** | Heading depth, nesting, sentence length | cyclomatic complexity |
| **doc-jargon** | Ratio of common English vs technical jargon | "bullshit meter" |
| **doc-layering** | Coarse-grained docs must not contain fine-grained detail | separation of concerns |
| **doc-scope** | Each doc has ONE topic (limited context window) | single responsibility |
| **doc-code-links** | Docs reference code, code references docs | traceability |
| **term-index** | Auto-generated glossary of all jargon/terms used | `cpm index` |

### Concepts

- **Layering (Diátaxis):** Tutorial → How-to → Reference → Explanation. Don't mix levels.
- **Context window friendly:** Each doc should be self-contained enough for an LLM to consume without needing 10 other files.
- **Jargon score:** Count words not in a common English dictionary (top 5000 words). High ratio = hard to read.
- **Term index:** Auto-extract capitalized terms, acronyms, and technical words → `docs/GLOSSARY.md`
- **Bullshit meter (nicer: clarity score):** Long sentences + passive voice + abstract nouns = low clarity.

### Detection methods (all grepable)

```bash
# File size: wc -l
# Heading depth: grep -c "^####" (too deep = too complex)
# Sentence length: awk for sentences > 30 words
# Jargon: compare words against common-english-words.txt
# Layering: ADR referencing implementation details = wrong level
# Code links: grep @see, count coverage
```

## Why

Documentation rots faster than code. Bad docs are worse than no docs — they mislead. Same quality discipline should apply.

## Value

- Quality characteristic: Usability
- Stakeholder benefit: Docs that LLMs and humans can actually use. Self-contained, right level of detail, clear language.

## Acceptance criteria

- [ ] AC1: `check-doc-complexity.sh` flags files >300 lines or >4 heading levels
- [ ] AC2: `check-doc-jargon.sh` reports jargon ratio per file
- [ ] AC3: `cpm index` generates docs/GLOSSARY.md from term extraction
- [ ] AC4: Runs on cpm's own docs without false positives

## Done when

- [ ] Acceptance criteria met
- [ ] Integrated in `cpm check`
- [ ] Own docs pass

## References

- @see ADR-019 (term index)
- @see ADR-013 (Diátaxis documentation types)
- @see docs/adrs/adr-135 (copilot mode — docs in .cpm/ vs embedded)
