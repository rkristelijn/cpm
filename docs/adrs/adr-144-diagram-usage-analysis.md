# ADR-144: Diagram Usage in Top 500 Repos

> 🟠 **Status: Partially Implemented** — Mermaid diagrams are used in docs but automated diagram quality analysis was not built.

*Status*: Partially Implemented · *Date*: 2026-05-21 · *Author*: kiro

## Context

Analyzed diagram usage across 494 top-starred GitHub repos to determine which diagram tooling cpm should support.

## Findings (2026-05-21)

### Diagram format adoption

| Type | Repos | % of 494 | Diffable | Renders on GitHub |
|------|-------|----------|----------|-------------------|
| ASCII art (box-drawing) | 234 | 47% | Yes | Yes |
| PNG in docs/images | 131 | 27% | No | Yes (as image) |
| Mermaid (code blocks) | 91 | 18% | Yes | Yes (native) |
| SVG files | 90 | 18% | Partial | Yes |
| PlantUML | 8 | 2% | Yes | No (needs plugin) |
| DrawIO (.drawio) | 0 | 0% | No | No |
| D2 | 0 | 0% | Yes | No |
| Graphviz (.dot) | 1 | 0% | Yes | No |

### Mermaid diagram types (by usage count)

| Type | Occurrences | Use case |
|------|-------------|----------|
| flowchart | 5,136 | Architecture, process flows |
| journey | 1,960 | User journeys |
| sequenceDiagram | 1,953 | API interactions |
| graph | 1,879 | Dependencies, relationships |
| mindmap | 1,659 | Brainstorming, overviews |
| timeline | 1,124 | Roadmaps, history |
| stateDiagram-v2 | 841 | State machines |
| quadrantChart | 556 | Prioritization |
| pie | 462 | Distribution |
| classDiagram | 285 | OOP design |

### Repos with most mermaid diagrams

| Repo | Mermaid blocks | Type |
|------|---------------|------|
| Web-Dev-For-Beginners | 13,279 | Educational |
| mermaid | 1,573 | The tool itself |
| ai-agents-for-beginners | 649 | Educational |
| fastapi | 205 | Framework docs |
| next.js | 202 | Framework docs |
| warp | 104 | Terminal app |
| JavaGuide | 90 | Educational |
| netdata | 62 | Monitoring |
| n8n | 40 | Workflow automation |
| ultralytics | 36 | ML/AI |

## Decision

1. **Remove DrawIO support** from cpm — 0% adoption, not diffable
2. **Add mermaid syntax validation** — 18% adoption, growing, native on GitHub/GitLab
3. **Do NOT add PlantUML** — 2% adoption, declining
4. **ASCII art is fine** — no tooling needed, universal

## Consequences

- Remove `cmd_drawio` from cpm
- Add `docs-mermaid-syntax` check (validate mermaid blocks in .md files)
- Mermaid presence as positive maturity indicator
- Re-run this analysis periodically to track trends

## Reproduction

Script: `scripts/analyze-diagrams.sh`
