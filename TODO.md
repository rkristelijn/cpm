
## Priority 1 — Mechanical fixes (R-031 fase 1-3, ~9 hours)

> These are all detected by CPM-INT rules. Target: 175 findings → 0.

- [ ] **wc -l trim** — 47 scripts missing `| tr -d ' '` after `wc -l` (macOS portability bug) `CPM-INT-004`
- [ ] **grep -c double-output** — 12 checks/ scripts + `check-xref-validate.sh:57` use `grep -c ... || echo 0`, which emits `0\n0` when grep matches nothing (grep prints 0 *and* `||` fires), corrupting counters/arithmetic. Fix: `n=$(grep -c ... ) || n=0`. (Found while building coderabbit-harvest.sh; same pattern check-coderabbit-patterns.sh itself flags.)
- [ ] **Unquoted vars in find** — 81 locations with `find $REPO` instead of `find "$REPO"` `CPM-INT-005`
- [ ] **Column width %-30s** — 32 findings with non-standard printf width in finding() `CPM-INT-009`
- [ ] **ANSI → ui.h** — `cmd_rule_scan.cpp` hardcodes ANSI macros, should use `ui_theme()` `CPM-INT-006`
- [x] ~~**category a11y** — 2 CSS rules use 'accessibility' instead of 'a11y'~~ `CPM-INT-003` — fixed 2026-08-30
- [ ] **Non-root defaults** — 5 scripts use `DIR="${1:-src}"` breaking REPO contract `CPM-INT-011`
- [ ] **strcasestr → compat.h** — duplicated portability shim in 2 files `CPM-INT-012`
- [x] ~~**constants.h2 duplicate**~~ `CPM-INT-002` — removed 2026-08-30
- [x] ~~**122 rule titles lowercase**~~ `CPM-INT-010` — capitalized 2026-08-30

## Priority 2 — Strategic (high impact)

- [x] ~~**Integrate rule-scan into `cpm check`**~~ — rule-scan draait als check in checks.cpp (verified 2026-09-14)
- [ ] **Gen1→Gen2 shell migration** — 62 scripts still use inline finding() instead of findings_add() (R-031 fase 4)
- [ ] **Add strict mode to 62 shell scripts** — `SH-STRICT-002` finds 67 scripts missing `set -o errexit -o nounset -o pipefail`
- [ ] **Rule test coverage** — 909 rules but only ~60 with e2e assertions (docs/issues/open/rule-test-coverage-gap.md)
- [ ] **E2E coverage 25→80%** — (docs/issues/open/coverage-gaps)
- [ ] **SonarCloud integration** — ADR-146, external validation of cpm's own code
- [ ] **Move cpm-eval boilerplate rules** (100 BP-* rules) into cpm/rules/ once validated on more repos
- [ ] **Unify JUnit output** — `cpm findings --junit` should use C++ binary, not shell

## Priority 3 — Cloud Provider IaC Coverage

Current: 13 IAC rules + 10 serverless rules — almost entirely AWS-focused.

- [ ] **Azure** (~20 rules): storage without HTTPS, NSG allow-all, AKS without RBAC, Key Vault soft-delete disabled, SQL Server without audit, App Service HTTP-only, missing Azure Defender, public IP on VMs, storage without private endpoint, managed identity not used
- [ ] **Google Cloud** (~15 rules): GCS allUsers, GKE legacy ABAC, Cloud SQL without SSL, Compute firewall 0.0.0.0/0, KMS rotation disabled, Cloud Run allUsers, Pub/Sub without DLQ, uniform bucket-level access, VPC flow logs disabled, IAM primitive roles
- [ ] **Cloudflare** (~10 rules): WAF disabled, SSL not full_strict, always_use_https off, security_level off, rate limiting absent, bot management off, missing origin CA
- [ ] **Multi-cloud generic** (~10 rules): provider without version constraint, backend without encryption, no prevent_destroy on stateful, output sensitive=true missing, count vs for_each
- [ ] **DigitalOcean** (~5 rules): droplet without VPC, firewall allow-all, spaces public, no monitoring
- [ ] **Vercel/Netlify** (~5 rules): missing headers (CSP/HSTS), _headers file missing, env vars in config

## Priority 4 — Rule Quality

- [ ] Add `content_contains` pre-filter to remaining ~400 rules (501/909 have it, ~30% speedup potential)
- [ ] Reduce noise: QUAL-021 (731 hits) — exclude closing fences
- [ ] SH-QUAL-010 triple-counts per file — consolidate to one finding
- [ ] STYLE-042 (banner comments) — exclude .sh files where separators are idiomatic
- [ ] A11Y rules (120): add HTML fixtures to cpm-eval
- [ ] SECRETS rules (80): add token/key fixtures to cpm-eval
- [ ] SCA-028 (committed git hooks) — tighten `content_contains: hooks`
- [ ] SCA-062 (unknown third-party action) — exclude known trusted orgs (actions/, github/, aws-actions/)
- [ ] Review subjective info-level rules: RS-QUAL-021, RS-QUAL-035, TEST-019 — keep or demote to `learn` only?
- [ ] Add duplicate-title detection to `cpm lint` — 7 rules share titles across languages
- [ ] **SEC-044 full-set quirk** — `SEC-044` (hardcoded /tmp) fires standalone (unit test in rules_test.cpp proves L1/L6) but is suppressed under the full ~1003-rule set. e2e assertion is a documented `skip`. Investigate engine ordering/per-line first-match behaviour. (2026-09-14)
- [ ] **Review-audit bot regex** — `cpm-eval/research/gitlab-review-audit.sh` bot_re misses GitLab per-project service accounts (`project_<id>_bot_<hash>`); they count as human reviewers. Extend bot_re with `project_[0-9]+_bot_`. (2026-09-14)

## Priority 5 — Features (backlog)

- [ ] `cpm ai-steer` — generate AI steering files for all known assistants (see `scripts/generate-ai-steering.sh`)
- [ ] Global `--timeout` flag for cpm commands
- [ ] Refactor Makefile to facade-only (all logic in cpm binary)
- [ ] Issue tracker adapter pattern (GitHub, ClickUp, Jira) — ADR-021 abandoned but simpler version possible
- [ ] Config quality checks (JSON/YAML/env) — docs/issues/open
- [ ] CLI terminal a11y rules — docs/issues/open
- [ ] Laravel/PHP checks — ADR-148
- [ ] Compression-based duplication detection — ADR-151
- [ ] Documentation quality platform — ADR-137

## Done (2026-09-14)

> ⚠️ **Uncommitted — commit buiten kantoortijd.** Twee repos: `cpm` + `cpm-eval`.

- [x] 5 new rules from GitLab review-audit + native-check cleanup:
  - `ERR-001` (Go ignored `if err != nil {}`), `ERR-002` (Python `except ...: pass`), `DUP-002` (duplicate route path)
  - `SEC-044` (hardcoded /tmp path), `SEC-045` (debug enabled in config)
- [x] Removed 5 redundant native OWASP grep checks from `checks.cpp`, coverage moved to rules:
  - empty-catch → QUAL-050/PATTERN-004/ERR-002; weak-crypto → SEC-038/SEC-039/GO-SEC-014;
    cors → WEB-SEC-016/SEC-031/API-016; tmp-hardcoded → SEC-044; debug-enabled → SEC-045
- [x] Improved SEC-038 (bare `md5()/sha1()`, skip_comments/strings, exclude_names, `.php`) and WEB-SEC-016 (skip_comments)
- [x] Cleaned `cpm.toml` (owasp-empty-catch toggle) + updated ADR-152 mapping
- [x] Fixtures + e2e (`test-new-rules.sh`, 130/130) + unit scenarios (`rules_test.cpp`, 100/100); test_checks 123/123; rules-smoke green
- [x] `rules-authoring.md`: added "Rules mined from code review" section
- [x] cpm-eval: removed APS-specific references from research README + gitlab-review-audit.sh; ran review-quality audit against public gitlab-org (read-only)

## Done (2026-08-30)

- [x] R-030: Design Patterns vs Native Platform Features research (137 patterns × 130 platforms)
- [x] R-031: cpm Refactor Plan (17 inconsistencies, 5 phases)
- [x] 10 PATTERN rules (PATTERN-001 through PATTERN-010)
- [x] 9 CPM-INT consistency rules (CPM-INT-002 through CPM-INT-012)
- [x] 122 rule titles capitalized (CPM-INT-010 → 0 findings)
- [x] constants.h2 removed (CPM-INT-002 → 0 findings)
- [x] Docs audit: 260 docs inventoried, 69 updated with status banners
- [x] 5 abandoned ADRs marked (016, 019, 021, 023, 134)
- [x] 8 outdated ADRs marked with banners
- [x] 15 partially-implemented ADRs: frontmatter updated
- [x] 6 implemented ADRs: proposed → implemented
- [x] architecture.md rewritten with accurate state
- [x] 8 encrypt.sh references fixed
- [x] cpm-eval extended with PATTERN test fixtures + assertions (124/124 pass)

## Done (earlier sessions)

- [x] ADR-126: Traceability by Design (xref-validate, todo-scraper, cpm todo, cpm xref, @see backfill)
- [x] ADR-138: Industry repository standards (top 50 analysis)
- [x] ADR-139: Scan gap analysis + implementation
- [x] ADR-140: Compliance framework mapping
- [x] ADR-141: Language coverage + supply chain
- [x] ADR-142: OWASP Top 10 coverage
- [x] ADR-143: Deep language support (design)
- [x] ADR-144: Diagram usage analysis
- [x] cpm score + badge + trend
- [x] cpm findings --learn / --compliance
- [x] Tool integrations (vale, alex, cspell, lychee)
- [x] Monorepo test detection fix
- [x] Scan language distribution + repo type
- [x] gcov files cleanup
- [x] Root folder reorganization (src, docs, .config)
- [x] docs/fixes → scripts
- [x] Screaming case docs renamed
