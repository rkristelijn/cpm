#!/usr/bin/env bash
# E2E test: check-electron + check-vue (security + quality)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

CHECKS_DIR="$(cd "$SCRIPT_DIR/../../checks/javascript" && pwd)"

echo "=== E2E: Electron + Vue checks ==="

# --- Electron security: should detect nodeIntegration ---
DIR=$(setup_project)
mkdir -p "$DIR/src"
cat > "$DIR/package.json" <<'EOF'
{ "dependencies": { "electron": "^42.0.0" } }
EOF
cat > "$DIR/src/main.ts" <<'EOF'
const win = new BrowserWindow({ webPreferences: { nodeIntegration: true } })
EOF
OUTPUT=$(bash "$CHECKS_DIR/check-electron-security.sh" "$DIR" 2>&1)
assert_contains "$OUTPUT" "electron-sec-node-integration" "should detect nodeIntegration: true"
teardown_project "$DIR"

# --- Electron security: clean project should pass ---
DIR=$(setup_project)
mkdir -p "$DIR/src"
cat > "$DIR/package.json" <<'EOF'
{ "dependencies": { "electron": "^42.0.0" } }
EOF
cat > "$DIR/src/main.ts" <<'EOF'
const win = new BrowserWindow({ webPreferences: { contextIsolation: true } })
win.webContents.on('will-navigate', (e) => e.preventDefault())
win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }))
EOF
OUTPUT=$(bash "$CHECKS_DIR/check-electron-security.sh" "$DIR" 2>&1)
assert_contains "$OUTPUT" "✓ Electron security checked" "clean project should pass"
teardown_project "$DIR"

# --- Electron quality: should detect sendSync ---
DIR=$(setup_project)
mkdir -p "$DIR/src"
cat > "$DIR/package.json" <<'EOF'
{ "dependencies": { "electron": "^42.0.0" } }
EOF
cat > "$DIR/src/renderer.ts" <<'EOF'
const result = ipcRenderer.sendSync('get-data')
EOF
OUTPUT=$(bash "$CHECKS_DIR/check-electron.sh" "$DIR" 2>&1)
assert_contains "$OUTPUT" "electron-sync-ipc" "should detect sendSync"
teardown_project "$DIR"

# --- Vue security: should detect v-html ---
DIR=$(setup_project)
mkdir -p "$DIR/src"
cat > "$DIR/package.json" <<'EOF'
{ "dependencies": { "vue": "^3.5.0" } }
EOF
cat > "$DIR/src/App.vue" <<'EOF'
<template><div v-html="userContent"></div></template>
EOF
OUTPUT=$(bash "$CHECKS_DIR/vue/check-vue-security.sh" "$DIR" 2>&1)
assert_contains "$OUTPUT" "vue-sec-v-html" "should detect v-html"
teardown_project "$DIR"

# --- Vue security: clean project should pass ---
DIR=$(setup_project)
mkdir -p "$DIR/src"
cat > "$DIR/package.json" <<'EOF'
{ "dependencies": { "vue": "^3.5.0" } }
EOF
cat > "$DIR/src/App.vue" <<'EOF'
<template><div>{{ safeText }}</div></template>
EOF
OUTPUT=$(bash "$CHECKS_DIR/vue/check-vue-security.sh" "$DIR" 2>&1)
assert_contains "$OUTPUT" "✓ Vue security checked" "clean vue project should pass"
teardown_project "$DIR"

# --- Vue quality: should detect bus.on without off ---
DIR=$(setup_project)
mkdir -p "$DIR/src"
cat > "$DIR/package.json" <<'EOF'
{ "dependencies": { "vue": "^3.5.0" } }
EOF
cat > "$DIR/src/Comp.vue" <<'EOF'
<script setup>
import bus from './bus'
bus.on('event', handler)
</script>
EOF
OUTPUT=$(bash "$CHECKS_DIR/vue/check-vue.sh" "$DIR" 2>&1)
assert_contains "$OUTPUT" "vue-event-bus-leak" "should detect bus.on without off"
teardown_project "$DIR"

# --- Skip: non-electron project should exit cleanly ---
DIR=$(setup_project)
mkdir -p "$DIR/src"
cat > "$DIR/package.json" <<'EOF'
{ "dependencies": { "react": "^19.0.0" } }
EOF
OUTPUT=$(bash "$CHECKS_DIR/check-electron-security.sh" "$DIR" 2>&1)
[[ -z "$OUTPUT" ]] || die "non-electron project should produce no output, got: $OUTPUT"
teardown_project "$DIR"

echo "=== All Electron + Vue check tests passed ==="
