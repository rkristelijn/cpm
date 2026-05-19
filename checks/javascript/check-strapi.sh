#!/usr/bin/env bash
# checks/javascript/check-strapi.sh
# @see ADR-129
# Strapi best practices from portal-service + strapi-health-plugin
# Pattern: health endpoint, secure uploads, custom controllers, lifecycle hooks
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q "@strapi/strapi" "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC="$REPO/src"
[ -d "$SRC" ] || exit 0

# --- 1. No health endpoint (K8s probes) ---
if ! grep -rq "health\|strapi-health-plugin" "$REPO/package.json" "$SRC" 2>/dev/null; then
  finding "strapi-no-health" "No health endpoint — add strapi-health-plugin for K8s probes"
fi

# --- 2. No upload security (extension validation) ---
if ! find "$SRC" -name "*.ts" -o -name "*.js" 2>/dev/null | xargs grep -l "allowedExtensions\|secure-upload\|upload.*middleware" 2>/dev/null | grep -q .; then
  error "strapi-no-upload-security" "No upload security middleware — malicious files can be uploaded"
fi

# --- 3. No custom middlewares at all ---
MW_DIR="$SRC/middlewares"
if [ ! -d "$MW_DIR" ] || [ -z "$(ls "$MW_DIR" 2>/dev/null)" ]; then
  finding "strapi-no-middlewares" "No custom middlewares — consider security/logging middleware"
fi

# --- 4. API keys or secrets in config files ---
CONFIG_DIR="$REPO/config"
if [ -d "$CONFIG_DIR" ]; then
  BAD=$(grep -rn "password\|secret\|apiKey\|token" "$CONFIG_DIR" --include="*.ts" --include="*.js" 2>/dev/null | \
    grep -v "env(\|process.env\|placeholder\|example" | head -1 || true)
  [ -n "$BAD" ] && error "strapi-hardcoded-secret" "Potential hardcoded secret in config — use env() helper"
fi

# --- 5. No lifecycle hooks (missed validation/audit opportunity) ---
LIFECYCLES=$(find "$SRC" -name "lifecycles.ts" -o -name "lifecycles.js" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
CONTENT_TYPES=$(find "$SRC/api" -type d -name "content-types" 2>/dev/null | wc -l | tr -d ' ')
if [ "$CONTENT_TYPES" -gt 3 ] && [ "$LIFECYCLES" -eq 0 ]; then
  finding "strapi-no-lifecycles" "$CONTENT_TYPES content-types but no lifecycle hooks — missed validation opportunity"
fi

# --- 6. All controllers are default (no custom logic) ---
CTRL_FILES=$(find "$SRC/api" -name "*.ts" -o -name "*.js" -path "*/controllers/*" 2>/dev/null | grep -v node_modules)
if [ -n "$CTRL_FILES" ]; then
  CUSTOM=$(echo "$CTRL_FILES" | xargs grep -L "factories.createCoreController" 2>/dev/null | wc -l | tr -d ' ')
  TOTAL=$(echo "$CTRL_FILES" | wc -l | tr -d ' ')
  [ "$TOTAL" -gt 3 ] && [ "$CUSTOM" -eq 0 ] && \
    finding "strapi-all-default-ctrl" "All $TOTAL controllers use defaults — no custom business logic?"
fi

# --- 7. GraphQL extensions without type safety ---
GQL_DIR="$SRC/extensions/graphql"
if [ -d "$GQL_DIR" ]; then
  if ! grep -rq "TypedDocumentNode\|codegen\|graphql-tag" "$GQL_DIR" 2>/dev/null; then
    finding "strapi-graphql-no-types" "GraphQL extensions without type generation"
  fi
fi

# --- 8. No CORS configuration (from strapi.io best practices) ---
CONFIG_DIR="$REPO/config"
if [ -d "$CONFIG_DIR" ] && ! grep -rq "cors\|origin" "$CONFIG_DIR" --include="*.ts" --include="*.js" 2>/dev/null; then
  finding "strapi-no-cors" "No CORS configuration — API accessible from any origin"
fi

# --- 9. No rate limiting ---
if ! grep -rq "rateLimit\|strapi-plugin-rate-limit\|koa-ratelimit" "$REPO/package.json" "$SRC" 2>/dev/null; then
  finding "strapi-no-rate-limit" "No rate limiting — API vulnerable to brute force/DoS"
fi

# --- 10. No webhook security (from strapi.io blog) ---
if grep -rq "webhook" "$CONFIG_DIR" 2>/dev/null; then
  if ! grep -rq "secret\|auth\|token" "$CONFIG_DIR" --include="*.ts" --include="*.js" 2>/dev/null | grep -qi "webhook"; then
    finding "strapi-webhook-no-auth" "Webhooks configured without authentication"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Strapi patterns: all checks passed\n"
exit 0
