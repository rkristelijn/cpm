#!/usr/bin/env bash
# cpm:ignore-file SECRETS-039 SECRETS-040 SECRETS-041 SECRETS-045 — detector/test source: contains the patterns it checks for
# checks/universal/check-db-security.sh
# @see ADR-148
# Database security: default ports, weak passwords, root user, no SSL, version EOL
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/docker-compose.yml" ] || [ -f "$REPO/docker-compose.yaml" ] || [ -f "$REPO/.env" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

COMPOSE=""
[ -f "$REPO/docker-compose.yml" ] && COMPOSE="$REPO/docker-compose.yml"
[ -f "$REPO/docker-compose.yaml" ] && COMPOSE="$REPO/docker-compose.yaml"

if [ -n "$COMPOSE" ]; then
  # --- 1. Default ports exposed to host ---
  grep -qE '"3306:3306"|3306:3306' "$COMPOSE" 2>/dev/null && \
    finding "db-default-port-mysql" "MySQL port 3306 exposed directly — use internal network or non-default port"
  grep -qE '"5432:5432"|5432:5432' "$COMPOSE" 2>/dev/null && \
    finding "db-default-port-pg" "PostgreSQL port 5432 exposed directly — use internal network or non-default port"
  grep -qE '"27017:27017"|27017:27017' "$COMPOSE" 2>/dev/null && \
    finding "db-default-port-mongo" "MongoDB port 27017 exposed directly — use internal network"

  # --- 2. Empty/default password ---
  grep -qE "MYSQL_ALLOW_EMPTY_PASSWORD.*yes|MYSQL_ALLOW_EMPTY_PASSWORD.*true" "$COMPOSE" 2>/dev/null && \
    error "db-empty-password" "MYSQL_ALLOW_EMPTY_PASSWORD enabled — never allow empty passwords"
  grep -qE "MYSQL_ROOT_PASSWORD:\s*(root|password|admin|mysql|123)" "$COMPOSE" 2>/dev/null && \
    error "db-weak-password" "Weak/default MySQL root password in docker-compose"
  grep -qE "POSTGRES_PASSWORD:\s*(postgres|password|admin|123)" "$COMPOSE" 2>/dev/null && \
    error "db-weak-password-pg" "Weak/default PostgreSQL password in docker-compose"

  # --- 3. Database version EOL ---
  # MySQL 5.7 EOL Oct 2023
  grep -qE "mysql:5\.7|mysql:5\.6|mariadb:10\.5|mariadb:10\.4" "$COMPOSE" 2>/dev/null && \
    error "db-version-eol" "Database version is EOL — MySQL 5.7 (Oct 2023), MariaDB 10.5 (Jun 2025)"
  # PostgreSQL 12/13 EOL
  grep -qE "postgres:12|postgres:13|postgresql:12|postgresql:13" "$COMPOSE" 2>/dev/null && \
    error "db-version-eol-pg" "PostgreSQL 12 (EOL Nov 2024) or 13 (EOL Nov 2025) detected — upgrade to 15+"

  # --- 4. No healthcheck on database ---
  # Simple heuristic: if there's a db service but no healthcheck
  if grep -qE "mysql|postgres|mariadb|mongo" "$COMPOSE" 2>/dev/null; then
    if ! grep -q "healthcheck" "$COMPOSE" 2>/dev/null; then
      finding "db-no-healthcheck" "No healthcheck on database container — app may start before DB is ready"
    fi
  fi
fi

# --- 5. Root user in .env ---
if [ -f "$REPO/.env" ]; then
  grep -qE "^DB_USERNAME=root|^DB_USER=root" "$REPO/.env" 2>/dev/null && \
    finding "db-root-user" "DB_USERNAME=root in .env — use a dedicated application user"
fi

# --- 6. No SSL/TLS for database connection ---
if [ -f "$REPO/.env" ]; then
  if grep -qE "^DB_HOST=|^DATABASE_URL=" "$REPO/.env" 2>/dev/null; then
    if ! grep -qE "sslmode=require|ssl=true|MYSQL_SSL|useSSL=true" "$REPO/.env" 2>/dev/null; then
      finding "db-no-ssl" "No SSL/TLS configured for database connection"
    fi
  fi
fi

# --- 7. Hardcoded connection string in source code ---
SRC_FILES=$(find "$REPO" -name "*.py" -o -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.java" 2>/dev/null | grep -v "vendor\|node_modules\|\.venv\|venv\|test\|spec" | head -200)
if [ -n "$SRC_FILES" ]; then
  echo "$SRC_FILES" | xargs grep -lnE "mysql://.*:.*@|postgres://.*:.*@|mongodb://.*:.*@" 2>/dev/null | head -1 | grep -q . && \
    error "db-hardcoded-url" "Database connection string with password in source code — use environment variable"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Database security OK"
exit 0
