#!/usr/bin/env bash
# checks/php/check-php.sh
# PHP anti-patterns: security, deprecated APIs, Laravel/WordPress best practices
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "php" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/composer.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Find PHP files (exclude vendor)
PHP_FILES=$(find "$REPO" -name "*.php" 2>/dev/null | grep -v "vendor\|node_modules" || true)
[ -z "$PHP_FILES" ] && exit 0

# === Security: Command injection ===
echo "$PHP_FILES" | xargs grep -ln "eval(\|exec(\|system(\|shell_exec(\|passthru(\|proc_open(\|popen(" 2>/dev/null | head -1 | grep -q . && \
  error "php-command-injection" "eval/exec/system/shell_exec found — command injection risk"

# === Security: SQL injection (raw queries with user input) ===
echo "$PHP_FILES" | xargs grep -ln "\$_GET\|\$_POST\|\$_REQUEST" 2>/dev/null | \
  xargs grep -l "query\|mysql\|DB::raw\|->where.*\\\$_" 2>/dev/null | head -1 | grep -q . && \
  error "php-sql-injection" "User input (\$_GET/\$_POST) used in queries — SQL injection risk"

# === Security: XSS (unescaped output) ===
echo "$PHP_FILES" | xargs grep -n "echo \$_\|print \$_\|<?= \$_" 2>/dev/null | head -1 | grep -q . && \
  error "php-xss" "Unescaped user input in output — XSS vulnerability"

# === Security: File inclusion with user input ===
echo "$PHP_FILES" | xargs grep -n "include.*\$_\|require.*\$_\|include_once.*\$_" 2>/dev/null | head -1 | grep -q . && \
  error "php-file-inclusion" "Dynamic include with user input — remote file inclusion risk"

# === Deprecated functions ===
echo "$PHP_FILES" | xargs grep -ln "mysql_connect\|mysql_query\|ereg(\|eregi(\|split(\|create_function\|each(" 2>/dev/null | head -1 | grep -q . && \
  finding "php-deprecated" "Deprecated PHP functions (mysql_*, ereg, create_function) — upgrade"

# === No composer.lock (non-reproducible) ===
[ ! -f "$REPO/composer.lock" ] && finding "php-no-lockfile" "No composer.lock — non-reproducible installs"

# === PHP version not pinned ===
if ! grep -q '"php"' "$REPO/composer.json" 2>/dev/null; then
  finding "php-no-version" "No PHP version constraint in composer.json"
fi

# === Laravel-specific ===
if grep -q "laravel" "$REPO/composer.json" 2>/dev/null; then
  # .env committed
  [ -f "$REPO/.env" ] && error "php-env-committed" ".env file committed — contains secrets, add to .gitignore"
  # No APP_KEY rotation hint
  grep -q "APP_KEY=base64:" "$REPO/.env.example" 2>/dev/null || \
    [ ! -f "$REPO/.env.example" ] && finding "php-no-env-example" "No .env.example — team can't set up the project"
  # Debug mode
  grep -q "APP_DEBUG=true" "$REPO/.env" 2>/dev/null && error "php-debug-on" "APP_DEBUG=true in .env — disable in production"
  # Mass assignment (no $fillable or $guarded)
  MODELS=$(find "$REPO" -path "*/Models/*.php" -o -path "*/models/*.php" 2>/dev/null | grep -v vendor)
  if [ -n "$MODELS" ]; then
    NO_GUARD=$(echo "$MODELS" | xargs grep -L "fillable\|guarded" 2>/dev/null | head -1 || true)
    [ -n "$NO_GUARD" ] && finding "php-mass-assignment" "Model without \$fillable/\$guarded — mass assignment vulnerability"
  fi
fi

# === WordPress-specific ===
if grep -q "wordpress\|wp-" "$REPO/composer.json" 2>/dev/null || [ -f "$REPO/style.css" ] && grep -q "Theme Name" "$REPO/style.css" 2>/dev/null; then
  # Direct database queries without prepare
  echo "$PHP_FILES" | xargs grep -n "\$wpdb->query\|\$wpdb->get_" 2>/dev/null | \
    grep -v "prepare\|->prepare" | head -1 | grep -q . && \
    finding "wp-no-prepare" "\$wpdb query without prepare() — SQL injection risk"
  # Unescaped output
  echo "$PHP_FILES" | xargs grep -n "echo \$\|<?= \$" 2>/dev/null | \
    grep -v "esc_html\|esc_attr\|esc_url\|wp_kses\|htmlspecialchars" | \
    grep -v vendor | head -1 | grep -q . && \
    finding "wp-unescaped-output" "Output without esc_html/esc_attr — XSS risk in WordPress"
  # No text domain (i18n)
  echo "$PHP_FILES" | xargs grep -l "__(\|_e(" 2>/dev/null | head -1 | grep -q . || \
    finding "wp-no-i18n" "No internationalization (__(), _e()) — theme not translatable"
fi

# === General quality ===
# God files (>500 lines)
LARGE=$(echo "$PHP_FILES" | xargs wc -l 2>/dev/null | awk '$1 > 500 {print}' | grep -v "total\|vendor" | wc -l | tr -d ' ')
[ "$LARGE" -gt 3 ] && finding "php-large-files" "$LARGE PHP files >500 lines — consider splitting"

# var_dump/print_r left in code
echo "$PHP_FILES" | xargs grep -ln "var_dump\|print_r\|dd(" 2>/dev/null | head -1 | grep -q . && \
  finding "php-debug-output" "var_dump/print_r/dd() left in code — remove before production"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ PHP patterns OK"
exit 0
