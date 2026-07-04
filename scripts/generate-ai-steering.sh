#!/usr/bin/env bash
set -euo pipefail

# Generate AI steering/instruction files for all known AI coding assistants.
# Each file points to CONTRIBUTING.md as the single source of truth.

MSG="Follow the guidelines in CONTRIBUTING.md and docs/design-specs/requirements.md"

# AGENTS.md is the universal standard (agents.md spec, 60k+ repos)
# Tools that read it natively: Codex, Cursor, Jules, Gemini CLI, VS Code,
# JetBrains Junie, Aider, Windsurf, Augment, Factory, Devin, Zed, Warp, etc.
# We still generate tool-specific files for tools that prefer their own location.

declare -A FILES=(
  # Universal (agents.md standard)
  ["AGENTS.md"]="# AGENTS.md\n\n${MSG}"
  # Kiro
  [".kiro/steering/base.md"]="# Base\n\n${MSG}"
  # GitHub Copilot
  [".github/copilot-instructions.md"]="${MSG}"
  # Claude Code
  ["CLAUDE.md"]="${MSG}"
  # Cursor
  [".cursor/rules/base.md"]="${MSG}"
  # Windsurf
  [".windsurfrules"]="${MSG}"
  # Cline
  [".clinerules"]="${MSG}"
  # Aider
  [".aider.conf.yml"]="# Aider config\nread: [AGENTS.md, CONTRIBUTING.md]"
  # Codex (OpenAI)
  ["codex.md"]="${MSG}"
  # Amazon Q Developer
  [".amazonq/rules/base.md"]="${MSG}"
  # Tabnine
  [".tabnine.yaml"]="# Tabnine\n# ${MSG}"
  # JetBrains Junie
  [".junie/guidelines.md"]="${MSG}"
  # Augment
  [".augment/rules/base.md"]="${MSG}"
  # Sourcegraph Cody
  [".cody/instructions.md"]="${MSG}"
  # Gemini CLI
  [".gemini/settings.json"]="{ \"context\": { \"fileName\": \"AGENTS.md\" } }"
)

for path in "${!FILES[@]}"; do
  dir=$(dirname "$path")
  [ "$dir" != "." ] && mkdir -p "$dir"
  printf '%b\n' "${FILES[$path]}" >"$path"
  echo "✓ $path"
done

echo ""
echo "Done. All AI steering files point to CONTRIBUTING.md"
