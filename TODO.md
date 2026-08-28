
## Cloud Provider IaC Coverage

Current: 13 IAC rules + 10 serverless rules — almost entirely AWS-focused.

Missing providers:

- [ ] **Azure** (~20 rules): azurerm_storage_account without HTTPS enforcement, NSG allow-all, AKS without RBAC, Key Vault soft-delete disabled, SQL Server without audit, App Service HTTP-only, missing Azure Defender, public IP on VMs, storage without private endpoint, managed identity not used
- [ ] **Google Cloud** (~15 rules): GCS bucket allUsers/allAuthenticatedUsers, GKE legacy ABAC, Cloud SQL without SSL, Compute firewall 0.0.0.0/0, KMS key rotation disabled, Cloud Run allUsers invoker, Pub/Sub without DLQ, Cloud Storage uniform bucket-level access, VPC flow logs disabled, IAM primitive roles (Owner/Editor)
- [ ] **Cloudflare** (~10 rules): WAF disabled, SSL mode not "full_strict", always_use_https off, security_level "essentially_off", minify disabled, no page rules for caching, DNS-only (no proxy), rate limiting absent, bot management off, missing origin CA certificate
- [ ] **DigitalOcean** (~5 rules): Droplet without VPC, firewall allow-all, spaces public access, no monitoring, DB without connection pool
- [ ] **Vercel/Netlify** (~5 rules): vercel.json without headers (CSP/HSTS), _headers file missing, redirect HTTP→HTTPS absent, env vars in vercel.json instead of dashboard, functions without memory/duration limits
- [ ] **Multi-cloud generic** (~10 rules): Terraform provider without version constraint, backend without encryption, no lifecycle prevent_destroy on stateful resources, output sensitive=true missing on secrets, data source without depends_on when needed, count vs for_each (count is index-fragile), missing moved blocks for refactoring

Prioriteit: Azure > GCP > Cloudflare > multi-cloud generic > DigitalOcean > Vercel/Netlify

## Rule Quality

- [ ] Add `content_contains` pre-filter to 365 existing rules that lack it (perf: ~30% scan speedup)
- [ ] Reduce noise on QUAL-021 (731 hits) — consider excluding closing ``` or only matching opening fences
- [ ] SH-QUAL-010 triple-counts per file (one finding per missing directive) — consider consolidating to one finding per file
- [ ] STYLE-042 (banner comments) — exclude .sh files where `# =====` separators are idiomatic
- [ ] A11Y rules (120): add HTML fixture files to cpm-eval so they're testable
- [ ] SECRETS rules (80): add token/key fixtures to cpm-eval for each secret type
- [ ] SCA-028 (committed git hooks) `content_contains: hooks` is too broad — matches any .sh with "hooks" in it, tighten to filenames or path-based targeting
- [ ] SCA-062 (unknown third-party action) fires on every `uses:` line — consider excluding known trusted orgs (actions/, github/, aws-actions/)
- [ ] Review subjective info-level rules: RS-QUAL-021 (Clone derive), RS-QUAL-035 (Vec capacity), TEST-019 (snapshot opinion) — keep or demote to `learn` level only?
- [ ] Fix git history: 219 commits with corporate email — consider `git filter-repo` to rewrite to <rkristelijn@gmail.com> (breaks forks/PRs)
- [ ] Move cpm-eval boilerplate rules (100 BP-* rules) into cpm/rules/ once validated on more repos
- [ ] Add duplicate-title detection to `cpm lint` — 7 rules share titles across languages (e.g. "Command injection via shell execution" in PY/PHP/RB/CS/JV)

## Technical Debt

- [ ] **Add strict mode to 62 shell scripts** — `SH-STRICT-002` dogfood found 62 scripts in `checks/`, `lib/shell/`, `scripts/`, and `install.sh` missing `set -o errexit -o nounset -o pipefail` in the first 10 lines. Run `./build/rule-scan . 2>&1 | grep SH-STRICT-002` to see the full list.
- [ ] Unify JUnit output: `cpm findings --junit` should read JSONL and produce JUnit XML (replace shell script with C++ binary capability)
- [ ] Duplicate function detection: `exports.sh --duplicates` to find same-named functions across files (possible code duplication)

## Features

- [ ] `cpm ai-steer` command: generate AI steering files for all known assistants (Kiro, Copilot, Claude, Cursor, Windsurf, Cline, Aider, Codex, Amazon Q, Tabnine, Junie, Augment, Cody) — see `scripts/generate-ai-steering.sh`
- [ ] Add timeout support to cpm commands (global --timeout flag or per-command)
- [ ] Refactor Makefile to be facade-only (all logic in cpm binary)
- [ ] Design adapter pattern for issue tracker integration (GitHub, ClickUp, Jira)
  - Create `IssueProvider` interface
  - Implement `GitHubAdapter`, `ClickUpAdapter`, `JiraAdapter`
  - Use adapter pattern for extensibility
- [x] ADR-126: Traceability by Design
  - [x] Add `xref-validate` check
  - [x] Add `todo-scraper` check
  - [x] Add `cpm todo` command
  - [x] Add `cpm xref` command
  - [x] Backfill `@see` comments in existing code (100% traceability)

## Done (this session)

- [x] ADR-138: Industry repository standards (top 50 analysis)
- [x] ADR-139: Scan gap analysis + implementation
- [x] ADR-140: Compliance framework mapping
- [x] ADR-141: Language coverage + supply chain
- [x] ADR-142: OWASP Top 10 coverage
- [x] ADR-143: Deep language support (design)
- [x] ADR-144: Diagram usage analysis
- [x] 58 checks (was 34)
- [x] cpm score + badge + trend
- [x] cpm findings --learn / --compliance
- [x] Tool integrations (vale, alex, cspell, lychee)
- [x] 5 failing tests fixed (10/10)
- [x] Monorepo test detection fix
- [x] Scan language distribution + repo type

## Manual found

- [x] remove all gcov files in root and find the cause, let it write in .tmp
- [x] too many root folders, code goes to src, (incl lib), docs go to docs, config goes to .config if possible, candidates: ./examples, ./Formula, ./checks, ./testgs, ./vendor, ./templates
- [x] why is there sh in docs (./docs/fixes) sh goes to scripts
- [x] duplicate documentation? ./docs/features and ./docs/checks
- [x] why screaming case items in ./docs/{PROCESS,ARCHITECTURE,CONVENTIONS}
