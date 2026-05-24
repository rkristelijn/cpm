#!/usr/bin/env bash
# checks/javascript/vue/check-vue.sh
# Vue 3 anti-patterns: ref/reactive misuse, watch cleanup, v-for key, props mutation
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"vue"' "$REPO/package.json" || exit 0

findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/components" ] && SRC="$SRC $REPO/components/"
[ -d "$REPO/views" ] && SRC="$SRC $REPO/views/"
[ -z "$SRC" ] && exit 0

# ref() without .value in template (Vue 3 auto-unwraps in template but not in script)
while IFS= read -r file; do
  if grep -q "{{.*ref(" "$file" 2>/dev/null; then
    findings_add "warning" "vue-ref-missing-value" "ref() accessed without .value in template" \
      "Use {{ myRef }} in template (auto-unwrapped) or {{ myRef.value }} in script" \
      "https://vuejs.org/guide/essentials/reactivity-fundamentals.html"
  fi
done < <(find $SRC -name "*.vue" -o -name "*.js" -o -name "*.ts" 2>/dev/null)

# reactive() on primitives (doesn't work, should use ref)
while IFS= read -r file; do
  if grep -qE "reactive\((null|undefined|[0-9]+|'[^']*'|\"[^\"]*\")\)" "$file" 2>/dev/null; then
    findings_add "warning" "vue-reactive-primitive" "reactive() on primitive value" \
      "Use ref() for primitives: ref(0) instead of reactive(0)" \
      "https://vuejs.org/guide/essentials/reactivity-fundamentals.html"
  fi
done < <(find $SRC -name "*.vue" -o -name "*.js" -o -name "*.ts" 2>/dev/null)

# watch() without cleanup (memory leak)
while IFS= read -r file; do
  if grep -qE "watch\([^,]+,\s*\(" "$file" 2>/dev/null && ! grep -q "onUnmounted\|onBeforeUnmount" "$file" 2>/dev/null; then
    findings_add "warning" "vue-watch-no-cleanup" "watch() without cleanup function" \
      "Return cleanup function from watch callback to prevent memory leaks" \
      "https://vuejs.org/api/reactivity-core.html#watch"
  fi
done < <(find $SRC -name "*.vue" -o -name "*.js" -o -name "*.ts" 2>/dev/null)

# v-if + v-for on same element (performance issue)
while IFS= read -r file; do
  if grep -qE "v-if.*v-for|v-for.*v-if" "$file" 2>/dev/null; then
    findings_add "warning" "vue-vif-vfor" "v-if and v-for on same element" \
      "Use v-for on <template> wrapper with v-if inside for better performance" \
      "https://vuejs.org/guide/essentials/conditional.html#v-for-with-v-if"
  fi
done < <(find $SRC -name "*.vue" 2>/dev/null)

# Missing key on v-for
while IFS= read -r file; do
  if grep -qE "v-for=" "$file" 2>/dev/null && ! grep -q "v-bind:key\|:key" "$file" 2>/dev/null; then
    findings_add "warning" "vue-missing-key" "v-for without :key attribute" \
      "Always provide a unique :key for v-for to ensure proper DOM updates" \
      "https://vuejs.org/guide/essentials/list.html#maintaining-state-with-key"
  fi
done < <(find $SRC -name "*.vue" 2>/dev/null)

# Mutating props directly (anti-pattern)
while IFS= read -r file; do
  if grep -qE "props\.[a-zA-Z]+\s*=" "$file" 2>/dev/null; then
    findings_add "warning" "vue-prop-mutation" "Direct mutation of props" \
      "Props are readonly. Use emit to notify parent of changes" \
      "https://vuejs.org/guide/components/props.html#one-way-data-flow"
  fi
done < <(find $SRC -name "*.vue" 2>/dev/null)

# Large computed without memoization (computed is already memoized, but check for side effects)
while IFS= read -r file; do
  if grep -qE "computed\s*\(\s*\(\)\s*=>" "$file" 2>/dev/null; then
    lines=$(wc -l < "$file" 2>/dev/null || echo 0)
    if [ "$lines" -gt 200 ]; then
      findings_add "warning" "vue-large-computed" "Large computed function" \
        "Consider breaking down complex computed properties" \
        "https://vuejs.org/api/reactivity-core.html#computed"
    fi
  fi
done < <(find $SRC -name "*.vue" 2>/dev/null)

# No defineEmits typing (Vue 3 script setup)
while IFS= read -r file; do
  if grep -qE "script setup" "$file" 2>/dev/null && ! grep -qE "defineEmits|emits:" "$file" 2>/dev/null; then
    findings_add "warning" "vue-no-define-emits" "Missing defineEmits in script setup" \
      "Use defineEmits() to type emitted events for better IDE support" \
      "https://vuejs.org/api/sfc-script-setup.html#defineemits"
  fi
done < <(find $SRC -name "*.vue" 2>/dev/null)

# Options API mixed with Composition API in same file
while IFS= read -r file; do
  has_options=$(grep -qE "data\s*\(\)|methods:|computed:|watch:" "$file" 2>/dev/null && echo "yes")
  has_composition=$(grep -qE "script setup|setup\s*\(|ref\(|reactive\(|computed\(|watch\(" "$file" 2>/dev/null && echo "yes")
  if [ "$has_options" = "yes" ] && [ "$has_composition" = "yes" ]; then
    findings_add "warning" "vue-mixed-api" "Options API and Composition API mixed" \
      "Choose one pattern per component for consistency" \
      "https://vuejs.org/guide/introduction.html#api-styles"
  fi
done < <(find $SRC -name "*.vue" 2>/dev/null)

echo "  ✓ Vue patterns checked"