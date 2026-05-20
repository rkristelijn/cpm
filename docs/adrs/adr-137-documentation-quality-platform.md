---
summary: Documentation quality as a 5-layer system — from sentence linting to cognitive load analysis.
status: accepted
---

# ADR-137: Documentation Quality Platform

## Context

cpm now has `doc-style` (writing quality) and `doc-complexity` (structure basics). But documentation quality is much deeper than sentence-level linting. Poor docs are the #1 reason developers abandon tools.

## Decision

Documentation quality is a 5-layer system. Each layer builds on the previous. We implement bottom-up with measurable algorithms at every level.

## The 5 Layers

```text
┌─────────────────────────────────────────┐
│ 5. Engineering Quality                  │  ← docs-as-code (snippets compile, links resolve)
├─────────────────────────────────────────┤
│ 4. Cognitive Load Analysis              │  ← UX for docs (concept density, memory load)
├─────────────────────────────────────────┤
│ 3. Information Architecture             │  ← doc-purpose validation (Diátaxis contracts)
├─────────────────────────────────────────┤
│ 2. Structural Quality                   │  ← scanability, flow, navigation
├─────────────────────────────────────────┤
│ 1. Writing Quality                      │  ← sentence linting (DONE)
└─────────────────────────────────────────┘
```

---

## Layer 1: Writing Quality (implemented)

Sentence-level linting. Comparable to Vale, Microsoft Style Guide, Google Developer Docs Style Guide.

### Algorithms

**Readability formulas** (all implemented in `doc_complexity.cpp`):

```text
Flesch Reading Ease:
  FRE = 206.835 - 1.015 × (words/sentences) - 84.6 × (syllables/words)
  Score: 0-100 (higher = easier). Target for dev docs: 40-60.

Flesch-Kincaid Grade Level:
  FKGL = 0.39 × (words/sentences) + 11.8 × (syllables/words) - 15.59
  Score: US grade level. Target: 8-12 for tutorials, 10-14 for architecture.

Gunning Fog Index (jargon density):
  GFI = 0.4 × (words/sentences + 100 × complex_words/words)
  complex_words = words with 3+ syllables (excluding proper nouns, compounds)
  Target: <12 for tutorials, <16 for reference.

Coleman-Liau Index (no syllable counting needed — faster):
  CLI = 0.0588 × L - 0.296 × S - 15.8
  L = avg letters per 100 words, S = avg sentences per 100 words

Automated Readability Index (character-based):
  ARI = 4.71 × (chars/words) + 0.5 × (words/sentences) - 21.43
```

**Syllable counting** (approximation, English):

```cpp
int count_syllables(const std::string& word) {
  if (word.size() <= 3) return 1;
  int count = 0;
  bool prev_vowel = false;
  for (char c : word) {
    bool is_vowel = strchr("aeiouy", tolower(c)) != nullptr;
    if (is_vowel && !prev_vowel) count++;
    prev_vowel = is_vowel;
  }
  if (tolower(word.back()) == 'e') count--;  // silent e
  return count < 1 ? 1 : count;
}
```

**Lexical density** (information vs filler):

```text
Lexical Density = content_words / total_words × 100%

content_words = nouns + verbs + adjectives + adverbs
function_words = articles, prepositions, conjunctions, pronouns, auxiliaries

Approximation without POS tagging:
  function_words = match against stop word list (~200 words)
  content_words = total_words - function_words

Target: 40-60% for dev docs (too high = dense jargon, too low = filler)
```

### Current checks

| Rule | Detects | Source | Autofix |
|------|---------|--------|---------|
| weasel-word | "simply", "just", "obviously" | dictionaries/weasel-words.txt | ✅ Remove |
| passive-voice | "is created", "will be generated" | dictionaries/passive-patterns.txt | ⚠️ Context |
| mixed-addressing | you/we/je mixed in one doc | doc_style.cpp | ❌ Author choice |
| non-imperative | "You should run X" | dictionaries/non-imperative.txt | ✅ Strip prefix |
| undefined-acronym | First use without expansion | doc_style.cpp | ❌ Needs full name |
| hedging | "probably", "you might want to" | dictionaries/hedging-phrases.txt | ✅ Remove |
| low-readability | Flesch < 30 | doc_complexity.cpp | ❌ Rewrite |

### Planned additions

| Rule | Detects | Algorithm | Autofix |
|------|---------|-----------|---------|
| repeated-words | "Click the button button" | Adjacent word comparison | ✅ Remove dup |
| vague-pronouns | "It does this automatically" | "it/this/that/these" without preceding noun in same sentence | ❌ Specify |
| weak-verbs | "handles/manages/processes" | Dictionary match | ⚠️ Suggest |
| filler-phrases | "please note that", "in order to" | Dictionary match | ✅ Remove |
| unnecessary-future | "will create" in instructions | "will + verb" pattern | ✅ → present |
| negative-instructions | "Do not forget to…" | "do not/don't + verb" | ✅ → positive |
| ambiguous-reference | "this/that/these" without noun | Pronoun at sentence start without referent | ❌ Add noun |
| sentence-variance | Max sentence 2× average length | stddev(sentence_lengths) | ❌ Split |

### Autofix transformations

```text
Before: "You should probably run the tests after installation."
After:  "Run the tests after installation."
Rules:  non-imperative + hedging

Before: "It is important to note that the configuration will be created automatically."
After:  "The configuration is created automatically."
Rules:  filler-phrases + unnecessary-future

Before: "Do not forget to set the environment variable."
After:  "Set the environment variable."
Rules:  negative-instructions + non-imperative
```

---

## Layer 2: Structural Quality (partially implemented)

Determines if docs are scannable. A well-structured doc lets readers find what they need without reading everything.

### Algorithms

**Scanability score** (composite):

```text
Scanability = w1×heading_density + w2×list_ratio + w3×code_ratio
            + w4×visual_breaks + w5×(1 - avg_paragraph_length/max_para)

heading_density = headings / (total_lines / 50)     — 1 heading per 50 lines ideal
list_ratio = list_lines / total_lines               — target 10-30%
code_ratio = code_block_lines / total_lines         — target 10-40% for tutorials
visual_breaks = (headings + code_blocks + tables + images) / (total_lines / 20)
avg_paragraph_length = prose_lines / paragraph_count — target: 3-8 lines

Weights: w1=0.25, w2=0.20, w3=0.20, w4=0.15, w5=0.20
Score: 0-100
```

**Topic coherence** (detects context switching):

```text
For each pair of adjacent paragraphs:
  keywords_A = extract_content_words(paragraph_A)  — nouns, verbs, technical terms
  keywords_B = extract_content_words(paragraph_B)
  overlap = |keywords_A ∩ keywords_B| / min(|keywords_A|, |keywords_B|)

If overlap < 0.1 for 3+ consecutive paragraph pairs → "broken-flow" finding.

Simplified (no NLP): use backtick-terms + capitalized words as proxy for keywords.
```

**Terminology consistency**:

```text
For each document:
  terms = extract all backtick-enclosed words and capitalized multi-word phrases
  groups = cluster terms by edit distance (Levenshtein ≤ 2) or shared root

  If a group has >1 variant used in same doc:
    e.g., "workspace" (5×), "project" (3×), "app" (1×) for same concept
    → "inconsistent-terminology" finding

Simplified: maintain a synonyms dictionary (configurable):
  workspace|project|app
  function|method|procedure
  parameter|argument|option
```

### Current checks

| Rule | Detects | Status |
|------|---------|--------|
| missing-summary | No intro after H1 | ✅ doc_structure.cpp |
| missing-example | No code blocks in >50 line doc | ✅ doc_structure.cpp |
| giant-list | >20 items without grouping | ✅ doc_structure.cpp |
| orphan-section | Heading with no content | ✅ doc_structure.cpp |
| skipped-heading-level | H2 → H4 jump | ✅ doc_structure.cpp |
| no-next-steps | Doc ends without links | ✅ doc_structure.cpp |
| doc-too-long | >500 lines | ✅ doc_complexity.cpp |
| doc-multiple-topics | >1 H1 | ✅ check-doc-scope.sh |
| doc-broad-scope | >10 H2 sections | ✅ check-doc-scope.sh |

### Planned additions

| Rule | Detects | Algorithm |
|------|---------|-----------|
| paragraph-wall | Paragraph >8 lines without break | Count consecutive non-empty, non-heading, non-list, non-code lines |
| broken-flow | Topic jumps between sections | Keyword overlap < 0.1 between adjacent paragraphs |
| inconsistent-terminology | Same concept, different words | Synonym dictionary + frequency analysis |
| inconsistent-headings | Mix noun/verb heading styles | POS detection on first word of headings |
| duplicate-sections | Same content repeated | Jaccard similarity on sentence sets between sections (>0.7 = dup) |
| no-visual-breaks | >30 lines of prose without heading/code/table/image | Line counting |

---

## Layer 3: Information Architecture (minimal implementation)

Validate structure per document type. Detect intent, enforce contracts, measure navigation.

### Document Type Detection

```text
Priority order:
1. Frontmatter: type: tutorial|howto|reference|explanation|adr|changelog|api|troubleshooting
2. Path convention: /tutorials/, /guides/, /api/, /adrs/, /reference/
3. Filename: *-tutorial.md, howto-*, adr-*, CHANGELOG.md
4. Content signals (heading + structure analysis):

Signals per type:
  tutorial:        "Step 1"|"Prerequisites"|"What you'll build" + numbered lists
  howto:           "How to" in H1 + imperative headings + short (<100 lines)
  reference:       "Parameters"|"Options"|"Returns"|"API" + tables
  explanation:     "Context"|"Why"|"Background" + no code blocks + diagrams
  adr:             "Decision"|"Context"|"Consequences" + frontmatter status
  api:             "Request"|"Response"|"Endpoint" + JSON code blocks
  troubleshooting: "Symptom"|"Cause"|"Solution"|"Error"
  changelog:       dates + "Added"|"Fixed"|"Changed"|"Removed"
```

### Document Type Contracts

Each type has required and forbidden elements:

```text
TUTORIAL contract:
  required: [prerequisites, numbered_steps, verification, end_result]
  expected: [next_steps, single_path (no choices), progressive_complexity]
  forbidden: [alternatives_discussion, deep_theory, >7 prerequisites]

HOWTO contract:
  required: [goal_statement, steps, result]
  expected: [assumptions, <7 steps, no_background_theory]
  forbidden: [history, "What is X?" sections, >100 lines]

REFERENCE contract:
  required: [parameters_or_options, examples, consistent_format]
  expected: [types, defaults, return_values, error_codes]
  forbidden: [narrative_prose, opinions, "you might want to"]

EXPLANATION (concept) contract:
  required: [context, relationships, trade_offs]
  expected: [diagrams, analogies, links_to_howto]
  forbidden: [step_by_step_instructions, imperative_mood]

ADR contract:
  required: [context, decision, consequences]
  expected: [alternatives_considered, status, date, enforcement]
  forbidden: [implementation_code (>50% code ratio)]

API contract:
  required: [endpoint, request_format, response_format, error_codes, example]
  expected: [authentication, rate_limits, versioning]
  forbidden: [internal_architecture, narrative]

TROUBLESHOOTING contract:
  required: [symptom, cause, solution]
  expected: [prevention, related_issues]
  forbidden: [feature_explanation, tutorials]
```

### Navigation Quality

**Reachability analysis** (BFS from entry point):

```text
Algorithm:
  1. Find entry points: README.md, docs/index.md, docs/README.md
  2. Parse all internal markdown links [text](path)
  3. BFS from entry points, following links
  4. unreachable = all_docs - reachable_docs

  Metrics:
    reachability_ratio = reachable / total_docs
    avg_depth = average shortest path from entry point
    islands = docs with 0 incoming AND 0 outgoing links

  Findings:
    reachability < 0.5 → warning "no-navigation"
    islands > 0 → info "island-doc" per file
    depth > 3 → info "deep-burial" per file
```

**Directory structure**:

```text
  flat_dump: directory with >15 .md files and no README/index → warning
  no_index: directory with >5 .md files and no README → info
  cryptic_name: filename matches /^(doc|notes|misc|tmp|draft)-?\d*\.md$/ → info
  name_content_mismatch: filename stem ≠ H1 (normalized) → info
```

### Progressive Disclosure

**Section ordering score**:

```text
Expected order (by importance to reader):
  1. What it is (description/summary)     — top 10%
  2. Install/Setup                         — top 20%
  3. Basic usage / Quick start             — top 30%
  4. Common options                        — top 50%
  5. Advanced / Configuration              — 50-80%
  6. Troubleshooting / FAQ                 — 80-90%
  7. API / Reference                       — bottom 20%

Score = 1 - (sum of position_violations / total_sections)
position_violation = max(0, actual_position% - expected_max_position%)

Finding: key section (install, usage, examples) below 60% → "buried-content"
```

### Onboarding Speed

**Time to first code** (lines until first copy-pasteable example):

```text
Scan from top:
  Skip: frontmatter, headings, empty lines, prose
  Find: first ``` code block with ≥3 lines

  lines_to_first_code = line_number of first code block

  Targets:
    tutorial/getting-started: ≤ 20 lines
    howto: ≤ 30 lines
    reference: ≤ 50 lines

  Finding: exceeds target → "slow-onboarding"
```

**Copy-paste readiness**:

```text
First code block analysis:
  has_imports = contains "import"|"require"|"#include"|"use"|"from"
  has_ellipsis = contains "..." or "// ..."
  has_undefined = references variables not defined in block
  is_complete = has_imports && !has_ellipsis && !has_undefined

  Finding: !is_complete → "incomplete-example"
```

**Decision fatigue**:

```text
Before first code block, count:
  choices = occurrences of "choose"|"pick"|"select"|"either"|"or you can"|"alternatively"

  Finding: choices > 1 before first example → "decision-fatigue"
```

---

## Layer 4: Cognitive Load Analysis (not implemented — highest priority)

Treat docs like UX — measure mental effort required. No existing tool does this.

Based on Cognitive Load Theory (Sweller 1988) and Miller's Law (7±2 chunks in working memory).
We target **extraneous** cognitive load — the load caused by bad presentation, not by the topic itself.

### Algorithms

**Concept density** (new terms per section):

```text
For each section (between headings):
  technical_terms = words in backticks + UPPER_CASE words + words not in common_english_1000
  new_terms = technical_terms - terms_introduced_in_previous_sections
  concept_density = |new_terms| / section_word_count × 100

  Budget: max 5 new terms per section (Miller's Law: 7±2, minus 2 for safety)

  Finding: new_terms > 5 → "concept-density" warning

  Simplified detection (no NLP):
    is_technical_term(word) = 
      word is in backticks OR
      word is ALL_CAPS (3+ chars, not common English) OR
      word contains '_' or '-' (compound technical term) OR
      word starts with uppercase mid-sentence (proper noun/term) OR
      word not in top-1000 common English words
```

**Stacked instructions** (too many actions per block):

```text
For each paragraph and list item:
  imperative_verbs = count words matching imperative pattern:
    - First word of sentence is a verb (capitalized, not "I", "It", "The"...)
    - Words after "then"|"and"|"," that are verbs

  Simplified: count occurrences of common imperative verbs:
    run|install|create|add|set|open|click|navigate|configure|build|
    start|stop|copy|paste|move|delete|update|enable|disable|restart

  Finding: imperative_count > 3 per sentence → "stacked-instructions"
  Finding: imperative_count > 5 per paragraph → "stacked-instructions"
```

**Forward references** (things you must remember for later):

```text
Detect patterns:
  "see below"|"explained later"|"described in the .* section"|
  "we'll cover"|"more on this"|"as we'll see"|"(see .* section)"

  Count per section.

  Finding: forward_refs > 2 per section → "forward-reference-overload"

  Rationale: each forward ref occupies 1 working memory slot.
  With >2, reader has used 2/4 available slots just for "remember to read later".
```

**Memory overload** (too much to hold in mind):

```text
Tables:
  rows > 20 without sub-headings or grouping → "memory-overload"
  columns > 7 → "memory-overload" (can't compare across wide tables)

Lists:
  items > 15 without sub-grouping → "memory-overload"
  nested depth > 3 → "memory-overload"

Parameters/options:
  If a single section documents >10 parameters without categorization
  → "memory-overload" (suggest: group into "common" vs "advanced")
```

**Context switching** (topic-hopping within a section):

```text
For each section, extract keyword sets per paragraph:
  keywords = content_words(paragraph) — stop words removed

For adjacent paragraphs A, B:
  coherence = |keywords_A ∩ keywords_B| / min(|A|, |B|)

  If coherence < 0.05 (almost no shared words):
    context_switch_count++

Finding: context_switch_count > 2 per section → "context-switching"

Simplified (fast, no NLP):
  Extract backtick-terms + words >6 chars as keywords.
  Compare sets between consecutive paragraphs.
```

**No reinforcement** (concept without example):

```text
For each section that introduces a new concept:
  has_definition = contains "is a"|"refers to"|"means"|": " pattern
  has_example = code block within 20 lines after definition

  Finding: has_definition && !has_example → "no-reinforcement"
```

**High scroll distance** (key content buried):

```text
Key sections (by heading keyword):
  install|setup|usage|example|quickstart|getting.started|api|customiz

For each key section:
  position_pct = section_start_line / total_lines × 100

  Finding: position_pct > 60% → "high-scroll-distance"
  Message: "'{heading}' is at {pct}% of document — most readers need this earlier"
```

### Cognitive Load Budget (configurable in cpm.toml)

```toml
[docs.cognitive-load]
max-concepts-per-section = 5
max-actions-per-instruction = 3
max-forward-references = 2
max-scroll-to-example = 20        # lines after concept intro
max-table-rows-ungrouped = 20
max-list-items-ungrouped = 15
max-paragraph-lines = 8
max-topic-switches-per-section = 2
```

---

## Layer 5: Engineering Quality (minimal implementation)

Docs-as-code — verify docs match reality over time.

### Algorithms

**Code block validity**:

```text
For each fenced code block with language tag:
  1. Extract language (```js, ```bash, ```json, etc.)
  2. Per language:
     json: attempt JSON.parse → invalid = finding
     yaml: check indentation consistency + known keys
     bash: check for undefined variables, unclosed quotes
     js/ts: check imports exist in package.json dependencies

  3. Detect deprecated patterns (configurable per framework):
     react: componentWillMount, findDOMNode, defaultProps on function
     node: require() in ESM, Buffer(), new Buffer()

  Finding: invalid syntax or deprecated API → "stale-code-snippet"
```

**Version drift**:

```text
Extract version references from prose (not code blocks):
  pattern: /\b(v?\d+\.\d+(\.\d+)?)\b/ near known tool names
  pattern: /\b(Node\.?js|TypeScript|React|Python|Java)\s+\d+/

Compare against:
  1. package.json / lockfile versions (if available)
  2. Known EOL dates:
     Node 14: EOL 2023-04, Node 16: EOL 2023-09, Node 18: EOL 2025-04
     TypeScript 4.x: superseded by 5.x (2023-03)
     React 17: superseded by 18 (2022-03)
     Python 3.7: EOL 2023-06, 3.8: EOL 2024-10

  Finding: version in docs < current major in project → "version-drift"
  Finding: version in docs is EOL → "eol-version-in-docs"
```

**Source-doc drift** (git-based):

```text
For each doc file:
  doc_modified = git log -1 --format=%at -- <doc_file>

  For related source files (heuristic: same name stem, or referenced in doc):
    source_modified = git log -1 --format=%at -- <source_file>

  drift_days = (source_modified - doc_modified) / 86400

  Finding: drift_days > 90 → "source-doc-drift"
  Message: "Source changed 90+ days after docs — verify docs are current"
```

**Dead symbol references**:

```text
Extract backtick-enclosed identifiers from docs:
  symbols = all `word` or `word.method` or `word()` patterns

For each symbol:
  grep -r symbol src/ lib/ — check if it still exists in codebase

  Finding: symbol not found in source → "dead-symbol-ref"
  (Skip: common terms like `true`, `false`, `null`, `string`, etc.)
```

**Stale TODOs**:

```text
For each TODO/FIXME/WIP/HACK in docs:
  age = git blame -L <line> -- <file> | extract date
  days_old = now - blame_date

  Finding: days_old > 90 → "stale-todo"
  Message: "TODO is {days} days old — resolve or remove"
```

---

## Composite Scores

### Per-document score

```text
$ cpm docs score README.md

  Layer 1 — Writing:        82/100
    Flesch-Kincaid Grade:   9.2 (target: 8-12) ✓
    Gunning Fog:            11.4 (target: <14) ✓
    Lexical density:        52% (target: 40-60%) ✓
    Style issues:           3 (weasel words)

  Layer 2 — Structure:      91/100
    Scanability:            88
    Paragraph walls:        0 ✓
    Heading density:        good (1 per 35 lines)

  Layer 3 — Architecture:   67/100
    Detected type:          tutorial
    Contract compliance:    4/6 required sections
    Missing:                verification, next_steps

  Layer 4 — Cognitive Load: 74/100
    Concept density:        3.2/section (budget: 5) ✓
    Stacked instructions:   1 violation
    Forward references:     0 ✓
    Scroll to action:       22% ✓

  Layer 5 — Engineering:    88/100
    Dead links:             0 ✓
    Code block validity:    1 deprecated import
    Version drift:          0 ✓

  Overall: B+ (80/100)
```

### Per-project score

```text
$ cpm docs score

  Documents:     58
  Total lines:   12,400

  Layer scores (weighted average across all docs):
    Writing:        76
    Structure:      68
    Architecture:   42  ← weakest
    Cognitive Load: 71
    Engineering:    83

  Overall: C+ (68/100)

  Top 5 issues:
    1. 41 island docs (not linked from anywhere)
    2. 12 docs missing summary
    3. 8 docs with concept density > 5/section
    4. 3 docs with stale code snippets
    5. No index in docs/components/ (58 files)
```

### Grade thresholds

```text
A+: 95-100    Exceptional (rare — auto-generated API docs + great tutorials)
A:  90-94     Excellent
B+: 80-89     Good (most well-maintained OSS projects)
B:  70-79     Adequate
C+: 60-69     Needs work
C:  50-59     Poor
D:  40-49     Unmaintained
F:  <40       Docs are actively harmful
```

---

## Implementation Priority

| Layer | Check | Effort | Impact | Priority |
|-------|-------|--------|--------|----------|
| 4 | concept-density | Medium | Very High | 1 — unique differentiator |
| 3 | doc-type-contracts | Medium | High | 2 — validates intent |
| 4 | stacked-instructions | Low | High | 3 — easy win |
| 2 | paragraph-wall | Low | High | 4 — 3 lines of code |
| 3 | time-to-first-code | Low | High | 5 — onboarding metric |
| 4 | forward-references | Low | Medium | 6 — regex |
| 5 | source-doc-drift | Low | High | 7 — git data available |
| 4 | memory-overload | Low | Medium | 8 — table/list counting |
| 2 | inconsistent-terminology | Medium | High | 9 — needs synonym dict |
| 3 | navigation-index | Low | Medium | 10 — dir check |
| 5 | code-block-validity | High | Very High | 11 — JSON/YAML easy, code hard |
| 5 | version-drift | Low | Medium | 12 — regex + EOL list |
| 3 | reachability-analysis | Medium | High | 13 — BFS over link graph |
| 4 | context-switching | High | Medium | 14 — needs keyword extraction |
| 2 | duplicate-sections | Medium | Low | 15 — Jaccard similarity |

## Implementation Philosophy

### cpm = diagnosis, AI = treatment

cpm provides **deterministic, algorithmic analysis** — no AI, no network, no non-determinism.
The output is structured data (JSONL findings) that AI tools can consume to suggest fixes.

```text
┌──────────────────────┐     ┌──────────────────────┐
│   cpm (algorithm)    │     │   AI (optional)      │
├──────────────────────┤     ├──────────────────────┤
│ • Deterministic      │────▶│ • Uses findings as   │
│ • Fast (<5s)         │     │   context            │
│ • Offline            │     │ • Suggests rewrites   │
│ • Reproducible       │     │ • Generates examples  │
│ • No false positives │     │ • Fills gaps          │
│ • Structured output  │     │ • Non-deterministic   │
└──────────────────────┘     └──────────────────────┘
     JSONL findings ──────────▶ AI prompt context
```

### Multiple analysis axes (all algorithmic)

Documentation quality is not one thing. We analyze along multiple independent axes:

| Axis | Analogy | What it measures |
|------|---------|-----------------|
| **SOLID-driven** | SRP, DIP for docs | One topic per doc, no coupling between sections, consistent interface per type |
| **Traceability** | Requirements tracing | Docs link to code, code links to docs, no orphans, no dead refs |
| **Anti-patterns** | Code smells for prose | Paragraph walls, stacked instructions, forward refs, mixed abstraction |
| **Structure** | Architecture patterns | Heading hierarchy, progressive disclosure, coarse→fine flow |
| **5 Questions** | Acceptance criteria | Purpose? Audience? Flow? Load? Actionable? |

### The 5 fundamental questions (composite checks)

Every finding maps to one of these. If it doesn't answer one of these, it's noise.

```text
1. PURPOSE:    Does this doc have ONE clear goal?
               → type detection + contract validation + SRP check

2. AUDIENCE:   Do I know who this is for?
               → assumptions explicit? prerequisites? mixed levels?

3. FLOW:       Is the order logical?
               → coarse→fine, concrete→abstract, no forward refs, no spaghetti

4. LOAD:       Can I process this?
               → concept density, paragraph walls, stacked instructions, memory overload

5. ACTIONABLE: Can I DO something with this?
               → time to first code, copy-paste ready, complete examples, verification
```

### Feedback strategy: biggest gap first

```text
For each document:
  1. Detect intent (what SHOULD this doc achieve?)
  2. Measure reality along all axes
  3. Gap = intent - reality per axis
  4. Rank gaps by severity
  5. Report top 3 gaps with specific, actionable fix suggestions

Output: not 40 findings that overwhelm, but prioritized actionable feedback.
```

### What "good" means per doc type

| Type | Good = | Bad = |
|------|--------|-------|
| Tutorial | Reader builds something that works in <5 min | Theory without steps, no verification |
| Reference | Reader finds answer in <30 sec | Narrative prose, missing entries |
| ADR | Reader understands decision + trade-offs | No alternatives, no consequences |
| How-to | Problem solved in <7 steps | Background theory, choices before action |
| README | Reader knows what/why/how in 60 sec | No install, no example, wall of text |

### Balance: fast improvement without AI

The algorithms find the **20% of issues that cause 80% of confusion**:

```text
High-value checks (implement first):
  • paragraph-wall         → 3 lines of code, huge readability win
  • concept-density        → count new terms per section
  • time-to-first-code    → lines until first code block
  • missing-summary        → no intro after H1
  • stacked-instructions   → too many actions per sentence

These alone transform docs from "technically correct" to "actually readable."
```

## Design Constraints

- All checks file-based (no network, no compilation for basic checks)
- No AI in the analysis pipeline (deterministic, reproducible)
- Dictionaries external (cSpell-compatible txt files)
- Autofix non-destructive (preview mode by default)
- Scores configurable per project via cpm.toml
- Language-agnostic (works on any markdown)
- Fast: full docs analysis < 5s for 100 files
- Output: JSONL findings consumable by AI tools for fix suggestions

## Conclusion

Implemented. The documentation quality platform is a 5-layer deterministic analysis system:

1. **Writing Quality** — sentence linting (weasel, passive, hedging, acronyms) ✅
2. **Structural Quality** — scanability, paragraph walls, heading hierarchy ✅
3. **Information Architecture** — 19 doc types, weighted signal detection, contract validation ✅
4. **Cognitive Load** — concept density, stacked instructions, forward refs, memory overload ✅
5. **Engineering Quality** — JSON/YAML validation in code blocks ✅

Plus:

- `docs-generate.sh` — auto-generates dependency graph, module overview, CLI reference, install docs, doc coverage
- `history.sh` — git history analysis with growth curves, hotspots, co-change clusters, mermaid visualizations

Key principle: **cpm = diagnosis (deterministic, fast, offline), AI = treatment (optional, uses findings as context).**

103 unit tests passing. Tested against cpm's own docs and mui-docs.

## References

- @see dictionaries/ (cSpell-compatible word lists)
- @see src/checks/docs/doc_style.cpp (Layer 1 implementation)
- @see src/checks/docs/doc_complexity.cpp (Layer 1+2 metrics)
- @see src/checks/docs/doc_structure.cpp (Layer 2+3 basics)
- @see [Diátaxis](https://diataxis.fr/) (Layer 3 framework)
- @see [Vale](https://vale.sh/) (comparable tool for Layer 1)
- @see [Google Developer Docs Style Guide](https://developers.google.com/style)
- @see [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/)
- @see [zakirullin/cognitive-load](https://github.com/zakirullin/cognitive-load) (Layer 4 inspiration, 12.2k stars)
- @see [Sweller 1988](https://doi.org/10.1207/s15516709cog1202_4) (Cognitive Load Theory)
- @see [Information Density](https://wignerfunction.substack.com/p/information-density-why-most-ml-content) (Layer 2 metrics)
- @see [Software Engineering at Google, Ch10](https://abseil.io/resources/swe-book/html/ch10.html) (docs philosophy)
- @see [LintMe: Linting Style and Substance](https://arxiv.org/html/2603.00331) (CHI 2026, academic research on doc linting)
- @see [Writing Technical Content That Helps](https://adventures.michaelfbryan.com/posts/writing-technical-content/) (cognitive load in practice)
