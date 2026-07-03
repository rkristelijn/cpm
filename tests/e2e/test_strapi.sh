#!/usr/bin/env bash
# E2E test: Strapi security hardening checks
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

CHECK="$SCRIPT_DIR/../../checks/javascript/check-strapi.sh"

echo "=== E2E: strapi-security-hardening ==="

# --- Test: skips non-strapi projects ---
DIR=$(setup_project)
echo '{"name":"not-strapi","dependencies":{"express":"4.0.0"}}' > "$DIR/package.json"
OUTPUT=$(bash "$CHECK" "$DIR" 2>&1 || true)
[[ -z "$OUTPUT" ]] || die "should skip non-strapi project, got: $OUTPUT"
teardown_project "$DIR"

# --- Test: detects playground opt-out pattern ---
DIR=$(setup_project)
mkdir -p "$DIR/config" "$DIR/src/plugins"
echo '{"name":"test","dependencies":{"@strapi/strapi":"5.0.0","@strapi/plugin-graphql":"5.0.0"}}' > "$DIR/package.json"
cat > "$DIR/config/plugins.ts" <<'EOF'
import { isPlaygroundEnabled } from "../src/plugins/server";
export default ({ env }) => ({
  graphql: {
    config: {
      playgroundAlways: isPlaygroundEnabled(),
      shadowCRUD: true,
      apolloServer: {
        introspection: isPlaygroundEnabled(),
      },
    },
  },
});
EOF
cat > "$DIR/src/plugins/server.ts" <<'EOF'
export const isPlaygroundEnabled = (): boolean => {
  return process.env.GRAPHQL_PLAYGROUND_ENABLED !== "false";
};
EOF
OUTPUT=$(bash "$CHECK" "$DIR" 2>&1 || true)
assert_contains "$OUTPUT" "strapi-playground-opt-out" "detects opt-out playground logic"
assert_contains "$OUTPUT" "strapi-introspection-tied-to-playground" "detects introspection tied to playground"
assert_contains "$OUTPUT" "strapi-shadow-crud" "detects shadowCRUD enabled"
teardown_project "$DIR"

# --- Test: detects no auth on graphql ---
DIR=$(setup_project)
mkdir -p "$DIR/config" "$DIR/src"
echo '{"name":"test","dependencies":{"@strapi/strapi":"5.0.0","@strapi/plugin-graphql":"5.0.0"}}' > "$DIR/package.json"
cat > "$DIR/config/plugins.ts" <<'EOF'
export default ({ env }) => ({
  graphql: { config: { endpoint: "/graphql" } },
});
EOF
cat > "$DIR/config/middlewares.ts" <<'EOF'
export default ["strapi::errors", "strapi::cors", "strapi::security"];
EOF
OUTPUT=$(bash "$CHECK" "$DIR" 2>&1 || true)
assert_contains "$OUTPUT" "strapi-graphql-no-auth" "detects no auth on graphql"
teardown_project "$DIR"

# --- Test: detects CSP allowing Apollo sandbox ---
DIR=$(setup_project)
mkdir -p "$DIR/config" "$DIR/src"
echo '{"name":"test","dependencies":{"@strapi/strapi":"5.0.0","@strapi/plugin-graphql":"5.0.0"}}' > "$DIR/package.json"
cat > "$DIR/config/plugins.ts" <<'EOF'
export default ({ env }) => ({ graphql: { config: {} } });
EOF
cat > "$DIR/config/middlewares.ts" <<'EOF'
export default [
  { name: "strapi::security", config: {
    contentSecurityPolicy: {
      directives: {
        "script-src": ["self", "embeddable-sandbox.cdn.apollographql.com"],
      }
    }
  }}
];
EOF
OUTPUT=$(bash "$CHECK" "$DIR" 2>&1 || true)
assert_contains "$OUTPUT" "strapi-csp-allows-playground" "detects CSP whitelisting Apollo"
teardown_project "$DIR"

# --- Test: detects no depth limit ---
DIR=$(setup_project)
mkdir -p "$DIR/config" "$DIR/src"
echo '{"name":"test","dependencies":{"@strapi/strapi":"5.0.0","@strapi/plugin-graphql":"5.0.0"}}' > "$DIR/package.json"
cat > "$DIR/config/plugins.ts" <<'EOF'
export default ({ env }) => ({ graphql: { config: { endpoint: "/graphql" } } });
EOF
OUTPUT=$(bash "$CHECK" "$DIR" 2>&1 || true)
assert_contains "$OUTPUT" "strapi-graphql-no-depth-limit" "detects no query depth limit"
teardown_project "$DIR"

# --- Test: detects no audit logging ---
DIR=$(setup_project)
mkdir -p "$DIR/config" "$DIR/src"
echo '{"name":"test","dependencies":{"@strapi/strapi":"5.0.0","@strapi/plugin-graphql":"5.0.0"}}' > "$DIR/package.json"
echo '' > "$DIR/config/plugins.ts"
OUTPUT=$(bash "$CHECK" "$DIR" 2>&1 || true)
assert_contains "$OUTPUT" "strapi-no-audit-log" "detects no audit logging"
teardown_project "$DIR"

# --- Test: passes when properly hardened ---
DIR=$(setup_project)
mkdir -p "$DIR/config" "$DIR/src/middlewares" "$DIR/src/policies" "$DIR/src/extensions/graphql" "$DIR/src/api/post/content-types"
echo '{"name":"test","dependencies":{"@strapi/strapi":"5.0.0","@strapi/plugin-graphql":"5.0.0","strapi-plugin-audit":"1.0.0","strapi-health-plugin":"1.0.0","koa-ratelimit":"5.0.0"}}' > "$DIR/package.json"
cat > "$DIR/config/plugins.ts" <<'EOF'
export default ({ env }) => ({
  graphql: {
    config: {
      playgroundAlways: false,
      shadowCRUD: false,
      depthLimit: 10,
      apolloServer: { introspection: false },
    },
  },
});
EOF
cat > "$DIR/config/middlewares.ts" <<'EOF'
export default [
  { name: "strapi::security", config: { contentSecurityPolicy: { directives: { "script-src": ["self"] } } } },
  { name: "strapi::cors", config: { origin: ["https://app.example.com"] } },
  "global::authenticate-graphql",
];
EOF
cat > "$DIR/src/middlewares/authenticate-graphql.ts" <<'EOF'
export default () => async (ctx, next) => { /* graphql auth policy */ await next(); };
EOF
cat > "$DIR/src/policies/isAuthenticated.ts" <<'EOF'
export default (ctx) => ctx.state.user ? true : false;
EOF
echo 'allowedExtensions: [".png",".jpg"]' > "$DIR/src/middlewares/secure-upload.ts"
echo 'export default {}' > "$DIR/src/extensions/graphql/codegen.ts"
echo 'TypedDocumentNode' >> "$DIR/src/extensions/graphql/codegen.ts"
OUTPUT=$(bash "$CHECK" "$DIR" 2>&1 || true)
assert_contains "$OUTPUT" "all checks passed" "hardened project passes all checks"
teardown_project "$DIR"

echo "=== All strapi-security-hardening tests passed ==="
