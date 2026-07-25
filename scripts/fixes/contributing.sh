#!/usr/bin/env bash
# fixes/contributing.sh — Generate CONTRIBUTING.md with framework conventions
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"

[ -f "$REPO/package.json" ] || { echo "  ✗ No package.json"; exit 1; }

if [ -f "$REPO/CONTRIBUTING.md" ] || [ -f "$REPO/contributing.md" ]; then
  echo "  ✓ CONTRIBUTING.md already exists"
  exit 0
fi

# Detect framework and package manager
FRAMEWORK=""
grep -q '"next"' "$REPO/package.json" && FRAMEWORK="nextjs"
grep -q '"@angular/core"' "$REPO/package.json" && FRAMEWORK="angular"
grep -q '"vue"' "$REPO/package.json" && FRAMEWORK="vue"
grep -q '"svelte"' "$REPO/package.json" && FRAMEWORK="svelte"
grep -q '"@nestjs/core"' "$REPO/package.json" && FRAMEWORK="nestjs"
grep -q '"express"' "$REPO/package.json" && FRAMEWORK="express"
grep -q '"fastify"' "$REPO/package.json" && FRAMEWORK="fastify"
grep -q '"nuxt"' "$REPO/package.json" && FRAMEWORK="nuxt"
grep -q '"astro"' "$REPO/package.json" && FRAMEWORK="astro"

PM="npm"
RUN="npm run"
[ -f "$REPO/pnpm-lock.yaml" ] && PM="pnpm" && RUN="pnpm"
[ -f "$REPO/yarn.lock" ] && PM="yarn" && RUN="yarn"

NAME=$(grep -o '"name"[^,]*' "$REPO/package.json" | head -1 | cut -d'"' -f4)

# Framework-specific docs and conventions
case "$FRAMEWORK" in
  nextjs)
    DOCS="https://nextjs.org/docs"
    CONVENTIONS="
## Framework conventions (Next.js)

Follow the [Next.js documentation]($DOCS). Don't reinvent what the framework provides.

### Rendering & Data
- **Server Components by default**. Add \`'use client'\` only for interactivity (hooks, event handlers).
- **Never fetch your own Route Handlers from Server Components** — call the logic directly.
- **Data fetching in Server Components**, not \`useEffect\`. Client components are for interaction, not data loading.
- **Always \`revalidatePath\`/\`revalidateTag\` after mutations** in Server Actions — otherwise cache is stale.
- **Suspense wraps the async component from above**, not inside it.

### Routing & Navigation
- **Use the App Router** (\`app/\` directory). No custom routing libraries.
- **Use \`next/link\`** for internal navigation. Never raw \`<a>\` tags.
- **\`redirect()\` goes outside try/catch** — it throws internally.
- **Access request data via \`params\`, \`searchParams\`, \`cookies()\`, \`headers()\`** — not \`useSearchParams\` in Server Components.

### Performance (Core Web Vitals)
- **Use \`next/image\`** with \`priority\` on LCP images. Never raw \`<img>\` tags.
- **Use \`next/font\`** for self-hosted fonts. No Google Fonts CDN links.
- **Use \`next/script\`** with loading strategy. No raw \`<script>\` tags.
- **Use \`next/dynamic\`** for heavy components (charts, modals, editors).
- **No CSS-in-JS runtime** (styled-components, emotion). Use Tailwind or CSS Modules.
- **Enable React Compiler** in next.config — free ~15% perf, zero code changes.
- **Keep middleware light** — no lodash/moment, add \`matcher\` to skip static assets.

### Architecture
- **Context providers** in separate \`'use client'\` files that accept \`children\`.
- **Don't add \`'use client'\` to pages** — extract interactive parts into small Client Components.
- **Move filtering/sorting/transforms to the server** — client components render, not compute.
- **Send minimal data to client** — filter on server, return only what the UI needs.
"
    ;;
  angular)
    DOCS="https://angular.dev"
    CONVENTIONS="
## Framework conventions (Angular)

Follow the [Angular documentation]($DOCS). Use the CLI for everything.

- **Components**: Generate with \`ng generate component\`. One component per file.
- **Services**: Injectable services for business logic. Components are thin.
- **Routing**: Use the Angular Router. Lazy-load feature modules.
- **Forms**: Use Reactive Forms for complex forms, Template-driven for simple ones.
- **HTTP**: Use \`HttpClient\`. Never raw \`fetch\`.
- **State**: Use signals for local state. NgRx only when truly needed.
- **Styling**: Component-scoped styles. No global CSS unless in \`styles.css\`.
"
    ;;
  vue|nuxt)
    DOCS="https://vuejs.org/guide/introduction"
    [ "$FRAMEWORK" = "nuxt" ] && DOCS="https://nuxt.com/docs"
    CONVENTIONS="
## Framework conventions (${FRAMEWORK^})

Follow the [documentation]($DOCS). Use Composition API.

- **Components**: Single File Components (\`.vue\`). \`<script setup>\` syntax.
- **State**: Use \`ref()\` and \`reactive()\`. Pinia for shared state.
- **Routing**: File-based routing (Nuxt) or Vue Router. No custom solutions.
- **Data fetching**: \`useFetch\` / \`useAsyncData\` (Nuxt). No \`onMounted\` + fetch.
- **Composables**: Extract reusable logic into \`composables/\`. Prefix with \`use\`.
"
    ;;
  nestjs)
    DOCS="https://docs.nestjs.com"
    CONVENTIONS="
## Framework conventions (NestJS)

Follow the [NestJS documentation]($DOCS). Use the CLI and decorators.

- **Modules**: One module per domain. Use \`@Module()\` for DI boundaries.
- **Controllers**: Thin — delegate to services. Use decorators for routing.
- **Services**: Business logic lives here. Injectable via constructor.
- **DTOs**: Use class-validator for input validation. Never trust raw input.
- **Guards/Pipes/Interceptors**: Use the built-in patterns. No custom middleware for auth/validation.
- **Config**: Use \`@nestjs/config\`. No \`process.env\` scattered in code.
"
    ;;
  *)
    DOCS=""
    CONVENTIONS=""
    ;;
esac

cat > "$REPO/CONTRIBUTING.md" << EOF
# Contributing to $NAME

## Quick start

\`\`\`bash
git clone <repository-url>
cd $NAME
$PM install
$RUN dev
\`\`\`

## Development workflow

1. Create a feature branch from \`main\`
2. Make your changes
3. Run \`$RUN lint\` — fix all warnings
4. Run \`$RUN test\` — all tests must pass
5. Run \`$RUN build\` — must compile cleanly
6. Commit with conventional commits: \`type(scope): description\`
7. Open a pull request
$CONVENTIONS
## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

\`\`\`
feat(auth): add login page
fix(api): handle timeout errors
docs(readme): add deployment section
chore(deps): update dependencies
\`\`\`

## Code style

- TypeScript strict mode — no \`any\` unless absolutely necessary
- Prettier/ESLint handle formatting — don't fight the formatter
- Name things clearly — no abbreviations, no single-letter variables (except loops)
- Small functions — if it doesn't fit on screen, split it

## For AI agents

This project uses standard $FRAMEWORK patterns. When generating code:
- Follow the framework conventions above
- Don't add libraries for things the framework already provides
- Match existing code style and patterns in the codebase
- Run lint + test before suggesting changes
EOF

echo "  ✓ Created CONTRIBUTING.md (${FRAMEWORK:-generic} conventions)"
