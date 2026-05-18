#!/usr/bin/env bash
# commit.sh — Interactive conventional commit helper.
# Usage: cpm commit
set -o errexit
set -o nounset
set -o pipefail

# Analyze staged files
STAGED=$(git diff --cached --name-only 2>/dev/null)
HAS_SRC=$(echo "$STAGED" | grep -c '^src/' || true)
HAS_TEST=$(echo "$STAGED" | grep -c '_test\|test_\|\.test\.' || true)
HAS_DOCS=$(echo "$STAGED" | grep -c '\.md$\|docs/' || true)
STAGED_COUNT=$(echo "$STAGED" | grep -c '.' || true)

echo ""
echo "  Staged ($STAGED_COUNT files):  [ctrl-c to abort]"
echo "$STAGED" | head -8 | sed 's/^/    /'
((STAGED_COUNT > 8)) && echo "    ... +$((STAGED_COUNT - 8)) more"
echo ""

# Warnings / enforcement
LEVEL=$(grep -A2 '^\[enforcement\]' cpm.toml 2>/dev/null | sed -n 's/^level *= *"\(.*\)"/\1/p')
LEVEL="${LEVEL:-guide}"

if ((HAS_SRC > 0 && HAS_TEST == 0)); then
  echo "  ⚠ Code changed but no tests staged"
fi
if ((HAS_SRC > 0 && HAS_DOCS == 0)); then
  echo "  ⚠ Code changed but no docs staged"
fi

if ((HAS_SRC > 0 && (HAS_TEST == 0 || HAS_DOCS == 0))); then
  echo ""
  if [[ "$LEVEL" == "enforce" ]]; then
    echo "  ✗ Blocked: enforcement=enforce requires tests+docs with code changes."
    echo "    Stage tests/docs, or: cpm set enforcement.level guard"
    exit 1
  elif [[ "$LEVEL" == "guard" ]]; then
    if ((HAS_TEST == 0)); then
      echo "  ✗ Blocked: enforcement=guard requires tests with code changes."
      echo "    Stage tests, or: cpm set enforcement.level guide"
      exit 1
    fi
  fi
fi

if ((STAGED_COUNT == 0)); then
  echo "  Nothing staged. Use: git add <files>"
  exit 1
fi

# Type
echo "  f)fix a)feat r)refactor d)docs"
echo "  t)test b)build c)ci p)perf s)style x)chore"
printf "  Type [f]: "
read -r k
case "${k:-f}" in
f) T=fix ;; a) T=feat ;; r) T=refactor ;; d) T=docs ;;
t) T=test ;; b) T=build ;; c) T=ci ;; p) T=perf ;;
s) T=style ;; x) T=chore ;; *) T=fix ;;
esac

# Scope
printf "  Scope (enter=none): "
read -r S

# Description
echo "  Imperative: add X, fix Y, remove Z"
printf "  Desc: "
read -r D
[[ -z "$D" ]] && { echo "  Required."; exit 1; }

# Breaking?
printf "  Breaking? [y/N]: "
read -r B
BP=""
[[ "$B" =~ ^[yY] ]] && BP="!"

# Build message + confirm
[[ -n "$S" ]] && LINE="${T}${BP}(${S}): ${D}" || LINE="${T}${BP}: ${D}"
echo ""
echo "  → $LINE"
printf "  Commit? [Y/n]: "
read -r C
[[ "$C" =~ ^[nN] ]] && { echo "  Aborted."; exit 0; }

git commit -m "$LINE"
