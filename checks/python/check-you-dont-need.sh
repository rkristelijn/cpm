#!/usr/bin/env bash
# checks/python/check-you-dont-need.sh
# @see ADR-129
# "You Don't Need" for Python — deprecated packages, stdlib replacements
set -o nounset -o pipefail

REPO="${1:-.}"
SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -d "$REPO/lib" ] && SRC="${SRC:+$SRC }$REPO/lib"

# Detect Python project
REQS=""
[ -f "$REPO/requirements.txt" ] && REQS="$REPO/requirements.txt"
[ -f "$REPO/pyproject.toml" ] && REQS="${REQS:+$REQS }$REPO/pyproject.toml"
[ -f "$REPO/setup.py" ] && REQS="${REQS:+$REQS }$REPO/setup.py"
[ -f "$REPO/Pipfile" ] && REQS="${REQS:+$REQS }$REPO/Pipfile"
[ -z "$REQS" ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

ALL_DEPS=$(cat $REQS 2>/dev/null)

# =============================================
# DEPRECATED / DEAD
# =============================================

echo "$ALL_DEPS" | grep -qi "^nose\b\|\"nose\"" && error "dead-nose" "nose is dead (unmaintained since 2015) — use pytest"
echo "$ALL_DEPS" | grep -qi "pycrypto\b\|\"pycrypto\"" && error "dead-pycrypto" "pycrypto abandoned + security vulns — use pycryptodome or cryptography"
echo "$ALL_DEPS" | grep -qi "^fabric\b.*<2\|\"fabric\".*<2" && finding "dead-fabric1" "Fabric 1.x EOL — upgrade to Fabric 2+ or use paramiko"
echo "$ALL_DEPS" | grep -qi "optparse\b" && finding "dead-optparse" "optparse removed in 3.10 — use argparse (stdlib)"
echo "$ALL_DEPS" | grep -qi "imp\b" && finding "dead-imp" "imp module deprecated — use importlib"

# =============================================
# STDLIB REPLACEMENTS
# =============================================

# os.path → pathlib (Python 3.4+)
if [ -n "$SRC" ]; then
  if grep -rn "os\.path\." $SRC --include="*.py" 2>/dev/null | grep -v "test\|venv\|\.tox" | head -1 | grep -q .; then
    finding "py-use-pathlib" "os.path.* used — prefer pathlib.Path (cleaner, OO, Python 3.4+)"
  fi
fi

# subprocess.call → subprocess.run (Python 3.5+)
if [ -n "$SRC" ]; then
  if grep -rn "subprocess\.call\|subprocess\.Popen" $SRC --include="*.py" 2>/dev/null | grep -v "test\|venv" | head -1 | grep -q .; then
    finding "py-use-subprocess-run" "subprocess.call/Popen — prefer subprocess.run() (Python 3.5+, simpler)"
  fi
fi

# string formatting: % and .format() → f-strings (Python 3.6+)
if [ -n "$SRC" ]; then
  if grep -rn '% "\|% ('\|\.format(' $SRC --include="*.py" 2>/dev/null | grep -v "test\|venv\|logging" | head -1 | grep -q .; then
    finding "py-use-fstrings" "%-format or .format() — prefer f-strings (Python 3.6+, faster + readable)"
  fi
fi

# typing.Dict/List/Tuple → dict/list/tuple (Python 3.9+)
if [ -n "$SRC" ]; then
  if grep -rn "typing\.Dict\|typing\.List\|typing\.Tuple\|typing\.Set" $SRC --include="*.py" 2>/dev/null | grep -v "test\|venv" | head -1 | grep -q .; then
    finding "py-builtin-generics" "typing.Dict/List/Tuple — use dict/list/tuple directly (Python 3.9+)"
  fi
fi

# typing.Optional → X | None (Python 3.10+)
if [ -n "$SRC" ]; then
  if grep -rn "Optional\[" $SRC --include="*.py" 2>/dev/null | grep -v "test\|venv" | head -1 | grep -q .; then
    finding "py-union-syntax" "Optional[X] — use X | None (Python 3.10+, PEP 604)"
  fi
fi

# =============================================
# PACKAGES WITH NATIVE/BETTER ALTERNATIVES
# =============================================

# requests — httpx is more modern (async support, HTTP/2)
echo "$ALL_DEPS" | grep -qi "^requests\b\|\"requests\"" && \
  finding "py-requests-httpx" "requests — consider httpx (async, HTTP/2, drop-in API compatible)"

# python-dotenv — can use pydantic-settings or python -m env
echo "$ALL_DEPS" | grep -qi "python-dotenv\|\"python-dotenv\"" && \
  finding "py-dotenv" "python-dotenv — consider pydantic-settings for validated env with types"

# six (Python 2/3 compat layer)
echo "$ALL_DEPS" | grep -qi "^six\b\|\"six\"" && \
  error "dead-six" "six (Python 2 compat) — Python 2 is dead since 2020, remove"

# mock (separate package — in stdlib since 3.3)
echo "$ALL_DEPS" | grep -qi "^mock\b\|\"mock\"" && \
  finding "py-stdlib-mock" "mock package — use unittest.mock (stdlib since Python 3.3)"

# json — no external package needed
echo "$ALL_DEPS" | grep -qi "simplejson\|\"simplejson\"" && \
  finding "py-stdlib-json" "simplejson — stdlib json is fast enough for most cases since 3.6+"

# collections.OrderedDict → dict (Python 3.7+ dicts preserve order)
if [ -n "$SRC" ]; then
  if grep -rn "OrderedDict" $SRC --include="*.py" 2>/dev/null | grep -v "test\|venv" | head -1 | grep -q .; then
    finding "py-ordered-dict" "OrderedDict — plain dict preserves insertion order since Python 3.7"
  fi
fi

# =============================================
# TOOLING
# =============================================

# setup.py without pyproject.toml
if [ -f "$REPO/setup.py" ] && [ ! -f "$REPO/pyproject.toml" ]; then
  finding "py-use-pyproject" "setup.py without pyproject.toml — PEP 621/517 is the modern standard"
fi

# requirements.txt without constraints
if [ -f "$REPO/requirements.txt" ]; then
  if grep -q "^[a-zA-Z]" "$REPO/requirements.txt" | grep -v "==" | head -1 | grep -q . 2>/dev/null; then
    finding "py-unpin-deps" "Unpinned deps in requirements.txt — use pip freeze or poetry.lock"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Python: no unnecessary dependencies\n"
exit 0
