---
summary: Guardrails are cpm's core — progressive blocking by maturity, workflow templates (ITIL-like), AI-safe by design.
status: proposed
---

# ADR-136: Guardrails as Core

*Date*: 2026-05-19
*Related*: [ADR-026](adr-026-v-model-process-enforcement.md), [ADR-135](adr-135-two-modes-%E2%80%94-copilot-%28non-intrusive%29-vs-embedded-%28through-code%29.md)

## Context

cpm's unique value is not the checks — it's the **process enforcement**. Any tool can lint. Only cpm guides you through the right process, blocks shortcuts, and adapts to your maturity level.

## Decision

### Core principle

> You don't need to know the system. The system knows you.

Guardrails are always on. They get stricter as maturity increases. They're customizable per workflow type.

### Progressive blocking by maturity

| Level | What's blocked | What's allowed |
|-------|---------------|----------------|
| 0 | Nothing | Everything (learning mode) |
| 1 | Push without format | Direct commits |
| 2 | Code on main, push without lint | Feature branches |
| 3 | Code without tests, commit without issue ref | Unlock with reason |
| 4 | Merge without pipeline, skip review | Nothing without audit |
| 5 | Any bypass without approval | Full process only |

### Workflow templates (ITIL-inspired)

```toml
# cpm.toml
[workflows]
default = "feature"    # normal development

[workflows.feature]
phases = ["issue", "branch", "code+test", "check", "pr+merge"]

[workflows.hotfix]
phases = ["branch-from-main", "fix+test", "check", "pr+merge"]
# Skips: issue creation (urgency)

[workflows.p1]
phases = ["fix", "push", "postmortem"]
# Skips: branch, PR (emergency)
# Requires: postmortem within 24h

[workflows.docs]
phases = ["branch", "write", "push"]
# Skips: tests, issue (low risk)

[workflows.refactor]
phases = ["issue", "branch", "code", "check", "pr"]
# Allows: unlock for code-without-tests (moves only)
```

### AI-safe development

The guardrails are designed so that:

1. **Any LLM can follow the process** — each step has ONE clear action
2. **Hallucination is caught** — integrity checks at every gate
3. **Shortcuts are logged** — every unlock has a reason in audit trail
4. **Context is bounded** — each phase has limited scope (like a context window)

### Customization

```toml
# Override any phase's exit criteria
[phase.3]
require-tests = true          # default at level 3
require-tests = false         # disable for this project

# Add custom gates
[phase.custom]
name = "security-review"
after = "check"
command = "bash scripts/security-review.sh"
```

## Enforcement

| What | How | Automation |
|------|-----|-----------|
| Progressive blocking | `cpm phase check` reads maturity level | pre-commit hook |
| Workflow selection | `--workflow hotfix` flag or auto-detect | Branch naming |
| Audit trail | `.cpm/phase.log` | Every block/unlock logged |
| Customization | `cpm.toml [workflows]` | Config-driven |

## Consequences

### Positive

- Process is the product (not just checks)
- Works for any team size (solo → enterprise)
- AI agents can't take shortcuts
- ITIL-compatible without ITIL complexity
- Customizable without code changes

### Negative

- Can feel restrictive (that's the point)
- Unlock mechanism must be easy enough to not frustrate
- Workflow templates need testing per project type

## References

- @see ADR-026 (V-model enforcement)
- @see ADR-013 (product positioning — learning layer)
- @see ADR-020 (product vision)
- @see lib/shell/phase.sh (current implementation)
- @see lib/shell/guard.sh (command blocking)

## Sandbox Options (future — enforcement hardness)

| Method | Hardness | Portable | How |
|--------|----------|----------|-----|
| Pre-commit hook | Soft | ✅ All | Blocks commit, bypassable with --no-verify |
| Guard (shell alias) | Soft | ✅ All | Blocks commands, bypassable with `command` |
| chmod (file perms) | Medium | ⚠️ Unix | Read-only dirs per phase, fragile |
| Nix shell | Hard | ✅ macOS+Linux | Declarative sandbox, per-phase devShell |
| Docker/container | Hard | ✅ All | Mount paths read-only per phase |
| bubblewrap (bwrap) | Hard | Linux only | Lightweight namespace sandbox |
| macOS sandbox-exec | Hard | macOS only | Apple native sandbox profiles |
| OverlayFS | Hard | Linux only | Read-only base + writable overlay |

### Progression

```text
Level 0-2: Soft (hooks + guard)
Level 3-4: Medium (chmod + logged unlocks)
Level 5:   Hard (sandbox — nix/docker/bwrap)
```

### Nix concept

```nix
# Per-phase devShell with path restrictions
devShells.phase1 = mkShell { shellHook = "export CPM_PHASE=1"; };
devShells.phase3 = mkShell { shellHook = "export CPM_PHASE=3"; };
```

### Decision needed

- Which hardness level is default?
- Should AI agents always run in hard sandbox?
- How to handle emergency escape from hard sandbox?
