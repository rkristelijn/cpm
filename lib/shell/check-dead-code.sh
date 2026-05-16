#!/usr/bin/env bash
# check-dead-code.sh — Find shell functions that are never called
source lib/shell/init.sh 2>/dev/null || true
print_header "checking for dead code..."
# Find function definitions not referenced elsewhere
dead=0
while IFS= read -r func; do
  refs=$(grep -r "$func" lib/ scripts/ --include='*.sh' 2>/dev/null | grep -v "^.*:${func}()" | wc -l | tr -d ' ')
  if ((refs == 0)); then
    echo "  ⚠ unused: $func"
    dead=$((dead + 1))
  fi
done < <(grep -rh '^[a-z_]*()' lib/shell/*.sh 2>/dev/null | sed 's/().*//')
((dead == 0)) && echo "  ✓ no dead code found"
