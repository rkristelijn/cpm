#!/usr/bin/env bash
# cpm:ignore-file SCA-028 — detector/test source: contains the patterns it checks for
# checks/javascript/nextjs/check-nextjs-15.sh
# Next.js 15 anti-patterns: router imports, getServerSideProps, metadata, fetch caching
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json" || exit 0

findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }

# next/router import in App Router (use next/navigation)
while IFS= read -r file; do
  if grep -qE "from ['\"]next/router['\"]" "$file" 2>/dev/null; then
    findings_add "warning" "next15-router-import" "next/router import in App Router" \
      "Use next/navigation for App Router: import { useRouter } from 'next/navigation'" \
      "https://nextjs.org/docs/app/building-your-application/routing/hooks"
  fi
done < <(find $REPO -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" 2>/dev/null | grep -v node_modules)

# getServerSideProps/getStaticProps in app/ directory
while IFS= read -r file; do
  if grep -qE "getServerSideProps|getStaticProps" "$file" 2>/dev/null && echo "$file" | grep -q "app/"; then
    findings_add "warning" "next15-page-dir-props" "getServerSideProps/getStaticProps in app/ directory" \
      "These are for Pages Router. Use async components and fetch with caching in App Router" \
      "https://nextjs.org/docs/app/building-your-application/upgrading/app-router-migration"
  fi
done < <(find $REPO -name "*.tsx" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No metadata export in layout.tsx
if [ -d "$REPO/app" ]; then
  has_metadata=false
  while IFS= read -r layout; do
    if grep -qE "export\s+const\s+metadata|export\s+default\s+function.*Layout" "$layout" 2>/dev/null; then
      has_metadata=true
      break
    fi
  done < <(find $REPO/app -name "layout.tsx" 2>/dev/null)
  if [ "$has_metadata" = false ]; then
    findings_add "warning" "next15-no-metadata" "No metadata export in root layout.tsx" \
      "Add export const metadata = { title: '...', description: '...' }" \
      "https://nextjs.org/docs/app/building-your-application/optimizing/metadata"
  fi
fi

# fetch() without cache/revalidate option
while IFS= read -r file; do
  if grep -qE "fetch\s*\(\s*['\"][^'\"]+['\"]" "$file" 2>/dev/null && ! grep -qE "next:\s*\{.*revalidate|cache:\s*['\"]" "$file" 2>/dev/null; then
    findings_add "warning" "next15-fetch-cache" "fetch() without cache/revalidate option" \
      "In Next.js 15, fetch is not cached by default. Add { next: { revalidate: 3600 } }" \
      "https://nextjs.org/docs/app/building-your-application/data-fetching"
  fi
done < <(find $REPO -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" 2>/dev/null | grep -v node_modules)

# Missing not-found.tsx
if [ -d "$REPO/app" ] && [ ! -f "$REPO/app/not-found.tsx" ]; then
  findings_add "warning" "next15-no-not-found" "Missing not-found.tsx for 404 handling" \
    "Create app/not-found.tsx to handle 404 pages" \
    "https://nextjs.org/docs/app/api-reference/file-conventions/not-found"
fi

# No error.tsx boundary
if [ -d "$REPO/app" ] && [ ! -f "$REPO/app/error.tsx" ]; then
  findings_add "warning" "next15-no-error-boundary" "Missing error.tsx for error handling" \
    "Create app/error.tsx to handle runtime errors" \
    "https://nextjs.org/docs/app/api-reference/file-conventions/error"
fi

# Importing server-only code in client component
while IFS= read -r file; do
  if grep -qE "\"use client\"|'use client'" "$file" 2>/dev/null; then
    if grep -qE "cookies\(\)|headers\(\)" "$file" 2>/dev/null; then
      findings_add "warning" "next15-server-in-client" "Server-only APIs in client component" \
        "cookies() and headers() are server-only. Use them in Server Components" \
        "https://nextjs.org/docs/app/building-your-application/rendering"
    fi
  fi
done < <(find $REPO -name "*.tsx" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# Using cookies()/headers() in client component
while IFS= read -r file; do
  if grep -qE "\"use client\"|'use client'" "$file" 2>/dev/null; then
    if grep -qE "import.*cookies|import.*headers" "$file" 2>/dev/null; then
      findings_add "warning" "next15-client-cookies" "cookies()/headers() imported in client component" \
        "These are server-only. Use next/headers cookies() in Server Components" \
        "https://nextjs.org/docs/app/api-reference/functions/cookies"
    fi
  fi
done < <(find $REPO -name "*.tsx" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No generateStaticParams for dynamic routes
while IFS= read -r dir; do
  if [ -d "$dir" ]; then
    has_params=false
    for f in "$dir"/*; do
      if [ -f "$f" ] && grep -q "generateStaticParams" "$f" 2>/dev/null; then
        has_params=true
        break
      fi
    done
    if [ "$has_params" = false ]; then
      findings_add "warning" "next15-no-static-params" "No generateStaticParams for dynamic route" \
        "Add generateStaticParams for static generation of dynamic routes" \
        "https://nextjs.org/docs/app/api-reference/functions/generate-static-params"
    fi
  fi
done < <(find $REPO/app -type d -name "\[*\]" 2>/dev/null)

# redirect() in try/catch (throws NEXT_REDIRECT)
while IFS= read -r file; do
  if grep -qE "try\s*\{[^}]*redirect\s*\(" "$file" 2>/dev/null; then
    findings_add "warning" "next15-redirect-try" "redirect() inside try/catch block" \
      "redirect() throws NEXT_REDIRECT. Use conditional rendering instead" \
      "https://nextjs.org/docs/app/api-reference/functions/redirect"
  fi
done < <(find $REPO -name "*.tsx" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

echo "  ✓ Next.js 15 patterns checked"
