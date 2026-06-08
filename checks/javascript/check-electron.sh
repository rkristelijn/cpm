#!/usr/bin/env bash
# checks/javascript/check-electron.sh
# Electron quality/performance anti-patterns (NOT security — see check-electron-security.sh)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-electron" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
cpm_has_dep "electron" "$REPO" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-36s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=$(cpm_find_src "$REPO")
[ -z "$SRC" ] && exit 0

# --- PERFORMANCE ---

# 1. ipcRenderer.sendSync (blocks renderer)
if grep -rn "sendSync\|ipcRenderer\.sendSync" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "electron-sync-ipc" "sendSync blocks renderer — use invoke/handle async pattern"
fi

# 2. @electron/remote (10000x slower than IPC)
if grep -rn "require.*electron.*remote\|@electron/remote\|electron\.remote" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-remote-module" "remote module is deprecated — 10000x slower than IPC, causes leaks"
fi

# 3. BrowserWindow without show: false (white flash)
if grep -rn "new BrowserWindow" $SRC 2>/dev/null | grep -v "node_modules\|show.*false" | head -1 | grep -q .; then
  finding "electron-window-flash" "BrowserWindow without show: false — white flash on startup"
fi

# 4. Many synchronous fs operations blocking main
if grep -rn "readFileSync\|writeFileSync\|readdirSync" $SRC 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | grep -c "" 2>/dev/null | grep -qE "^[5-9]|^[0-9]{2}"; then
  finding "electron-sync-fs" "Many sync fs operations — blocks main process event loop"
fi

# 5. No app.whenReady() (startup race condition)
if grep -rn "app\.on.*ready" $SRC 2>/dev/null | grep -v "whenReady\|node_modules" | head -1 | grep -q .; then
  finding "electron-app-on-ready" "app.on('ready') — use app.whenReady() (awaitable, no race)"
fi

# 6. Event listener leak (no cleanup on window close)
if grep -rn "\.on('closed\|\.on(\"closed" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  HAS_CLEANUP=$(grep -rn "removeListener\|removeAllListeners\|win = null" $SRC 2>/dev/null | grep -v node_modules | head -1 || true)
  [ -z "$HAS_CLEANUP" ] && finding "electron-listener-leak" "Window 'closed' handler without listener cleanup — memory leak"
fi

# 7. No proper error handling on IPC
HANDLERS=$(grep -rn "ipcMain\.\(handle\|on\)" $SRC 2>/dev/null | grep -v "node_modules\|\.test\." | grep -c "" || echo "0")
TRY_CATCH=$(grep -rn "try\|catch\|throw" $SRC 2>/dev/null | grep -v node_modules | grep -c "" || echo "0")
if [ "${HANDLERS:-0}" -gt 5 ] && [ "${TRY_CATCH:-0}" -lt "$((HANDLERS / 2))" ] 2>/dev/null; then
  finding "electron-ipc-no-error" "IPC handlers without try/catch — unhandled errors crash main process"
fi

# 8. Large object passed over IPC (serialization cost)
if grep -rn "send\|invoke" $SRC 2>/dev/null | grep -v node_modules | grep -E "JSON\.stringify|\.getBlocks\(\)|\.contentState" | head -1 | grep -q .; then
  finding "electron-ipc-large-payload" "Large object sent over IPC — serialize selectively, not entire state"
fi

# 9. Multiple BrowserWindows without shared session
WINDOWS=$(grep -rn "new BrowserWindow" $SRC 2>/dev/null | grep -v node_modules | grep -c "" || echo "0")
if [ "${WINDOWS:-0}" -gt 3 ]; then
  if ! grep -rn "partition\|session\.fromPartition" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    finding "electron-no-session-share" "Multiple windows without shared session — memory overhead"
  fi
fi

# 10. No graceful shutdown (data loss)
if ! grep -rn "before-quit\|will-quit" $SRC 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "electron-no-graceful-quit" "No before-quit/will-quit handler — risk of data loss on close"
fi

if [ $FINDINGS -eq 0 ]; then
  echo "  ✓ Electron quality checked"
else
  echo ""
  echo "  $FINDINGS Electron quality finding(s)"
fi
