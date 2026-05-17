#!/usr/bin/env bash
# fixes/nextjs-docs.sh — Generate docs/ with getting-started guide
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"

[ -f "$PKG" ] || { echo "  ✗ No package.json"; exit 1; }

# Extract project name
NAME=$(grep -o '"name"[^,]*' "$PKG" | head -1 | cut -d'"' -f4)
NAME="${NAME:-my-project}"

mkdir -p "$REPO/docs"

if [ -f "$REPO/docs/getting-started.md" ]; then
  echo "  ✓ docs/getting-started.md already exists"
  exit 0
fi

# Detect package manager
if [ -f "$REPO/pnpm-lock.yaml" ]; then
  INSTALL="pnpm install"
  RUN="pnpm"
elif [ -f "$REPO/yarn.lock" ]; then
  INSTALL="yarn"
  RUN="yarn"
else
  INSTALL="npm install"
  RUN="npm run"
fi

cat > "$REPO/docs/getting-started.md" << EOF
# Getting Started

## Prerequisites

- Node.js 20+
- ${INSTALL%% *}

## Install

\`\`\`bash
git clone <repository-url>
cd $NAME
$INSTALL
\`\`\`

## Development

\`\`\`bash
$RUN dev
\`\`\`

Open [http://localhost:3000](http://localhost:3000).

## Build

\`\`\`bash
$RUN build
\`\`\`

## Test

\`\`\`bash
$RUN test
\`\`\`

## Project Structure

\`\`\`
app/          — Pages and layouts (App Router)
public/       — Static assets
docs/         — Documentation
\`\`\`
EOF

echo "  ✓ Created docs/getting-started.md"
