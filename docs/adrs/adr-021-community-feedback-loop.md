---
summary: Built-in community feedback — one-click issue creation, deduplication, auto-context, fix tracking.
status: proposed
---

# ADR-021: Community Feedback Loop

## Context

When cpm finds an issue it can't fix, or a user hits a bug in cpm itself, the friction to report it is too high. We want: one command, auto-context, deduplication, and a living feedback loop that drives the roadmap.

## Decision

### `cpm report` — one-click issue creation

```bash
$ cpm check
  ✗ check-npm-audit: lodash prototype pollution (CVE-2024-1234)
    Fix: npm update lodash
    Can't fix? → cpm report

$ cpm report
  Searching existing issues... found 2 similar:
    #42 "lodash CVE in multiple repos" (open, 3 comments)
    #38 "npm audit false positive on dev deps" (closed)

  [1] Add comment to #42 with your context
  [2] Create new issue
  [3] Cancel

  > 1
  ✓ Added comment to #42 with:
    - Your repo (anonymized if private)
    - cpm version
    - OS/arch
    - Finding details
    - Suggested fix
```

### How it works

```text
User hits issue
    │
    ▼
cpm report
    │
    ├─ Search existing issues (GitHub API, fuzzy title match)
    │
    ├─ Found similar? → offer to comment (add data point)
    │
    └─ New? → create issue with auto-context:
         - cpm version + OS + arch
         - Check name + rule
         - File + line (if applicable)
         - Error output (sanitized, no PII)
         - Suggested fix (if known)
         - Maturity level of repo
```

### Auto-context (what gets attached)

| Field | Source | PII-safe? |
|-------|--------|-----------|
| cpm version | binary | Yes |
| OS + arch | uname | Yes |
| Check name | finding | Yes |
| Rule/CVE | finding | Yes |
| Error message | finding (sanitized) | Yes (strip paths) |
| Repo name | git remote (only if public) | Configurable |
| File path | finding (relative only) | Yes |
| Suggested fix | finding | Yes |
| Maturity level | cpm maturity | Yes |

### Deduplication (search before create)

Before creating a new issue:
1. Fetch open issues from `github.com/rkristelijn/cpm/issues`
2. Fuzzy match title against finding message
3. If match score > 70% → suggest commenting instead
4. Comment adds a "+1" data point with context

This means popular issues bubble up naturally — the most-reported problems get the most data points.

### Fix tracking

When a fix is released:
1. Issue is closed with "fixed in v0.2.0"
2. Next time user runs `cpm check`, if their version >= fix version → finding disappears
3. If user is on old version → `cpm report` suggests: "Fixed in v0.2.0. Run: cpm self-update"

### Privacy & consent

Before posting, cpm scans the payload for PII (same patterns as `check-pii`):

```text
$ cpm report
  Preparing report...

  ⚠ PII detected in payload:
    - Line 3: "/Users/remi/git/lab/supplier-manager" → path contains username
    - Line 7: "remi.kristelijn@company.com" → email address

  Suggestions:
    [1] Auto-redact (replace with <REDACTED>)
    [2] Edit manually before posting
    [3] Cancel

  > 1
  ✓ Redacted 2 PII occurrences

  This will share:
    - Check: npm-audit
    - Rule: CVE-2024-1234
    - Path: <REDACTED>/supplier-manager
    - OS: macOS arm64
    - cpm: v0.1.0

  Share? [y/n]:
```

Same pattern as `make commit` — interactive, shows what will happen, lets you choose. Never posts without explicit confirmation after PII check.

### Configuration

```toml
# ~/.config/cpm/cpm.toml (global)
[community]
enabled = true              # enable cpm report
github-repo = "rkristelijn/cpm"
auto-search = true          # search issues before creating
include-repo-name = false   # never share private repo names
```

### Roadmap driven by data

The issues become a prioritized backlog:
- Most-commented = most impactful to fix
- Most-reported rule = most common pain point
- Version distribution = who needs what

```text
$ cpm community-stats   # (future)
  Top pain points:
    #42 lodash CVE (12 reports, 5 repos)
    #38 false positive on dev deps (8 reports)
    #55 slow scan on monorepos (6 reports)
```

### Maturity level for this feature

| Level | Community integration |
|-------|---------------------|
| 0 | No feedback mechanism |
| 1 | `cpm report` exists (manual) |
| 2 | Auto-search + dedup |
| 3 | Fix tracking + version awareness |
| 4 | Community stats + roadmap driven by data |

## Consequences

- Low friction to report issues (one command)
- Deduplication prevents noise
- Auto-context saves time for both reporter and maintainer
- Popular issues bubble up → data-driven roadmap
- Privacy-first (consent, no PII)
- Community grows organically around real problems

## References

- @see docs/adrs/adr-014-findings-database.md (finding context)
- @see docs/adrs/adr-020-product-vision.md (learn, don't police)
- @see docs/adrs/adr-011-compliance-center.md (issue creation)
