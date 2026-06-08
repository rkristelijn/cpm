#!/usr/bin/env bash
# checks/javascript/check-electron-security.sh
# Electron security anti-patterns per official checklist
# @see https://www.electronjs.org/docs/latest/tutorial/security
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-electron-security" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
cpm_has_dep "electron" "$REPO" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-36s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
finding_err() { printf "  \033[31merror\033[0m    %-36s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=$(cpm_find_src "$REPO")
[ -z "$SRC" ] && exit 0

# --- WEBPREFERENCES ---

# 1. nodeIntegration: true (RCE in renderer)
if grep -rn "nodeIntegration.*true" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "electron-sec-node-integration" "nodeIntegration: true — full RCE if renderer is compromised"
fi

# 2. contextIsolation: false
if grep -rn "contextIsolation.*false" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "electron-sec-no-ctx-isolation" "contextIsolation: false — preload globals leak to renderer"
fi

# 3. webSecurity: false (disables same-origin)
if grep -rn "webSecurity.*false" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "electron-sec-web-security-off" "webSecurity: false — same-origin policy disabled"
fi

# 4. allowRunningInsecureContent: true
if grep -rn "allowRunningInsecureContent.*true" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding_err "electron-sec-insecure-content" "allowRunningInsecureContent: true — HTTP scripts in HTTPS context"
fi

# 5. sandbox: false (explicitly disabling)
if grep -rn "sandbox.*false" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "electron-sec-sandbox-off" "sandbox: false — renderer has OS-level access"
fi

# 6. nodeIntegrationInWorker: true
if grep -rn "nodeIntegrationInWorker.*true" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding_err "electron-sec-node-in-worker" "nodeIntegrationInWorker: true — web workers can access Node"
fi

# 7. experimentalFeatures: true
if grep -rn "experimentalFeatures.*true" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-sec-experimental" "experimentalFeatures: true — unstable Chromium features"
fi

# 8. enableBlinkFeatures
if grep -rn "enableBlinkFeatures" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-sec-blink-features" "enableBlinkFeatures — bypasses feature gates"
fi

# --- IPC SECURITY ---

# 9. ipcRenderer.on exposed directly via contextBridge (leaks event object)
if grep -rn "ipcRenderer\.on" $SRC 2>/dev/null | grep -v node_modules | grep -E "expose|contextBridge" | head -1 | grep -q .; then
  finding_err "electron-sec-ipc-exposed" "ipcRenderer.on exposed directly — leaks IpcRendererEvent to renderer"
fi

# 10. No sender validation on IPC handlers
HANDLERS=$(grep -rn "ipcMain\.\(handle\|on\)" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | wc -l | tr -d ' ')
VALIDATED=$(grep -rn "event\.sender\|senderFrame\|event\.frameId" $SRC 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
if [ "${HANDLERS:-0}" -gt 0 ] && [ "${VALIDATED:-0}" -lt "$((HANDLERS / 2))" ] 2>/dev/null; then
  finding "electron-sec-ipc-no-sender" "IPC handlers without sender validation — any webContents can invoke"
fi

# --- NAVIGATION & WINDOW ---

# 11. No will-navigate handler (navigation hijack)
if ! grep -rl "will-navigate" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-sec-no-nav-handler" "No will-navigate handler — attacker can navigate app to malicious page"
fi

# 12. No setWindowOpenHandler (popup abuse)
if ! grep -rl "setWindowOpenHandler" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-sec-no-popup-handler" "No setWindowOpenHandler — unconstrained window.open() from renderer"
fi

# 13. shell.openExternal without URL validation
if grep -rn "shell\.openExternal" $SRC 2>/dev/null | grep -v "node_modules\|startsWith\|protocol\|allowedUrl\|isValid" | head -1 | grep -q .; then
  finding "electron-sec-open-external" "shell.openExternal without URL validation — arbitrary protocol launch"
fi

# 14. allowpopups on webview
if grep -rn "allowpopups" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-sec-webview-popups" "webview allowpopups — unrestricted popup creation"
fi

# --- CSP & PROTOCOL ---

# 15. No Content-Security-Policy
INDEX_FILES=$(find "$REPO" -name "index.html" -not -path "*/node_modules/*" -not -path "*/dist/*" 2>/dev/null || true)
if [ -n "$INDEX_FILES" ]; then
  HAS_CSP=$(echo "$INDEX_FILES" | xargs grep -l "Content-Security-Policy" 2>/dev/null | head -1 || true)
  [ -z "$HAS_CSP" ] && finding "electron-sec-no-csp" "No Content-Security-Policy — XSS/injection not mitigated"
fi

# 16. file:// protocol used to load remote content
if grep -rn "loadURL.*file://\|loadFile" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  # Only flag if there's also a loadURL with http (mixing protocols)
  if grep -rn "loadURL.*http" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    finding "electron-sec-mixed-protocol" "Mixing file:// and http:// — prefer custom protocol (protocol.handle)"
  fi
fi

# 17. Deprecated register*Protocol (use protocol.handle)
if grep -rn "registerFileProtocol\|registerBufferProtocol\|registerStringProtocol" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-sec-deprecated-proto" "register*Protocol deprecated — use protocol.handle() for security"
fi

# --- SECRETS & DATA ---

# 18. Hardcoded secrets in electron main process
if grep -rnE "(api[_-]?key|secret|token|password)\s*[:=]\s*['\"][a-zA-Z0-9_\-]{16,}['\"]" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\.\|\.env" | head -1 | grep -q .; then
  finding_err "electron-sec-hardcoded-secret" "Hardcoded secret in source — use keytar or env vars"
fi

# 19. Unsafe deserialization (JSON.parse on IPC data without validation)
if grep -rn "JSON\.parse.*ipc\|JSON\.parse.*event\.\|JSON\.parse.*message" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "electron-sec-unsafe-deser" "JSON.parse on IPC/message data — validate schema before parsing"
fi

# 20. require('electron') directly in renderer (bypasses isolation)
RENDERER=$(find $SRC -path "*/renderer*" \( -name "*.ts" -o -name "*.js" -o -name "*.vue" \) -not -path "*/node_modules/*" -not -name "*preload*" 2>/dev/null || true)
if [ -n "$RENDERER" ]; then
  if echo "$RENDERER" | xargs grep -l "require.*electron\|from 'electron'" 2>/dev/null | head -1 | grep -q .; then
    finding_err "electron-sec-require-renderer" "require('electron') in renderer — bypasses contextIsolation"
  fi
fi

if [ $FINDINGS -eq 0 ]; then
  echo "  ✓ Electron security checked"
else
  echo ""
  echo "  $FINDINGS Electron security finding(s)"
fi
