#!/usr/bin/env bash
# docs-generate.sh — Auto-generate documentation from code analysis.
#
# Generates:
#   1. Dependency graph (mermaid from #include/import)
#   2. Module overview (directory structure → mermaid component diagram)
#   3. CLI reference (from command dispatch or --help)
#   4. Install docs (from cpm.toml [tools] + detected package manager)
#   5. Doc coverage report (exported symbols vs documented)
#
# Usage: bash lib/shell/docs-generate.sh [output-dir]
#
# @see ADR-137

set -o nounset
set -o pipefail

OUT="${1:-.tmp/generated-docs}"
mkdir -p "$OUT"

# --- 1. Dependency Graph ---
generate_dep_graph() {
  local outfile="$OUT/dependency-graph.md"
  {
    echo "# Dependency Graph"
    echo ""
    echo '```mermaid'
    echo "flowchart LR"

    # C/C++ includes
    find src -name '*.cpp' -o -name '*.h' 2>/dev/null | while read -r f; do
      local base
      base=$(basename "$f" | sed 's/\.[^.]*$//')
      grep -h '#include "' "$f" 2>/dev/null | sed 's/#include "//;s/".*//' | while read -r dep; do
        echo "  ${base} --> $(basename "$dep" | sed 's/\.[^.]*$//')"
      done
    done | sort -u

    echo '```'
  } > "$outfile"
  echo "  ✓ $outfile"
}

# --- 2. Module Overview ---
generate_module_overview() {
  local outfile="$OUT/module-overview.md"
  {
    echo "# Module Overview"
    echo ""
    echo '```mermaid'
    echo "graph TD"
    if [ -d src ]; then
      for dir in src/*/; do
        [ -d "$dir" ] || continue
        local mod count
        mod=$(basename "$dir")
        count=$(find "$dir" -name '*.cpp' -o -name '*.h' -o -name '*.ts' -o -name '*.py' 2>/dev/null | wc -l | tr -d ' ')
        echo "  ${mod}[${mod} — ${count} files]"
      done
    fi
    echo '```'
    echo ""
    echo "## Files per module"
    echo ""
    if [ -d src ]; then
      for dir in src/*/; do
        [ -d "$dir" ] || continue
        echo "### $(basename "$dir")"
        echo ""
        echo "| File | Description |"
        echo "|------|-------------|"
        find "$dir" -maxdepth 1 -type f \( -name '*.cpp' -o -name '*.h' \) 2>/dev/null | sort | while read -r f; do
          local desc
          desc=$(head -5 "$f" | grep -oE '@brief .*|// .*—.*' | head -1 | sed 's/@brief //;s/^\/\/ //')
          printf "| \`%s\` | %s |\n" "$(basename "$f")" "${desc:-—}"
        done
        echo ""
      done
    fi
  } > "$outfile"
  echo "  ✓ $outfile"
}

# --- 3. CLI Reference ---
generate_cli_reference() {
  local outfile="$OUT/cli-reference.md"
  echo "# CLI Reference" > "$outfile"
  echo "" >> "$outfile"

  # Try to extract from cpm help output
  if command -v ./cpm >/dev/null 2>&1; then
    echo "Generated from \`cpm help\`:" >> "$outfile"
    echo "" >> "$outfile"
    echo '```' >> "$outfile"
    ./cpm help 2>/dev/null | tail -n +3 >> "$outfile" || true
    echo '```' >> "$outfile"
  # Or parse the usage() function from main.cpp
  elif [ -f src/main.cpp ]; then
    echo "Extracted from source:" >> "$outfile"
    echo "" >> "$outfile"
    echo "| Command | Description |" >> "$outfile"
    echo "|---------|-------------|" >> "$outfile"
    grep -E '^\s+"  ' src/main.cpp 2>/dev/null | sed 's/.*"  //;s/\\n".*//' | while read -r line; do
      local cmd desc
      cmd=$(echo "$line" | awk '{print $1}')
      desc=$(echo "$line" | sed "s/^[^ ]* *//;s/ *$//")
      [ -n "$cmd" ] && printf "| \`%s\` | %s |\n" "$cmd" "$desc" >> "$outfile"
    done
  fi
  echo "" >> "$outfile"
  echo "  ✓ $outfile"
}

# --- 4. Install Docs ---
generate_install_docs() {
  local outfile="$OUT/install.md"
  echo "# Installation" > "$outfile"
  echo "" >> "$outfile"

  # Detect project type and generate install instructions
  if [ -f cpm.toml ]; then
    echo "## Prerequisites" >> "$outfile"
    echo "" >> "$outfile"
    grep -E '^[a-z]+ =' cpm.toml 2>/dev/null | head -10 | while IFS='=' read -r tool version; do
      tool=$(echo "$tool" | tr -d ' ')
      version=$(echo "$version" | tr -d ' "')
      echo "- ${tool} ${version}+" >> "$outfile"
    done
    echo "" >> "$outfile"
  fi

  if [ -f package.json ]; then
    echo "## Install (Node.js)" >> "$outfile"
    echo "" >> "$outfile"
    echo '```bash' >> "$outfile"
    echo "npm install" >> "$outfile"
    echo '```' >> "$outfile"
  elif [ -f Makefile ]; then
    echo "## Build from source" >> "$outfile"
    echo "" >> "$outfile"
    echo '```bash' >> "$outfile"
    echo "make build" >> "$outfile"
    echo '```' >> "$outfile"
  elif [ -f Cargo.toml ]; then
    echo "## Build (Rust)" >> "$outfile"
    echo "" >> "$outfile"
    echo '```bash' >> "$outfile"
    echo "cargo build --release" >> "$outfile"
    echo '```' >> "$outfile"
  fi
  echo "" >> "$outfile"
  echo "  ✓ $outfile"
}

# --- 5. Doc Coverage Report ---
generate_doc_coverage() {
  local outfile="$OUT/doc-coverage.md"
  {
    echo "# Documentation Coverage"
    echo ""

    # C/C++: count public functions in .h files
    if find src -name '*.h' 2>/dev/null | grep -q .; then
      echo "## C/C++ API Surface"
      echo ""
      echo "| Header | Functions |"
      echo "|--------|-----------|"
      find src -name '*.h' 2>/dev/null | sort | while read -r h; do
        local funcs
        funcs=$(grep -cE '^[a-zA-Z].*\(' "$h" 2>/dev/null | head -1 || echo 0)
        [ "${funcs:-0}" -gt 0 ] 2>/dev/null && printf "| \`%s\` | %d |\n" "$(basename "$h")" "$funcs"
      done
      echo ""
    fi

    # Doc type coverage
    echo "## Doc Type Coverage"
    echo ""
    echo "| Type | Status |"
    echo "|------|--------|"
    [ -f README.md ] && echo "| README | ✓ |" || echo "| README | ✗ missing |"
    [ -f CONTRIBUTING.md ] && echo "| CONTRIBUTING | ✓ |" || echo "| CONTRIBUTING | ✗ missing |"
    [ -f CHANGELOG.md ] && echo "| CHANGELOG | ✓ |" || echo "| CHANGELOG | ✗ missing |"
    [ -f LICENSE ] && echo "| LICENSE | ✓ |" || echo "| LICENSE | ✗ missing |"
    [ -f SECURITY.md ] && echo "| SECURITY | ✓ |" || echo "| SECURITY | ✗ missing |"
    [ -d docs/adrs ] && echo "| ADRs | ✓ ($(find docs/adrs -name '*.md' 2>/dev/null | wc -l | tr -d ' \n') docs) |" || echo "| ADRs | ✗ missing |"
    [ -d docs/tutorials ] && echo "| Tutorials | ✓ |" || echo "| Tutorials | ✗ missing |"
    [ -d docs/api ] && echo "| API docs | ✓ |" || echo "| API docs | ✗ missing |"
    echo ""
  } > "$outfile"
  echo "  ✓ $outfile"
}

# --- Main ---
echo ""
echo "  Generating documentation..."
echo ""

generate_dep_graph
generate_module_overview
generate_cli_reference
generate_install_docs
generate_doc_coverage

echo ""
echo "  Done. Output in: $OUT/"
echo "  Files:"
ls -1 "$OUT"/*.md 2>/dev/null | sed 's/^/    /'
echo ""
