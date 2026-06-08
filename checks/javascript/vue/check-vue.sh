#!/usr/bin/env bash
# checks/javascript/vue/check-vue.sh
# Vue 3 anti-patterns: reactivity, composition API, templates, performance
# @see https://vuejs.org/guide/best-practices/
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-vue" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
cpm_has_dep "vue" "$REPO" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-36s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=$(cpm_find_src "$REPO")
[ -z "$SRC" ] && exit 0

VUE_FILES=$(find $SRC -name "*.vue" 2>/dev/null | grep -v node_modules || true)
TS_FILES=$(find $SRC \( -name "*.ts" -o -name "*.js" \) 2>/dev/null | grep -v node_modules || true)
[ -z "$VUE_FILES" ] && exit 0

# --- REACTIVITY ---

# 1. reactive() on primitive values (doesn't work)
if echo "$VUE_FILES $TS_FILES" | xargs grep -lE "reactive\((null|undefined|[0-9]+|true|false|'[^']*'|\"[^\"]*\")\)" 2>/dev/null | head -1 | grep -q .; then
  finding "vue-reactive-primitive" "reactive() on primitive — use ref() for non-object values"
fi

# 2. Destructuring reactive() (loses reactivity)
if echo "$VUE_FILES $TS_FILES" | xargs grep -E "const \{.*\} = reactive\(|let \{.*\} = reactive\(" 2>/dev/null | head -1 | grep -q .; then
  finding "vue-destructure-reactive" "Destructuring reactive() loses reactivity — use toRefs() or keep object"
fi

# 3. Replacing reactive() reference (breaks reactivity)
if echo "$VUE_FILES $TS_FILES" | xargs grep -E "^[[:space:]]*(state|data|form)\s*=\s*(reactive|{)" 2>/dev/null | grep -v "const\|let\|var" | head -1 | grep -q .; then
  finding "vue-reassign-reactive" "Reassigning reactive variable breaks reactivity — mutate properties instead"
fi

# 4. storeToRefs missing (destructuring Pinia store loses reactivity)
if echo "$VUE_FILES $TS_FILES" | xargs grep -E "const \{.*\} = use[A-Z].*Store\(\)" 2>/dev/null | grep -v "storeToRefs" | head -1 | grep -q .; then
  finding "vue-pinia-no-storeToRefs" "Destructuring store without storeToRefs() — state loses reactivity"
fi

# --- COMPOSITION API ---

# 5. bus.on() without bus.off() in onBeforeUnmount (memory leak)
BUS_ON_FILES=$(echo "$VUE_FILES" | xargs grep -l "bus\.on\|\.on(" 2>/dev/null | grep -v node_modules || true)
if [ -n "$BUS_ON_FILES" ]; then
  LEAKY=$(echo "$BUS_ON_FILES" | xargs grep -L "onBeforeUnmount\|onUnmounted\|bus\.off\|\.off(" 2>/dev/null | head -1 || true)
  [ -n "$LEAKY" ] && finding "vue-event-bus-leak" "bus.on() without matching off() in unmount — memory leak"
fi

# 6. watch() without cleanup / stop (in composables or setup)
if echo "$VUE_FILES $TS_FILES" | xargs grep -E "watch\(.*\{" 2>/dev/null | grep -v "onCleanup\|stop\(\)\|watchStop\|unwatch" | wc -l | grep -qE "^[1-9][0-9]"; then
  # Only flag if there are many watchers without cleanup
  finding "vue-watch-no-cleanup" "Multiple watchers without cleanup — check for leaked subscriptions"
fi

# 7. getCurrentInstance() in application code (internal API)
if echo "$VUE_FILES $TS_FILES" | xargs grep -l "getCurrentInstance" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-get-current-instance" "getCurrentInstance() is internal — use provide/inject or composables instead"
fi

# 8. Async operations in setup without onMounted
if echo "$VUE_FILES" | xargs grep -lE "await.*fetch\(|await.*axios|await.*api\." 2>/dev/null | head -3 | while read -r f; do
  grep -L "onMounted" "$f" 2>/dev/null
done | head -1 | grep -q .; then
  finding "vue-async-in-setup" "Async in setup() without onMounted — may run before DOM is ready"
fi

# --- TEMPLATE ---

# 9. v-if + v-for on same element
if echo "$VUE_FILES" | xargs grep -E "v-if.*v-for|v-for.*v-if" 2>/dev/null | head -1 | grep -q .; then
  finding "vue-vif-vfor" "v-if and v-for on same element — v-if evaluates per iteration in Vue 3"
fi

# 10. v-for without :key
if echo "$VUE_FILES" | xargs grep -l "v-for=" 2>/dev/null | while read -r f; do
  if grep -q "v-for=" "$f" && ! grep -q ":key\|v-bind:key" "$f"; then echo "$f"; fi
done | head -1 | grep -q .; then
  finding "vue-missing-key" "v-for without :key — causes incorrect DOM reuse on reorder"
fi

# 11. v-for with index as key
if echo "$VUE_FILES" | xargs grep -E ':key="(i|index|idx)"' 2>/dev/null | head -1 | grep -q .; then
  finding "vue-index-as-key" "v-for :key uses array index — causes bugs on reorder/delete"
fi

# 12. Mutating props directly
if echo "$VUE_FILES" | xargs grep -E "props\.[a-zA-Z]+\s*=" 2>/dev/null | grep -v "//\|defineProps\|interface" | head -1 | grep -q .; then
  finding "vue-prop-mutation" "Direct mutation of props — use emit() or local copy"
fi

# --- PERFORMANCE ---

# 13. querySelector/getElementById in reactive context (should cache)
if echo "$VUE_FILES" | xargs grep -E "(querySelector|getElementById).*\\\$\{|querySelector.*\+" 2>/dev/null | grep -v "//.*querySelector" | head -1 | grep -q .; then
  finding "vue-dom-query-in-loop" "Dynamic DOM query (string interpolation) — cache elements or use refs"
fi

# 14. N watchers pattern (watch inside v-for component without single parent watcher)
WATCHER_FILES=$(echo "$VUE_FILES" | xargs grep -l "watch(" 2>/dev/null || true)
if [ -n "$WATCHER_FILES" ]; then
  HEAVY=$(echo "$WATCHER_FILES" | xargs grep -l "v-for" 2>/dev/null | while read -r f; do
    COUNT=$(grep -c "watch(" "$f" 2>/dev/null || echo "0")
    [ "$COUNT" -gt 3 ] && echo "$f"
  done | head -1 || true)
  [ -n "$HEAVY" ] && finding "vue-n-watchers" "Component with v-for + many watchers — move watcher to parent"
fi

# 15. as any casts (type safety bypass)
ANY_COUNT=$(echo "$VUE_FILES $TS_FILES" | xargs grep -oh "as any" 2>/dev/null | wc -l | tr -d ' ')
if [ "${ANY_COUNT:-0}" -gt 10 ]; then
  finding "vue-as-any-casts" "$ANY_COUNT 'as any' casts — use proper types or type guards"
fi

# 16. import type used as value (InstanceType<typeof ImportedType>)
if echo "$VUE_FILES" | xargs grep -B2 "InstanceType<typeof" 2>/dev/null | grep -q "import type"; then
  finding "vue-type-as-value" "import type + typeof — use value import or framework instance type"
fi

# --- ELEMENT PLUS SPECIFIC ---

# 17. Circular data passed to el-tree (parent back-references)
if echo "$VUE_FILES" | xargs grep -l "el-tree\|ElTree" 2>/dev/null | while read -r f; do
  grep -q "node-key" "$f" && grep -q "parent" "$f" && ! grep -q "stripParent\|toRaw\|JSON.parse" "$f" && echo "$f"
done | head -1 | grep -q .; then
  finding "vue-eltree-circular" "el-tree data with parent refs — breaks node-key matching silently"
fi

# 18. (tree as any).store internal mutation
if echo "$VUE_FILES" | xargs grep -E "\(.*as any\)\.store|\.store\.nodesMap" 2>/dev/null | head -1 | grep -q .; then
  finding "vue-eltree-internal" "Mutating el-tree internal store — use public API methods"
fi

# --- PINIA ---

# 19. Store action called outside setup (loses HMR + devtools)
if echo "$TS_FILES" | xargs grep -E "use[A-Z].*Store\(\)" 2>/dev/null | grep -v "setup\|\.vue\|composable\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-pinia-outside-setup" "Pinia store used outside setup/composable — loses devtools + HMR"
fi

# 20. localStorage.getItem + JSON.parse on every call (no caching)
LS_FILES=$(echo "$VUE_FILES $TS_FILES" | xargs grep -l "localStorage\.\(getItem\|setItem\)" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." || true)
if [ -n "$LS_FILES" ]; then
  HEAVY_LS=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    COUNT=$(grep -c "localStorage\.getItem\|JSON\.parse" "$f" 2>/dev/null || true)
    COUNT="${COUNT##*:}"; COUNT="${COUNT:-0}"
    [ "$COUNT" -gt 3 ] && HEAVY_LS="$f" && break
  done <<< "$LS_FILES"
  [ -n "$HEAVY_LS" ] && finding "vue-localstorage-no-cache" "Frequent localStorage parse — cache in module scope, sync on write"
fi

if [ $FINDINGS -eq 0 ]; then
  echo "  ✓ Vue patterns checked"
else
  echo ""
  echo "  $FINDINGS Vue finding(s)"
fi
