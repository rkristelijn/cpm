<!-- Origin: llama-cli -->
<!-- Status: Proposed (imported) -->

# ADR-072: Diagram Visualization Strategy & Element Limits

*Status*: Accepted

## Date

2026-05-02

## Context

The TUI renders mermaid code blocks as visual diagrams (ADR-070). With 6 diagram types now implemented, we need a clear strategy for:

- Which diagram types to support and how to render them
- Element limits to keep diagrams readable (no 40-item noise)
- What standard markdown already covers vs what needs mermaid/custom rendering
- Roadmap for missing diagram types

## Decision

### What markdown already covers (no diagram needed)

| Visualization | Markdown syntax | When to use |
|---|---|---|
| Tables | `\| col \| col \|` | Comparisons, data grids, matrices |
| Lists (nested) | `- item` / `1. item` | Hierarchies, steps, enumerations |
| Bold/italic | `**bold**` / `*italic*` | Emphasis within text |
| Blockquotes | `> text` | Callouts, notes, warnings |
| Horizontal rules | `---` | Section separators |

These render natively in the TUI without mermaid blocks.

### Implemented diagram types

| Type | Keyword | Rendering | Max elements |
|---|---|---|---|
| Flowchart | `graph TD/LR`, `flowchart` | Box-drawing (`┌─┐│└─┘`) with labels inside, `│` connectors | 12 nodes |
| Sequence | `sequenceDiagram` | ASCII columns with labeled arrows | 5 participants |
| Pie chart | `pie` | Horizontal bar chart (`█░`) with percentages | 10 slices |
| State | `stateDiagram-v2` | Delegates to flowchart box-drawing engine | 8 states |
| Venn | `venn` | Braille circles with ANSI colors, legend below | 3 sets (hard limit) |

### Element limits (readability constraints)

A diagram with too many elements becomes noise. The system prompt instructs the model to respect these limits. If data exceeds the limit, the model should group/aggregate.

| Diagram type | Hard limit | Reason |
|---|---|---|
| Flowchart nodes | 12 | Beyond 12, boxes become too narrow or wrap to multiple lines |
| Sequence participants | 5 | Beyond 5, the diagram exceeds 120 columns (standard terminal) |
| Pie slices | 10 | Beyond 10, bars become indistinguishable (all 1-block wide) |
| State nodes | 8 | Same as flowchart but linear chains get too tall |
| Venn sets | 3 | Geometric limit — 4+ overlapping circles are unreadable |

**Grouping strategy**: When data exceeds limits, the model should:

1. Group small items into "Other" (pie)
2. Collapse sub-processes into single nodes (flowchart)
3. Split into multiple diagrams with clear scope
4. Use a table instead if the diagram adds no structural insight

### Missing diagram types — roadmap

#### Priority 1: Easy wins (1-2 hours each)

| Type | Keyword | Rendering approach | Use case |
|---|---|---|---|
| **Gantt** | `gantt` | Horizontal time bars (reuse pie bar engine + date labels) | Project planning, timelines |
| **Mindmap** | `mindmap` | Tree with `├──` and `└──` (like `tree` command) | Brainstorming, topic exploration |
| **Quadrant** | `quadrantChart` | 2×2 grid with axis labels and items positioned | Prioritization (Eisenhower, effort/impact) |
| **Timeline** | `timeline` | Vertical list with `●──` markers and dates | History, release notes |

#### Priority 2: Medium effort (half day each)

| Type | Keyword | Rendering approach | Use case |
|---|---|---|---|
| **Class diagram** | `classDiagram` | Box-drawing boxes with sections (name/methods/props), lines between | Code architecture |
| **ER diagram** | `erDiagram` | Same engine as class, different parser (entities + relationships) | Database design |
| **XY chart** | `xychart-beta` | Braille dot plot with axis labels | Data trends, benchmarks |

#### Priority 3: Hard / low value

| Type | Keyword | Why deprioritized |
|---|---|---|
| Git graph | `gitGraph` | Branch merge layout is algorithmically complex |
| Sankey | `sankey-beta` | Proportional flow width doesn't work well in fixed-width terminal |
| C4 diagram | `C4Context` | Nested containers — complex layout, niche use case |

### Where mermaid falls short — alternatives

| Need | Mermaid gap | Alternative |
|---|---|---|
| Simple hierarchy | Flowchart is overkill for a tree | Use nested markdown lists or mindmap |
| Data comparison | Pie only shows proportions | Use markdown table with values |
| Matrix/grid | No native support | Use markdown table |
| Sparklines | No inline charts | Custom: `▁▂▃▅▇` Unicode block chars in text |
| Progress bars | No native support | Custom: `[████░░░░] 50%` inline |
| ASCII art | Freeform drawing | `text` code block (model draws manually) |

### Rendering architecture

```text
```mermaid block detected
       │
       ▼
DiagramRegistry.render(input)
       │
       ├── FlowchartRenderer  → box-drawing + connectors
       ├── SequenceRenderer   → ASCII columns + arrows
       ├── PieRenderer        → horizontal bar chart
       ├── StateRenderer      → delegates to flowchart
       ├── VennRenderer       → braille circles + colors
       ├── GanttRenderer      → (planned) time bars
       ├── MindmapRenderer    → (planned) tree lines
       ├── QuadrantRenderer   → (planned) 2×2 grid
       │
       └── no match → fallback: show as fenced code block
```text

Adding a new type = one `.h/.cpp` pair + register in `renderer.cpp`.

## Consequences

- Model is instructed (via system prompt) to use mermaid blocks and respect element limits
- Graceful degradation: unsupported types show as code blocks, not broken output
- Clear roadmap for contributors: easy wins first, hard problems last
- Element limits prevent unreadable diagrams — model groups/aggregates when data is large
- Markdown tables remain the go-to for structured data that doesn't need spatial relationships
