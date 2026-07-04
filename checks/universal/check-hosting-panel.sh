#!/usr/bin/env bash
# checks/universal/check-hosting-panel.sh
# @see ADR-148
# Hosting panel detection: CyberPanel, CloudPanel, Webmin (critical CVEs), version EOL
set -o nounset -o pipefail

REPO="${1:-.}"

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

COMPOSE=""
[ -f "$REPO/docker-compose.yml" ] && COMPOSE="$REPO/docker-compose.yml"
[ -f "$REPO/docker-compose.yaml" ] && COMPOSE="$REPO/docker-compose.yaml"
DOCKERFILE=""
[ -f "$REPO/Dockerfile" ] && DOCKERFILE="$REPO/Dockerfile"

# --- 1. CyberPanel (CVE-2024-51378: CVSS 10.0, mass exploitation) ---
if [ -n "$COMPOSE" ] && grep -qi "cyberpanel" "$COMPOSE" 2>/dev/null; then
  error "panel-cyberpanel" "CyberPanel detected — CVE-2024-51378 (CVSS 10.0): 22,000 servers ransomwared. Ensure ≥ 2.3.8"
fi
[ -d "$REPO/usr/local/CyberPanel" ] && \
  error "panel-cyberpanel" "CyberPanel installation detected — verify version ≥ 2.3.8 (pre-auth RCE)"

# --- 2. CloudPanel (CVE-2023-35885: RCE < 2.3.1) ---
if [ -n "$COMPOSE" ] && grep -qi "cloudpanel" "$COMPOSE" 2>/dev/null; then
  error "panel-cloudpanel" "CloudPanel detected — CVE-2023-35885 (RCE < 2.3.1). Ensure latest version"
fi

# --- 3. Webmin/Virtualmin (CVE-2024-12828: RCE, ~1M installs) ---
if [ -n "$COMPOSE" ] && grep -qi "webmin\|virtualmin" "$COMPOSE" 2>/dev/null; then
  error "panel-webmin" "Webmin/Virtualmin detected — CVE-2024-12828 (RCE). Ensure ≥ 2.111"
fi
[ -f "$REPO/etc/webmin/config" ] && \
  error "panel-webmin" "Webmin configuration found — verify version ≥ 2.111 (CGI command injection RCE)"

# --- 4. Coolify (7 CVEs found 2025) ---
if [ -n "$COMPOSE" ] && grep -qi "coolify" "$COMPOSE" 2>/dev/null; then
  finding "panel-coolify" "Coolify detected — ensure latest version (7 CVEs disclosed 2025)"
fi

# --- 5. Docker socket exposure (container escape) ---
if [ -n "$COMPOSE" ]; then
  grep -qE "/var/run/docker\.sock" "$COMPOSE" 2>/dev/null && \
    finding "panel-docker-socket" "Docker socket mounted — container escape risk. Use Docker proxy if needed"
fi

# --- 6. Panel ports exposed without restriction ---
if [ -n "$COMPOSE" ]; then
  grep -qE '"8090:8090"|8090:8090' "$COMPOSE" 2>/dev/null && \
    finding "panel-port-exposed" "CyberPanel port 8090 exposed — restrict with firewall/IP whitelist"
  grep -qE '"10000:10000"|10000:10000' "$COMPOSE" 2>/dev/null && \
    finding "panel-port-exposed" "Webmin port 10000 exposed — restrict with firewall/IP whitelist"
  grep -qE '"8888:8888"|8888:8888' "$COMPOSE" 2>/dev/null && \
    finding "panel-port-exposed" "Panel port 8888 exposed — restrict with firewall/IP whitelist"
  grep -qE '"2087:2087"|2087:2087' "$COMPOSE" 2>/dev/null && \
    finding "panel-port-exposed" "cPanel/WHM port 2087 exposed — restrict with firewall"
fi

# --- 7. phpMyAdmin publicly accessible ---
if [ -n "$COMPOSE" ] && grep -qi "phpmyadmin" "$COMPOSE" 2>/dev/null; then
  if grep -qE '"80:|"8080:|"443:' "$COMPOSE" 2>/dev/null; then
    finding "panel-phpmyadmin-exposed" "phpMyAdmin exposed on public port — restrict access or use adminer with auth"
  fi
fi

[ "$FINDINGS" -eq 0 ] && exit 0
exit 0
