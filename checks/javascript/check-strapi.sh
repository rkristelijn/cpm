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

# ===========================================================================
# SECURITY HARDENING CHECKS (anti-patterns from production incidents)
# ===========================================================================

# --- 11. GraphQL playground enabled by default in production ---
# Anti-pattern: playground enabled unless explicitly disabled (opt-out instead of opt-in)
# Best practice: playgroundAlways: false OR environment check NODE_ENV === 'production' → disable
PLUGINS_FILE=$(find "$CONFIG_DIR" -name "plugins.ts" -o -name "plugins.js" 2>/dev/null | head -1)
if [ -n "$PLUGINS_FILE" ]; then
  if grep -q "playgroundAlways" "$PLUGINS_FILE" 2>/dev/null; then
    # Check if it's opt-out (enabled unless disabled) vs opt-in (disabled unless enabled)
    if grep -rq 'isPlaygroundEnabled\|!== "false"\|!== .false.' "$PLUGINS_FILE" "$SRC" 2>/dev/null; then
      error "strapi-playground-opt-out" "GraphQL playground uses opt-OUT logic (enabled unless GRAPHQL_PLAYGROUND_ENABLED=false) — should be opt-IN (disabled unless explicitly enabled in non-prod)"
    fi
  fi
  # Also flag if playground is unconditionally true
  if grep -qE "playgroundAlways:\s*true" "$PLUGINS_FILE" 2>/dev/null; then
    error "strapi-playground-always" "GraphQL playground unconditionally enabled — disable in production"
  fi
fi

# --- 12. GraphQL playground helper function — opt-out pattern ---
# Scan src/ for the actual function that controls playground
PLAYGROUND_FUNC=$(grep -rn "isPlaygroundEnabled\|playgroundEnabled" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | head -3)
if [ -n "$PLAYGROUND_FUNC" ]; then
  if echo "$PLAYGROUND_FUNC" | grep -qE '!== "false"|!== .false.'; then
    error "strapi-playground-default-true" "Playground defaults to enabled (returns true unless env=false) — invert logic: default disabled, enable only for local/dev"
  fi
fi

# --- 13. Introspection tied to playground (same flag) ---
# Anti-pattern: introspection enabled whenever playground is
# Best practice: introspection should ALWAYS be off in production regardless of playground
if [ -n "$PLUGINS_FILE" ]; then
  if grep -q "introspection.*isPlaygroundEnabled\|introspection.*playground" "$PLUGINS_FILE" 2>/dev/null; then
    finding "strapi-introspection-tied-to-playground" "Introspection follows playground setting — should be independently disabled in production"
  fi
fi

# --- 14. No authentication middleware on GraphQL endpoint ---
# Check middlewares.ts for graphql route protection
MIDDLEWARES_FILE=$(find "$CONFIG_DIR" -name "middlewares.ts" -o -name "middlewares.js" 2>/dev/null | head -1)
if [ -n "$MIDDLEWARES_FILE" ]; then
  if ! grep -q "graphql.*auth\|authenticate.*graphql" "$MIDDLEWARES_FILE" 2>/dev/null; then
    if ! grep -rq "graphql.*policy\|isAuthenticated\|auth.*graphql" "$SRC/extensions" "$SRC/middlewares" "$SRC/policies" 2>/dev/null; then
      error "strapi-graphql-no-auth" "No authentication required on /graphql endpoint — all queries publicly accessible"
    fi
  fi
fi

# --- 15. Public role permissions too broad ---
# Check config-sync exports for public role grants
SYNC_DIR="$CONFIG_DIR/sync"
if [ -d "$SYNC_DIR" ]; then
  PUBLIC_GRANTS=$(grep -rn "\"public\"" "$SYNC_DIR" --include="*.json" 2>/dev/null | grep -i "find\|findOne\|count" | wc -l | tr -d ' ')
  if [ "$PUBLIC_GRANTS" -gt 3 ]; then
    error "strapi-public-role-broad" "Public role has $PUBLIC_GRANTS find/findOne permissions — review: should unauthenticated users access this data?"
  fi
fi

# --- 16. No Content Security Policy for GraphQL ---
if [ -n "$MIDDLEWARES_FILE" ]; then
  if grep -q "contentSecurityPolicy" "$MIDDLEWARES_FILE" 2>/dev/null; then
    # Check if Apollo/GraphQL sandbox domains are whitelisted (allows playground to load)
    if grep -q "apollo\|embeddable-sandbox\|embeddable-explorer" "$MIDDLEWARES_FILE" 2>/dev/null; then
      finding "strapi-csp-allows-playground" "CSP whitelists Apollo sandbox/explorer domains — remove in production to block playground UI"
    fi
  fi
fi

# --- 17. No query depth/complexity limiting ---
if [ -n "$PLUGINS_FILE" ]; then
  if ! grep -rq "depthLimit\|queryComplexity\|maxDepth\|costLimit" "$PLUGINS_FILE" "$SRC" 2>/dev/null; then
    finding "strapi-graphql-no-depth-limit" "No GraphQL query depth/complexity limiting — vulnerable to nested query DoS"
  fi
fi

# --- 18. shadowCRUD enabled (auto-generates types for all content-types) ---
if [ -n "$PLUGINS_FILE" ]; then
  if grep -qE "shadowCRUD:\s*true" "$PLUGINS_FILE" 2>/dev/null; then
    finding "strapi-shadow-crud" "shadowCRUD: true — auto-exposes all content-types via GraphQL. Disable and explicitly register only needed types."
  fi
fi

# --- 19. JWT expiry too long or not configured ---
if [ -n "$PLUGINS_FILE" ]; then
  JWT_EXPIRY=$(grep -oE "expiresIn.*['\"]([^'\"]+)['\"]" "$PLUGINS_FILE" 2>/dev/null | grep -oE "[0-9]+[a-z]" | head -1)
  if [ -n "$JWT_EXPIRY" ]; then
    # Extract number and unit
    NUM=$(echo "$JWT_EXPIRY" | grep -oE "[0-9]+")
    UNIT=$(echo "$JWT_EXPIRY" | grep -oE "[a-z]+")
    if [ "$UNIT" = "d" ] || ([ "$UNIT" = "h" ] && [ "$NUM" -gt 1 ]); then
      finding "strapi-jwt-long-expiry" "JWT expires in $JWT_EXPIRY — consider shorter tokens (15m-1h) with refresh"
    fi
  fi
fi

# --- 20. No audit logging plugin ---
if ! grep -rq "strapi-plugin-audit\|audit-log\|strapi-plugin-paper-trail" "$REPO/package.json" 2>/dev/null; then
  finding "strapi-no-audit-log" "No audit logging plugin — admin actions and data changes are not tracked"
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Strapi patterns: all checks passed\n"
exit 0
