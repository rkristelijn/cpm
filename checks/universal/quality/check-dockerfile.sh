#!/usr/bin/env bash
# checks/universal/quality/check-dockerfile.sh
# Dockerfile best practices from docs.docker.com/build/building/best-practices
# Source: Docker official documentation (2026)
source "$(dirname "$0")/../../../lib/shell/check.sh"
set -o nounset -o pipefail

REPO="${1:-.}"
DOCKERFILES=$(find "$REPO" -maxdepth 3 -name "Dockerfile*" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)
[ -z "$DOCKERFILES" ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

for df in $DOCKERFILES; do
  # --- Running as root (no USER instruction) ---
  grep -q "^USER " "$df" || finding "docker-no-user" "No USER instruction — container runs as root ($df)"

  # --- No .dockerignore ---
  dir=$(dirname "$df")
  [ ! -f "$dir/.dockerignore" ] && [ ! -f "$REPO/.dockerignore" ] && \
    finding "docker-no-ignore" "No .dockerignore — build context includes unnecessary files"

  # --- Using ADD instead of COPY (without URL/tar) ---
  if grep -q "^ADD " "$df" 2>/dev/null; then
    BAD=$(grep "^ADD " "$df" | grep -v "http\|https\|\.tar\|\.gz\|--checksum" || true)
    [ -n "$BAD" ] && finding "docker-add-vs-copy" "ADD used without URL/tar — use COPY for local files ($df)"
  fi

  # --- No multi-stage build (large images) ---
  FROMS=$(grep -c "^FROM " "$df" 2>/dev/null || echo 0)
  [ "$FROMS" -eq 1 ] && finding "docker-no-multistage" "Single FROM — consider multi-stage build to reduce image size ($df)"

  # --- apt-get update without install in same RUN ---
  if grep -q "apt-get update" "$df" 2>/dev/null; then
    BAD=$(grep -n "apt-get update" "$df" | while read -r line; do
      num=$(echo "$line" | cut -d: -f1)
      grep -A1 "^${num}:" "$df" | grep -q "apt-get install" || echo "$num"
    done)
    # Simpler check: separate RUN for update vs install
    grep -q "^RUN apt-get update$" "$df" && \
      finding "docker-split-apt" "apt-get update in separate RUN — combine with install to avoid cache issues"
  fi

  # --- No HEALTHCHECK ---
  grep -q "^HEALTHCHECK " "$df" || finding "docker-no-healthcheck" "No HEALTHCHECK — orchestrators can't detect unhealthy containers ($df)"

  # --- Using latest tag ---
  grep "^FROM.*:latest" "$df" >/dev/null 2>&1 && \
    error "docker-latest-tag" "FROM :latest — pin base image version for reproducible builds ($df)"

  # --- Running as root with apt/yum (no cleanup) ---
  if grep -q "apt-get install\|yum install\|apk add" "$df" 2>/dev/null; then
    grep -q "rm -rf /var/lib/apt\|rm -rf /var/cache\|--no-cache" "$df" || \
      finding "docker-no-cleanup" "Package install without cache cleanup — increases image size ($df)"
  fi

  # --- COPY . . without .dockerignore (copies everything) ---
  grep -q "^COPY \. \." "$df" 2>/dev/null && [ ! -f "$REPO/.dockerignore" ] && \
    error "docker-copy-all" "COPY . . without .dockerignore — copies secrets, node_modules, .git ($df)"

  # --- Hardcoded secrets/passwords ---
  grep -qiE "PASSWORD|SECRET|API_KEY|TOKEN" "$df" 2>/dev/null && \
    grep -qiE "ENV.*=|ARG.*=" "$df" 2>/dev/null && \
    error "docker-hardcoded-secret" "Potential secret in ENV/ARG — use build secrets or runtime env ($df)"
done

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Dockerfile best practices: all checks passed\n"
exit 0
