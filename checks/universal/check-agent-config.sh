#!/usr/bin/env bash
# check-agent-config.sh — Verify AI agent config has minimum useful content.
#
# Detects:
#   - Agent config exists but lacks build instructions
#   - Agent config exists but lacks test instructions
#   - Agent config exists but lacks architecture hints
#   - Agent config exists but lacks constraints/rules
#
# Agnostic: works with .kiro/, .amazonq/, .cursorrules, AGENTS.md,
# .github/copilot-instructions.md

source "$(dirname "$0")/../../lib/shell/check.sh"
WARN=0

# Find agent config content
CONTENT=""
if [[ -f "AGENTS.md" ]]; then
  CONTENT=$(cat AGENTS.md)
elif [[ -f ".cursorrules" ]]; then
  CONTENT=$(cat .cursorrules)
elif [[ -f ".github/copilot-instructions.md" ]]; then
  CONTENT=$(cat .github/copilot-instructions.md)
elif [[ -d ".kiro/agents" ]]; then
  CONTENT=$(cat .kiro/agents/*.json 2>/dev/null || true)
elif [[ -d ".amazonq" ]]; then
  CONTENT=$(cat .amazonq/*.md .amazonq/*.json 2>/dev/null || true)
fi

if [[ -z "$CONTENT" ]]; then
  echo "  [agent-config] skip — no agent config found"
  exit 0
fi

echo "  [agent-config] Checking agent config quality..."

# 1. Build instructions
if ! echo "$CONTENT" | grep -qiE '(make|build|compile|cargo|npm run|yarn|gradle|mvn|go build|g\+\+|gcc)'; then
  echo "  [agent-config] warning: no build instructions"
  echo "    why: AI agents won't know how to build your project"
  echo "    fix: add a build command (e.g. 'make build')"
  WARN=$((WARN + 1))
fi

# 2. Test instructions
if ! echo "$CONTENT" | grep -qiE '(test|verify|spec|check)'; then
  echo "  [agent-config] warning: no test instructions"
  echo "    why: AI agents won't verify their changes"
  echo "    fix: add a test command (e.g. 'make test')"
  WARN=$((WARN + 1))
fi

# 3. Architecture hints
if ! echo "$CONTENT" | grep -qiE '(src/|lib/|architecture|structure|entry.?point|directory|module)'; then
  echo "  [agent-config] warning: no architecture hints"
  echo "    why: AI agents need to understand project layout"
  echo "    fix: describe your directory structure"
  WARN=$((WARN + 1))
fi

# 4. Constraints/rules
if ! echo "$CONTENT" | grep -qiE "(don.t|never|avoid|rules|must not|forbidden|convention)"; then
  echo "  [agent-config] warning: no constraints or rules"
  echo "    why: AI agents need boundaries to avoid bad patterns"
  echo "    fix: add a 'Rules' or 'Don't' section"
  WARN=$((WARN + 1))
fi

if [[ $WARN -gt 0 ]]; then
  echo ""
  echo "  [agent-config] $WARN warning(s) — agent config could be more useful"
  exit 0
fi

echo "  [agent-config] pass — config has build, test, architecture, and rules"
