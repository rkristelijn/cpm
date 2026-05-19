#!/usr/bin/env bash
# check-runtime-eol.sh — Detect end-of-life runtimes before they become a security risk.
# @see ADR-129
#
# Checks Node.js, Python, Java versions against known EOL dates.
# Sources: package.json engines, .nvmrc, .python-version, Dockerfile, pom.xml
#
# Inspired by standard-components/typescript-runtime-processor

source "$(dirname "$0")/../../../lib/shell/check.sh"
FAIL=0

# Node.js EOL dates (update yearly) — only LTS matters
# https://endoflife.date/nodejs
declare -A NODE_EOL=(
  [16]="2023-09-11"
  [18]="2025-04-30"
  [20]="2026-04-30"
  [22]="2027-04-30"
)
NODE_MIN_SUPPORTED=20

# Python EOL
declare -A PYTHON_EOL=(
  [3.8]="2024-10-14"
  [3.9]="2025-10-05"
  [3.10]="2026-10-04"
  [3.11]="2027-10-24"
  [3.12]="2028-10-02"
)

# Detect Node version
detect_node() {
  local ver=""
  if [[ -f ".nvmrc" ]]; then
    ver=$(cat .nvmrc | grep -oE '[0-9]+' | head -1)
  elif [[ -f "package.json" ]]; then
    ver=$(grep -oE '"node":\s*"[^"]*"' package.json 2>/dev/null | grep -oE '[0-9]+' | head -1)
  elif [[ -f "Dockerfile" ]]; then
    ver=$(grep -i "FROM.*node:" Dockerfile 2>/dev/null | grep -oE 'node:([0-9]+)' | grep -oE '[0-9]+' | head -1)
  fi
  echo "$ver"
}

# Detect Python version
detect_python() {
  local ver=""
  if [[ -f ".python-version" ]]; then
    ver=$(cat .python-version | grep -oE '[0-9]+\.[0-9]+' | head -1)
  elif [[ -f "pyproject.toml" ]]; then
    ver=$(grep -oE 'python_requires.*[0-9]+\.[0-9]+' pyproject.toml 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
  fi
  echo "$ver"
}

# Check Node
NODE_VER=$(detect_node)
if [[ -n "$NODE_VER" ]]; then
  if [[ "$NODE_VER" -lt "$NODE_MIN_SUPPORTED" ]]; then
    findings_add "warning" "" "check-violation" "Node.js $NODE_VER is EOL — upgrade to $NODE_MIN_SUPPORTED+" "" ""
    FAIL=1
  else
    echo "  ✓ Node.js $NODE_VER (supported)"
  fi
fi

# Check Python
PY_VER=$(detect_python)
if [[ -n "$PY_VER" ]]; then
  eol="${PYTHON_EOL[$PY_VER]:-}"
  if [[ -n "$eol" ]]; then
    today=$(date +%Y-%m-%d)
    if [[ "$today" > "$eol" ]]; then
      findings_add "warning" "" "check-violation" "Python $PY_VER is EOL (since $eol) — upgrade" "" ""
      FAIL=1
    else
      echo "  ✓ Python $PY_VER (EOL: $eol)"
    fi
  fi
fi

# Check Java (from pom.xml or .java-version)
if [[ -f "pom.xml" ]]; then
  JAVA_VER=$(grep -oE '<java.version>[0-9]+</java.version>' pom.xml 2>/dev/null | grep -oE '[0-9]+' | head -1)
  if [[ -n "$JAVA_VER" && "$JAVA_VER" -lt 17 ]]; then
    findings_add "warning" "" "check-violation" "Java $JAVA_VER — only 17+ is actively supported" "" ""
    FAIL=1
  elif [[ -n "$JAVA_VER" ]]; then
    echo "  ✓ Java $JAVA_VER (supported)"
  fi
fi

[[ $FAIL -eq 0 && -z "$NODE_VER" && -z "$PY_VER" ]] && echo "  ✓ No runtime version files detected"
exit $FAIL
