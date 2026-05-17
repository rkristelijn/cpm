# Next.js Patterns — Checkable RTFM Patterns

This document lists 18 checkable patterns for Next.js App Router projects, derived from official documentation and best practices.

## App Router Core Patterns

### 1. No getServerSideProps/getStaticProps in App Router
**Severity:** error  
**Pattern:** `getServerSideProps|getStaticProps|getStaticPaths|getServerSideSideProps`  
**Why:** These are Pages Router APIs. App Router uses async components and `generateStaticParams`.  
**Fix:** Convert to async Server Components with `fetch` caching options.  
**Docs:** https://nextjs.org/docs/app/building-your-application/upgrading/pages-router

### 2. Dynamic Routes Require generateStaticParams
**Severity:** warning  
**Pattern:** Route segment with `[id]` or `[slug]` without `generateStaticParams`  
**Why:** Without it, pages are dynamic (SSR) at runtime, hurting TTFB.  
**Fix:** Add `export async function generateStaticParams() { ... }` for known paths.  
**Docs:** https://nextjs.org/docs/app/building-your-application/routing/dynamic-routes#generating-static-params

### 3. Server Components Must Not Import Client Components with 'use client'
**Severity:** warning  
**Pattern:** Client component importing another client component unnecessarily  
**Why:** Each 'use client' boundary adds bundle size. Keep the boundary as low as possible.  
**Fix:** Move 'use client' only to leaf components that need interactivity.  
**Docs:** https://nextjs.org/docs/app/building-your-application/rendering#server-components

### 4. cookies()/headers() in Static Generation Context
**Severity:** error  
**Pattern:** `cookies()` or `headers()` used in page/layout without dynamic rendering  
**Why:** These APIs make the route dynamic. Using them without `export const dynamic = 'force-dynamic'` causes runtime errors.  
**Fix:** Add `export const dynamic = 'force-dynamic'` or move logic to middleware/Route Handlers.  
**Docs:** https://nextjs.org/docs/app/api-reference/functions/cookies

## Data Fetching Patterns

### 5. Fetch Without Explicit Cache Strategy
**Severity:** warning  
**Pattern:** `fetch(url)` without `{ cache: ... }` or `revalidate: ...`  
**Why:** Default cache behavior changed in Next.js 15. Explicit is better than implicit.  
**Fix:** Add `{ cache: 'force-cache' }` for static data or `{ cache: 'no-store' }` for dynamic.  
**Docs:** https://nextjs.org/docs/app/api-reference/functions/fetch

### 6. Server Actions Without Revalidation
**Severity:** warning  
**Pattern:** Server Action mutating data without `revalidatePath` or `revalidateTag`  
**Why:** UI won't reflect mutations — users see stale data.  
**Fix:** Call `revalidatePath('/route')` or `revalidateTag('tag')` after mutations.  
**Docs:** https://nextjs.org/docs/app/api-reference/functions/revalidatePath

### 7. No Suspense Boundary for Slow Data
**Severity:** warning  
**Pattern:** Page with multiple fetches without `loading.tsx` or Suspense  
**Why:** Entire page blocks until all fetches complete. Streaming improves perceived performance.  
**Fix:** Add `loading.tsx` or wrap slow components in `<Suspense>`.  
**Docs:** https://nextjs.org/docs/app/building-your-application/routing/loading-ui

## Metadata & SEO Patterns

### 8. Root Layout Missing Metadata
**Severity:** warning  
**Pattern:** `app/layout.tsx` without `export const metadata` or `generateMetadata`  
**Why:** Pages lack title, description, Open Graph tags for social sharing.  
**Fix:** Add metadata export with title, description, and icons.  
**Docs:** https://nextjs.org/docs/app/api-reference/functions/generate-metadata

### 9. Static Export Without output: 'export'
**Severity:** error  
**Pattern:** `next.config.js` without `output: 'export'` for static hosting  
**Why:** Next.js generates dynamic routes that require a Node.js server.  
**Fix:** Add `output: 'export'` and ensure no dynamic APIs are used.  
**Docs:** https://nextjs.org/docs/app/building-your-application/deploying/static-exports

## Error Handling Patterns

### 10. No not-found.tsx for 404 Handling
**Severity:** warning  
**Pattern:** App Router project without `app/not-found.tsx`  
**Why:** Default 404 is unauthenticated and lacks branding.  
**Fix:** Create `app/not-found.tsx` with consistent styling.  
**Docs:** https://nextjs.org/docs/app/api-reference/file-conventions/not-found

### 11. No error.tsx for Error Boundaries
**Severity:** warning  
**Pattern:** Route segments without `app/error.tsx`  
**Why:** Unhandled errors crash the entire route segment.  
**Fix:** Add `error.tsx` with `useEffect` to reset error state.  
**Docs:** https://nextjs.org/docs/app/building-your-application/routing/error-handling

### 12. redirect() in try/catch Block
**Severity:** warning  
**Pattern:** `redirect()` inside `try { ... } catch { ... }`  
**Why:** `redirect()` throws internally. Catching it prevents the redirect.  
**Fix:** Move `redirect()` outside try/catch, use conditional logic.  
**Docs:** https://nextjs.org/docs/app/api-reference/functions/redirect

## Performance Patterns

### 13. Image Without sizes Prop
**Severity:** warning  
**Pattern:** `next/image` without `sizes` prop  
**Why:** Browser downloads larger images than needed, hurting LCP.  
**Fix:** Add `sizes="(max-width: 768px) 100vw, 50vw"` or similar.  
**Docs:** https://nextjs.org/docs/app/api-reference/components/image#sizes

### 14. Font Without display Swap
**Severity:** warning  
**Pattern:** `next/font/google` without `display: 'swap'`  
**Why:** Flash of invisible text (FOIT) hurts CLS and UX.  
**Fix:** Add `display: 'swap'` to font configuration.  
**Docs:** https://nextjs.org/docs/app/api-reference/components/font#display

### 15. LCP Image Missing priority
**Severity:** warning  
**Pattern:** Hero/LCP image without `priority` prop  
**Why:** Browser prioritizes differently, delaying LCP.  
**Fix:** Add `priority` to the first above-the-fold image.  
**Docs:** https://nextjs.org/docs/app/api-reference/components/image#priority

### 16. Heavy Imports in Middleware
**Severity:** warning  
**Pattern:** `moment|lodash|chart.js|recharts` imported in `middleware.ts`  
**Why:** Middleware runs on every request. Heavy imports add latency.  
**Fix:** Move heavy logic to Route Handlers or API routes.  
**Docs:** https://nextjs.org/docs/app/building-your-application/routing/middleware

## Security Patterns

### 17. Server Env Vars Leaked to Client
**Severity:** error  
**Pattern:** `process.env.SECRET_*` used in client components  
**Why:** Server-only env vars become undefined or leaked to client bundle.  
**Fix:** Prefix public vars with `NEXT_PUBLIC_`, keep secrets server-only.  
**Docs:** https://nextjs.org/docs/app/building-your-application/configuring/environment-variables

### 18. Middleware Without matcher
**Severity:** warning  
**Pattern:** `middleware.ts` without `config.matcher`  
**Why:** Middleware runs on static assets (images, fonts), wasting resources.  
**Fix:** Add `matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)']`.  
**Docs:** https://nextjs.org/docs/app/building-your-application/routing/middleware#matcher

## Summary Table

| # | Pattern | Severity | Category |
|---|---------|----------|----------|
| 1 | getServerSideProps in App Router | error | architecture |
| 2 | Dynamic routes without generateStaticParams | warning | performance |
| 3 | Server Component importing 'use client' | warning | architecture |
| 4 | cookies()/headers() in static context | error | architecture |
| 5 | Fetch without explicit cache | warning | data |
| 6 | Server Action without revalidate | warning | data |
| 7 | No Suspense boundary for slow data | warning | performance |
| 8 | Root layout missing metadata | warning | seo |
| 9 | Static export without output: 'export' | error | deployment |
| 10 | No not-found.tsx | warning | error-handling |
| 11 | No error.tsx | warning | error-handling |
| 12 | redirect() in try/catch | warning | error-handling |
| 13 | Image without sizes prop | warning | performance |
| 14 | Font without display swap | warning | performance |
| 15 | LCP image missing priority | warning | performance |
| 16 | Heavy imports in middleware | warning | performance |
| 17 | Server env vars leaked to client | error | security |
| 18 | Middleware without matcher | warning | performance |