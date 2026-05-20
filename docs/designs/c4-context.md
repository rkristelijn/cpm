# C4 Context Diagram — cpm

Shows cpm's position in the developer ecosystem.

```mermaid
C4Context
    title System Context — cpm (code project maturity)

    Person(dev, "Developer", "Writes code, commits, pushes")
    Person(ci, "CI System", "GitHub Actions, GitLab CI, Jenkins")

    System(cpm, "cpm", "Quality layer between git and code. One binary, zero friction.")

    System_Ext(git, "Git", "Version control")
    System_Ext(remote, "Remote", "GitHub, GitLab, Bitbucket")
    System_Ext(tools, "Quality Tools", "gitleaks, semgrep, clang-format, eslint")
    System_Ext(findings_db, "Findings DB", "JSONL files in ~/.local/share/cpm/")

    Rel(dev, cpm, "Runs checks, scans repos, manages issues")
    Rel(cpm, git, "Installs hooks, reads history")
    Rel(cpm, tools, "Orchestrates (shell out)")
    Rel(cpm, findings_db, "Writes findings, reads for queries")
    Rel(cpm, remote, "Push/pull issues (via git)")
    Rel(ci, cpm, "Runs cpm check --full")
    Rel(git, remote, "Push/pull")
```

## Key relationships

| From | To | Interaction |
|------|-----|-------------|
| Developer | cpm | CLI commands (check, scan, init, issue) |
| cpm | Git | Hook installation, log parsing (DORA metrics) |
| cpm | Quality Tools | Shell out with timeout, parse output |
| cpm | Findings DB | JSONL append (write), query (read) |
| CI | cpm | `cpm check --full` in pipeline |
