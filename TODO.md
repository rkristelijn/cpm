
## Technical Debt

- [ ] Unify JUnit output: `cpm findings --junit` should read JSONL and produce JUnit XML (replace shell script with C++ binary capability)
- [ ] Duplicate function detection: `exports.sh --duplicates` to find same-named functions across files (possible code duplication)

## Features

- [ ] Add timeout support to cpm commands (global --timeout flag or per-command)
- [ ] Refactor Makefile to be facade-only (all logic in cpm binary)
- [ ] Design adapter pattern for issue tracker integration (GitHub, ClickUp, Jira)
  - Create `IssueProvider` interface
  - Implement `GitHubAdapter`, `ClickUpAdapter`, `JiraAdapter`
  - Use adapter pattern for extensibility
- [ ] ADR-126: Traceability by Design
  - Add `xref-validate` check
  - Add `todo-scraper` check
  - Add `cpm todo` command
  - Add `cpm xref` command
  - Backfill `@see` comments in existing code
  - See: docs/adrs/adr-126-traceability-by-design.md
