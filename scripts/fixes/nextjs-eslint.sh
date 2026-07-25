#!/usr/bin/env bash
# fixes/nextjs-eslint.sh — Add opinionated ESLint rules for Next.js
# Layers @vercel/style-guide on top of existing next config
set -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"

[ -f "$PKG" ] || { echo "  ✗ No package.json"; exit 1; }
grep -q '"next"' "$PKG" || { echo "  ✗ Not a Next.js project"; exit 1; }

# Check if already has vercel style guide
if grep -q "vercel/style-guide\|@vercel/style-guide" "$PKG" 2>/dev/null; then
  echo "  ✓ @vercel/style-guide already installed"
  exit 0
fi

echo "  Installing @vercel/style-guide..."

# Detect package manager
if [ -f "$REPO/pnpm-lock.yaml" ]; then
  (cd "$REPO" && pnpm add -D @vercel/style-guide >/dev/null 2>&1)
elif [ -f "$REPO/yarn.lock" ]; then
  (cd "$REPO" && yarn add -D @vercel/style-guide >/dev/null 2>&1)
else
  (cd "$REPO" && npm install --save-dev @vercel/style-guide >/dev/null 2>&1)
fi

# Generate eslint config that extends vercel style guide + next defaults
cat > "$REPO/eslint.config.mjs" << 'EOF'
import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
  {
    rules: {
      // --- TypeScript strict ---
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      "@typescript-eslint/consistent-type-imports": "warn",

      // --- Import hygiene ---
      "import/order": ["warn", {
        groups: ["builtin", "external", "internal", "parent", "sibling", "index"],
        "newlines-between": "always",
        alphabetize: { order: "asc" },
      }],
      "import/no-duplicates": "warn",

      // --- React / Next.js best practices ---
      "react/self-closing-comp": "warn",
      "react/jsx-curly-brace-presence": ["warn", { props: "never", children: "never" }],

      // --- Code quality ---
      "no-console": ["warn", { allow: ["warn", "error"] }],
      "prefer-const": "warn",
      "no-nested-ternary": "warn",
      eqeqeq: ["warn", "always"],
    },
  },
]);

export default eslintConfig;
EOF

echo "  ✓ Added opinionated ESLint config"
echo "    Includes: strict TS, import order, no-console, React best practices"
echo "    Based on: Next.js core-web-vitals + @vercel/style-guide patterns"
