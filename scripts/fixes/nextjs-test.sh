#!/usr/bin/env bash
# fixes/nextjs-test.sh — Add vitest + testing-library + smoke test to Next.js project
# Version-scoped: Next.js 14-16
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"

[ -f "$PKG" ] || {
  echo "  ✗ No package.json"
  exit 1
}
grep -q '"next"' "$PKG" || {
  echo "  ✗ Not a Next.js project"
  exit 1
}

# Already has tests?
if grep -q '"test"' "$PKG" && ! grep -q '"test":\s*"echo' "$PKG"; then
  echo "  ✓ Test script already configured"
  exit 0
fi

echo "  Adding vitest + @testing-library/react..."

# Detect package manager
if [ -f "$REPO/pnpm-lock.yaml" ]; then
  PM="pnpm add -D"
elif [ -f "$REPO/yarn.lock" ]; then
  PM="yarn add -D"
else
  PM="npm install --save-dev"
fi

# Install test deps
(cd "$REPO" && $PM vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom jsdom >/dev/null 2>&1)

# Add vitest config
cat >"$REPO/vitest.config.ts" <<'EOF'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
  },
})
EOF

cat >"$REPO/vitest.setup.ts" <<'EOF'
import '@testing-library/jest-dom/vitest'
EOF

# Add smoke test
mkdir -p "$REPO/app"
cat >"$REPO/app/page.test.tsx" <<'EOF'
import { render, screen } from '@testing-library/react'
import { expect, it } from 'vitest'
import Page from './page'

it('renders without crashing', () => {
  render(<Page />)
  expect(screen.getByRole('heading')).toBeInTheDocument()
})
EOF

# Add test script to package.json (replace existing no-op or add)
if grep -q '"test"' "$PKG"; then
  sed -i.bak 's/"test":[^,]*/"test": "vitest run"/' "$PKG"
else
  sed -i.bak 's/"scripts": {/"scripts": {\n    "test": "vitest run",/' "$PKG"
fi
rm -f "${PKG}.bak"

echo "  ✓ Added vitest + smoke test (app/page.test.tsx)"
