
## Technical Debt

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