#!/usr/bin/env bash
# checks/php/wordpress/check-wordpress-hardening.sh
# @see ADR-148
# WordPress hardening: wp-config security, xmlrpc, file editing, SSL
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/wp-config.php" ] || [ -f "$REPO/wp-includes/version.php" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

CONFIG="$REPO/wp-config.php"

if [ -f "$CONFIG" ]; then
  # --- 1. WP_DEBUG enabled ---
  grep -qE "define\s*\(\s*['\"]WP_DEBUG['\"].*true" "$CONFIG" 2>/dev/null && \
    error "wp-debug-enabled" "WP_DEBUG is true — disable in production"

  # --- 2. File editing not disabled ---
  if ! grep -q "DISALLOW_FILE_EDIT" "$CONFIG" 2>/dev/null; then
    finding "wp-file-editing" "DISALLOW_FILE_EDIT not set — attackers can edit plugins/themes via admin"
  fi

  # --- 3. Default table prefix ---
  if grep -qE "table_prefix\s*=\s*['\"]wp_['\"]" "$CONFIG" 2>/dev/null; then
    finding "wp-default-prefix" "Default table prefix 'wp_' — change to reduce automated attacks"
  fi

  # --- 4. No forced SSL for admin ---
  if ! grep -q "FORCE_SSL_ADMIN" "$CONFIG" 2>/dev/null; then
    finding "wp-no-ssl-admin" "FORCE_SSL_ADMIN not set — admin login over HTTP possible"
  fi

  # --- 5. Default/weak security keys ---
  if grep -qE "put your unique phrase here|your unique phrase" "$CONFIG" 2>/dev/null; then
    error "wp-default-keys" "Default security keys/salts — generate unique keys at api.wordpress.org/secret-key"
  fi

  # --- 6. Database credentials visible ---
  if grep -qE "DB_PASSWORD.*['\"][^'\"]{1,3}['\"]" "$CONFIG" 2>/dev/null; then
    finding "wp-weak-db-password" "Very short database password detected"
  fi

  # --- 7. Auto-updates disabled ---
  if grep -qE "AUTOMATIC_UPDATER_DISABLED.*true\|WP_AUTO_UPDATE_CORE.*false" "$CONFIG" 2>/dev/null; then
    finding "wp-no-auto-update" "Auto-updates disabled — manual patching required for security fixes"
  fi
fi

# --- 8. xmlrpc.php accessible (no block) ---
if [ -f "$REPO/xmlrpc.php" ]; then
  if ! grep -rq "xmlrpc" "$REPO/.htaccess" "$REPO/nginx.conf" "$REPO/nginx/" 2>/dev/null; then
    finding "wp-xmlrpc-enabled" "xmlrpc.php present without .htaccess block — DDoS/bruteforce vector"
  fi
fi

# --- 9. wp-content/uploads allows PHP execution ---
if [ -d "$REPO/wp-content/uploads" ]; then
  if [ ! -f "$REPO/wp-content/uploads/.htaccess" ]; then
    finding "wp-uploads-executable" "No .htaccess in uploads — PHP files can be executed"
  fi
fi

# --- 10. WordPress version EOL ---
if [ -f "$REPO/wp-includes/version.php" ]; then
  WP_VER=$(grep "wp_version\s*=" "$REPO/wp-includes/version.php" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if [ -n "$WP_VER" ]; then
    MAJOR=$(echo "$WP_VER" | cut -d. -f1)
    MINOR=$(echo "$WP_VER" | cut -d. -f2)
    # WordPress only supports latest major, anything 2+ versions behind is risky
    [ "$MAJOR" -lt 6 ] && error "wp-outdated" "WordPress $WP_VER — seriously outdated, upgrade immediately"
    [ "$MAJOR" -eq 6 ] && [ "$MINOR" -lt 4 ] && finding "wp-outdated" "WordPress $WP_VER — consider upgrading to latest"
  fi
fi

# --- 11. readme.html / license.txt expose version ---
[ -f "$REPO/readme.html" ] && finding "wp-version-exposed" "readme.html exposes WordPress version — delete it"
[ -f "$REPO/license.txt" ] && finding "wp-license-exposed" "license.txt present in web root — unnecessary exposure"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ WordPress hardening OK"
exit 0
