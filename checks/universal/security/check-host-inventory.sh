#!/usr/bin/env bash
# check-host-inventory.sh - Generate infrastructure SBOM (OS, packages, drivers, Docker).
# @see ADR-129
#
# Unlike check-sbom (scans a code project), this scans the HOST SYSTEM.
# Intended for server/infra machines managed by Ansible or similar.
#
# Requires: python3, optionally syft + grype
# Output: .tmp/host-inventory.json
#         .tmp/host-sbom.json (if syft available)
#         .tmp/host-cves.json (if --scan flag and grype available)
#
# Usage:
#   check-host-inventory.sh          # inventory only
#   check-host-inventory.sh --scan   # inventory + CVE scan

source "$(dirname "$0")/../../../lib/shell/check.sh"

OUTPUT_DIR=".tmp"
INVENTORY="$OUTPUT_DIR/host-inventory.json"
HOST_SBOM="$OUTPUT_DIR/host-sbom.json"
HOST_CVES="$OUTPUT_DIR/host-cves.json"
mkdir -p "$OUTPUT_DIR"

SCAN_CVES=false
[[ "${1:-}" == "--scan" ]] && SCAN_CVES=true

# 1. System inventory
if ! command -v python3 >/dev/null 2>&1; then
  echo "  [skip] python3 required for host-inventory"
  exit 0
fi

python3 << 'PYEOF'
import json, subprocess, platform, os

def cmd(c):
    try:
        return subprocess.check_output(c, shell=True, stderr=subprocess.DEVNULL).decode().strip()
    except:
        return ""

inv = {
    "hostname": platform.node(),
    "date": cmd("date -Iseconds"),
    "os": {
        "name": cmd("lsb_release -si") or platform.system(),
        "version": cmd("lsb_release -sr") or platform.release(),
        "codename": cmd("lsb_release -sc"),
        "kernel": platform.release(),
        "arch": platform.machine(),
    },
    "packages": {
        "dpkg": int(cmd("dpkg -l 2>/dev/null | grep -c '^ii'") or 0),
        "snap": int(cmd("snap list 2>/dev/null | tail -n +2 | wc -l") or 0),
        "flatpak": int(cmd("flatpak list 2>/dev/null | wc -l") or 0),
        "pip": int(cmd("pip list 2>/dev/null | tail -n +3 | wc -l") or 0),
    },
    "kernel_modules": {
        "count": int(cmd("lsmod 2>/dev/null | tail -n +2 | wc -l") or 0),
    },
    "docker": {
        "images": [
            line for line in
            cmd("docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null").splitlines()
            if line and "<none>" not in line
        ],
        "containers": [
            line for line in
            cmd("docker ps --format '{{.Names}} ({{.Image}}): {{.Status}}' 2>/dev/null").splitlines()
            if line
        ],
    },
    "usb_devices": cmd("lsusb 2>/dev/null").splitlines(),
    "listening_ports": [
        line.split() for line in
        cmd("ss -tlnp 2>/dev/null | tail -n +2").splitlines()
        if line
    ],
    "disk_mounts": cmd("df -P 2>/dev/null | grep '^/dev'").splitlines(),
    "uptime": cmd("uptime -p 2>/dev/null"),
}

with open(os.environ.get("INVENTORY_OUT", ".tmp/host-inventory.json"), "w") as f:
    json.dump(inv, f, indent=2)

pkgs = inv["packages"]["dpkg"]
imgs = len(inv["docker"]["images"])
mods = inv["kernel_modules"]["count"]
print(f"  Host inventory: {pkgs} packages, {imgs} Docker images, {mods} kernel modules")
PYEOF

# 2. OS package SBOM (syft)
if command -v syft >/dev/null 2>&1; then
  echo "  Generating OS SBOM..."
  syft dir:/ --catalogers dpkg -o cyclonedx-json="$HOST_SBOM" --quiet 2>/dev/null
  count=$(grep -c '"bom-ref"' "$HOST_SBOM" 2>/dev/null || echo "0")
  echo "  OS SBOM: $count components"
else
  echo "  [skip] syft not installed - OS SBOM skipped"
fi

# 3. Docker image SBOMs
if command -v syft >/dev/null 2>&1 && command -v docker >/dev/null 2>&1; then
  echo "  Scanning Docker images..."
  docker_dir="$OUTPUT_DIR/docker-sboms"
  mkdir -p "$docker_dir"
  count=0
  for img in $(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>'); do
    safe=$(echo "$img" | tr '/:' '__')
    syft "$img" -o cyclonedx-json="$docker_dir/$safe.json" --quiet 2>/dev/null && ((count++)) || true
  done
  echo "  Docker SBOMs: $count images"
fi

# 4. CVE scan (--scan flag)
if $SCAN_CVES; then
  if command -v grype >/dev/null 2>&1; then
    echo "  Running CVE scan..."
    if [[ -f "$HOST_SBOM" ]]; then
      grype "sbom:$HOST_SBOM" -o json > "$HOST_CVES" 2>/dev/null
      critical=$(grep -c '"Critical"' "$HOST_CVES" 2>/dev/null || echo "0")
      high=$(grep -c '"High"' "$HOST_CVES" 2>/dev/null || echo "0")
      medium=$(grep -c '"Medium"' "$HOST_CVES" 2>/dev/null || echo "0")
      low=$(grep -c '"Low"' "$HOST_CVES" 2>/dev/null || echo "0")
      echo "  CVEs: $critical critical, $high high, $medium medium, $low low"
      [[ "$critical" -gt 0 ]] && exit 1
    fi
  else
    echo "  [skip] grype not installed - CVE scan skipped"
  fi
fi
