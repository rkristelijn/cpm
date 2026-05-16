<!-- Origin: workspace-tui -->
<!-- Status: Proposed (imported) -->

# ADR-001: Vision — Workspace TUI

*Status*: Accepted · *Date*: 2026-05-07

## Context

Managing tasks, calendar, and email across multiple workspace providers (Google, Microsoft, Proton, Apple) requires switching between web UIs, desktop apps, or inconsistent CLIs. Power users want:

- **CLI-first workflow** — scriptable, composable with other tools
- **AI integration** — read, plan, write, manage tasks with AI assistance
- **Provider-agnostic** — same interface for Google, Microsoft, Proton, Apple
- **Remote-friendly** — works over SSH, no GUI required
- **Best-practice workflows** — Covey-style planning (day/week/month/year)

Existing tools:
- `gcalcli`, `mutt`, `taskwarrior` — fragmented, no AI, no unified workflow
- Web UIs — not scriptable, not remote-friendly
- Desktop apps — not CLI-first, not provider-agnostic

## Decision

Build **workspace-tui**: a terminal user interface for workspace management with:

1. **Multi-provider support** — Google Workspace, Microsoft 365, Proton, Apple iCloud
2. **AI-powered workflows** — read/plan/write/manage with LLM assistance
3. **TUI interface** — keyboard-driven, panels, focus management
4. **CLI powers** — scriptable, pipeable, composable
5. **Best-practice planning** — Covey quadrants, day/week/month/year planning
6. **Remote-first** — works over SSH, no X11/Wayland required

## Problem it solves

**For power users:**
- Unified interface across providers
- Scriptable workflows (e.g., "show today's meetings + unread emails")
- AI-assisted planning and task management
- Remote access without VPN/desktop forwarding
- **Local backup + control** — throttled sync, keep cloud lean, store large files locally
- **Cleanup automation** — archive spam, status updates, old emails locally
- **Offline-first** — work without internet, sync when connected
- **Provider migration** — move from Gmail to Proton without losing your workflow
- **Vendor lock-in free** — your data, your rules, your provider

**For AI integration:**
- Read: "What's on my calendar today?"
- Plan: "Schedule focus time for project X"
- Write: "Draft email to team about Y"
- Manage: "Move task Z to next week"

**For best-practice workflows:**
- Covey quadrants: urgent/important matrix
- Time-blocking: plan day/week/month/year
- Review cycles: daily/weekly/monthly/yearly reflection

## Architecture principles

1. **Provider abstraction** — all providers implement same interface
2. **TUI library** — `blessed` (Node.js) for cross-platform TUI
3. **AI-ready** — structured data for LLM consumption/generation
4. **Testable** — BDD/TDD from day one
5. **Quality-driven** — linting, testing, coverage from start

## Success criteria

- [ ] Read calendar events from Google/Microsoft/Proton/Apple
- [ ] Read emails from Gmail/Outlook/Proton/iCloud
- [ ] Manage tasks across providers
- [ ] AI-powered planning workflows
- [ ] TUI with keyboard navigation
- [ ] CLI mode for scripting
- [ ] Works over SSH
- [ ] Local backup with throttled sync
- [ ] Cloud cleanup: archive spam/status updates locally, keep cloud lean
- [ ] Large file offload: move attachments to local storage

## Alternatives considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Extend existing tools | Mature, stable | Fragmented, no AI, no TUI | Rejected |
| Web app | Rich UI, accessible | Not CLI-first, not remote | Rejected |
| Desktop app | Native feel | Not remote-friendly | Rejected |
| CLI-only (no TUI) | Simple, scriptable | Poor UX for interactive use | Rejected |
| **TUI + CLI** | Best of both worlds | More complex | **Chosen** |

## Consequences

- Requires OAuth setup for each provider
- Node.js dependency for `blessed` TUI
- Provider APIs may have rate limits
- AI integration requires LLM API access

## References

- Covey's Time Management Matrix
- GTD (Getting Things Done)
- `gcalcli`, `mutt`, `taskwarrior` — prior art
- `blessed` — Node.js TUI library
