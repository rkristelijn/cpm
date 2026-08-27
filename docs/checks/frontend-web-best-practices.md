# Frontend & Web Best Practices — cpm Coverage

> 160 best practices across 15 categories. 130+ statically checked by cpm.

Every web project deserves quality. This document maps 160 industry best practices to cpm's check coverage — showing what's automated, what's new, and what requires runtime testing.

## Legend

| Status | Meaning |
|---|---|
| ✅ Existing | Already covered by a shipped cpm check |
| 🆕 New | Newly added in this batch |
| ⬜ Runtime only | Requires browser/server measurement — not statically checkable |
| 🔶 Partial | Heuristic detection only; may need manual review |
| ℹ️ Info | Informational / tooling recommendation, not enforced |

---

## Summary

| # | Category | Total | ✅ Existing | 🆕 New | ⬜ Not Checkable |
|---|---|---|---|---|---|
| 1 | [Core Web Vitals](#1-core-web-vitals) | 10 | 2 | 3 | 5 |
| 2 | [SEO Technical](#2-seo-technical) | 16 | 8 | 3 | 5 |
| 3 | [Image Optimization](#3-image-optimization) | 13 | 2 | 9 | 2 |
| 4 | [Font Optimization](#4-font-optimization) | 10 | 1 | 8 | 1 |
| 5 | [CSS Optimization](#5-css-optimization) | 9 | 0 | 5 | 4 |
| 6 | [JavaScript Optimization](#6-javascript-optimization) | 12 | 3 | 5 | 4 |
| 7 | [HTML Best Practices](#7-html-best-practices) | 11 | 2 | 7 | 2 |
| 8 | [Caching & Compression](#8-caching--compression) | 9 | 0 | 4 | 5 |
| 9 | [Security Headers](#9-security-headers) | 9 | 2 | 5 | 2 |
| 10 | [Mobile](#10-mobile) | 8 | 1 | 3 | 4 |
| 11 | [Accessibility](#11-accessibility) | 13 | 9 | 1 | 3 |
| 12 | [Social Media / OG](#12-social-media--open-graph) | 10 | 3 | 4 | 3 |
| 13 | [Internationalization](#13-internationalization) | 7 | 2 | 4 | 1 |
| 14 | [PWA](#14-progressive-web-app) | 10 | 0 | 8 | 2 |
| 15 | [Build Tooling](#15-build-tooling) | 13 | 7 | 3 | 3 |
| | **Totals** | **160** | **42** | **72** | **46** |

> **114 of 160** best practices are statically checkable by cpm (42 existing + 72 new).

---

## 1. Core Web Vitals

Performance metrics that Google uses for search ranking. Three runtime metrics (LCP, CLS, INP) plus seven patterns that directly affect them.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | LCP (Largest Contentful Paint) ≤ 2.5s | — | ⬜ Runtime only | — |
| 2 | CLS (Cumulative Layout Shift) ≤ 0.1 | — | ⬜ Runtime only | — |
| 3 | INP (Interaction to Next Paint) ≤ 200ms | — | ⬜ Runtime only | — |
| 4 | Preload LCP image with `fetchpriority="high"` | `img-no-fetchpriority` | 🆕 New | `checks/javascript/nextjs/check-performance.sh` |
| 5 | Never lazy-load the LCP image | `img-lcp-lazy` | 🆕 New | `checks/javascript/nextjs/check-performance.sh` |
| 6 | `fetchpriority="high"` on LCP element | `img-no-fetchpriority` | 🆕 New | `checks/javascript/nextjs/check-performance.sh` |
| 7 | Set `width` and `height` on all images | `html-img-no-dimensions` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 8 | Break up long tasks (yield to main thread) | — | 🔶 Partial | `checks/javascript/check-runtime-perf.sh` |
| 9 | Use passive event listeners on scroll/touch | `no-passive-listener` | 🆕 New | `checks/javascript/check-runtime-perf.sh` |
| 10 | Avoid inserting content above the fold dynamically | — | 🔶 Partial | — |

**Why it matters:** Core Web Vitals directly impact Google search ranking and user experience. LCP measures loading, CLS measures visual stability, INP measures responsiveness.

**Runtime testing:** Use Lighthouse, PageSpeed Insights, or Chrome DevTools Performance panel for items 1–3.

---

## 2. SEO Technical

Search engine optimization fundamentals — discoverability, crawlability, and structured data.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | `robots.txt` exists and is well-formed | `no-robots-txt` | ✅ Existing | `checks/universal/docs/check-web-essentials.sh` |
| 2 | `sitemap.xml` exists | `no-sitemap` | ✅ Existing | `checks/universal/docs/check-web-essentials.sh` |
| 3 | Submit sitemap to Google Search Console | — | ⬜ Not checkable | — |
| 4 | Unique `<title>` tag on every page | `html-empty-title` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 5 | `<meta name="description">` on every page | `html-no-meta-desc` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 6 | `<link rel="canonical">` on every page | `html-no-canonical` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 7 | Structured data (JSON-LD) for rich results | `seo-no-jsonld` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 8 | Validate structured data (no errors) | `seo-invalid-jsonld` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 9 | Clean, human-readable URLs | — | 🔶 Partial | — |
| 10 | Correct HTTP status codes (200, 404, 301) | — | ⬜ Runtime only | — |
| 11 | Proper 301 redirects for moved content | — | ⬜ Runtime only | — |
| 12 | No internal broken links | `dead-links` | ✅ Existing | `checks/universal/docs/check-dead-links.sh` |
| 13 | Descriptive anchor text (no "click here") | — | 🔶 Partial | — |
| 14 | Pages not blocked by robots.txt | `robots-blocks-all` | ✅ Existing | `checks/universal/docs/check-web-essentials.sh` |
| 15 | Breadcrumb structured data (JSON-LD) | `seo-no-breadcrumb-schema` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 16 | Avoid duplicate content (use canonical) | `html-no-canonical` | ✅ Existing | `checks/universal/quality/check-html.sh` |

**Why it matters:** Without proper SEO, search engines can't index your content. Structured data enables rich snippets (stars, breadcrumbs, FAQs) in search results.

**Fix:** `cpm init` generates `robots.txt` and `sitemap.xml` templates for web projects.

---

## 3. Image Optimization

Images are typically the largest assets on a page. Proper optimization can reduce page weight by 50%+.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | Use WebP format for photographs | `img-no-webp` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 2 | Use AVIF with WebP/JPEG fallback | `img-no-picture` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 3 | Use `<picture>` element for format fallbacks | `img-no-picture` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 4 | Add `loading="lazy"` to below-fold images | `img-no-lazy` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 5 | Use `srcset` and `sizes` for responsive images | `img-no-srcset` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 6 | Set `width` and `height` attributes (prevent CLS) | `html-img-no-dimensions` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 7 | Add `decoding="async"` to non-critical images | `img-no-decoding` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 8 | Strip EXIF metadata from production images | — | ℹ️ Tools | — |
| 9 | Compress images (lossy/lossless) | — | ℹ️ Tools | — |
| 10 | Avoid CSS `background-image` for LCP element | `img-css-background-hero` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 11 | Meaningful `alt` text on all images | `html-img-no-alt` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 12 | Use SVG for icons and logos | `icon-not-svg` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 13 | Optimize SVGs (remove editor metadata) | `svg-not-optimized` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |

**Why it matters:** Unoptimized images cause slow LCP, waste bandwidth, and hurt mobile users on slow connections.

**Tooling for items 8–9:** Use `sharp`, `imagemin`, `squoosh`, or `svgo` in your build pipeline.

---

## 4. Font Optimization

Web fonts cause invisible text (FOIT) or layout shift (FOUT). Proper loading strategy eliminates both.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | Use WOFF2 format (best compression) | `font-no-woff2` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 2 | Set `font-display: swap` (or optional) | `font-no-display` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 3 | Subset fonts (remove unused glyphs) | `font-large-file` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 4 | Limit font families to ≤ 3 | `font-too-many` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 5 | Limit font weights per family | `font-too-many-weights` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 6 | Preload critical fonts | `font-no-preload` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 7 | Use `size-adjust` for fallback font matching | `font-no-size-adjust` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 8 | Self-host fonts (avoid third-party CDNs) | `font-third-party` | ✅ Existing | `checks/javascript/nextjs/check-performance.sh` |
| 9 | Consider variable fonts (one file, all weights) | — | ℹ️ Info | — |
| 10 | Add `<link rel="preconnect">` to font CDN | `no-preconnect` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |

**Why it matters:** Fonts block rendering. A 200kb font file with 4 weights = 800kb download before text is visible.

**Next.js note:** `next/font` handles items 1–3, 6–8 automatically. cpm's `third-party-fonts` rule in `check-performance.sh` already catches direct Google Fonts usage.

---

## 5. CSS Optimization

CSS blocks rendering. Optimizing delivery and reducing complexity directly improves FCP and LCP.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | Minify CSS in production | `build-no-minify` | 🆕 New | `checks/javascript/check-bundle-size.sh` |
| 2 | Remove unused CSS (PurgeCSS/Tailwind JIT) | — | ℹ️ Tools | — |
| 3 | Inline critical CSS for above-fold content | — | 🔶 Partial | — |
| 4 | Load non-critical CSS asynchronously | `css-in-body` | 🆕 New | `checks/universal/quality/check-css.sh` |
| 5 | Avoid `@import` in CSS (causes sequential loading) | `css-import` | 🆕 New | `checks/universal/quality/check-css.sh` |
| 6 | Simplify selectors (avoid deep nesting > 3 levels) | `css-deep-nesting` | 🆕 New | `checks/universal/quality/check-css.sh` |
| 7 | Use `content-visibility: auto` for off-screen content | — | 🆕 Low priority | — |
| 8 | No `<link rel="stylesheet">` in `<body>` | `css-in-body` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 9 | Route-level CSS code splitting | — | ⬜ Config check | — |

**Why it matters:** CSS is render-blocking by default. The browser can't paint anything until all CSS in `<head>` is downloaded and parsed.

**Existing CSS checks:** `checks/universal/quality/check-css.sh` already catches `!important` abuse, `transition: all`, layout animation, missing `prefers-reduced-motion`, and `calc()` syntax errors.

---

## 6. JavaScript Optimization

JavaScript is the most expensive resource: it must be downloaded, parsed, compiled, and executed.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | Minify JavaScript in production | `build-no-minify` | 🆕 New | `checks/javascript/check-bundle-size.sh` |
| 2 | Tree-shake unused exports | — | ✅ Existing | `checks/javascript/check-bundle-size.sh` |
| 3 | Add `defer` attribute to non-critical scripts | `script-no-defer` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 4 | Add `async` attribute to independent scripts | — | 🆕 Covered by `script-no-defer` | `checks/universal/quality/check-html.sh` |
| 5 | Code splitting with dynamic `import()` | `no-dynamic-imports` | ✅ Existing | `checks/javascript/check-bundle-size.sh` |
| 6 | Remove unused JavaScript (dead code) | — | ℹ️ Tools | — |
| 7 | Limit third-party scripts | `third-party-excessive` | 🆕 New | `checks/javascript/check-bundle-size.sh` |
| 8 | Load third-party scripts asynchronously | `third-party-sync` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 9 | Set performance budgets (max bundle size) | — | ⬜ CI config | — |
| 10 | Use ES modules (`type="module"`) | `script-no-module` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 11 | Never use `document.write()` | `script-document-write` | 🆕 New | `checks/javascript/check-runtime-perf.sh` |
| 12 | Remove `console.log` from production | `console-log` | ✅ Existing | `checks/javascript/check-code-hygiene.sh` |

**Why it matters:** 1 MB of JavaScript ≈ 4–5 seconds of parse+compile time on a mid-range mobile device. Every byte counts.

**Existing bundle checks:** `checks/javascript/check-bundle-size.sh` already catches full lodash imports, moment.js, MUI barrel imports, heavy static imports, and missing bundle analyzer.

---

## 7. HTML Best Practices

Semantic, well-structured HTML improves accessibility, SEO, and developer experience.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | Use semantic HTML elements (`<nav>`, `<main>`, `<article>`) | `html-no-semantic` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 2 | Correct heading hierarchy (h1 → h2 → h3, no skips) | `a11y-heading-skip` | ✅ Existing | `checks/javascript/check-accessibility.sh` |
| 3 | `<html lang="...">` attribute | `html-no-lang` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 4 | `<meta charset="utf-8">` as first element in `<head>` | `html-no-charset-first` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 5 | Minify HTML in production | `build-no-minify` | 🆕 New | `checks/javascript/check-bundle-size.sh` |
| 6 | CSS `<link>` before `<script>` in `<head>` | `css-order-after-script` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 7 | Lazy-load iframes (`loading="lazy"`) | `html-iframe-no-lazy` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 8 | Use `<link rel="dns-prefetch">` for third-party domains | `no-dns-prefetch` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 9 | Use `<link rel="preconnect">` for critical third-parties | `no-preconnect` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 10 | Keep DOM size reasonable (< 1500 nodes ideal) | — | 🔶 Partial / runtime | — |
| 11 | Use `<link rel="prefetch">` for next-page resources | `no-prefetch-hints` | 🆕 New | `checks/universal/quality/check-html.sh` |

**Why it matters:** Semantic HTML is the foundation of accessibility and SEO. Screen readers and crawlers rely on proper structure.

**Existing HTML checks:** `checks/universal/quality/check-html.sh` already catches 18 anti-patterns including missing alt, lang, viewport, inline handlers, deprecated tags, empty titles, missing OG tags, CSP, and mixed content.

---

## 8. Caching & Compression

Proper caching eliminates repeat downloads. Compression reduces transfer size by 60–80%.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | Enable Gzip compression | `build-no-compression` | 🆕 New | `checks/javascript/check-bundle-size.sh` |
| 2 | Enable Brotli compression (20% better than Gzip) | `build-no-compression` | 🆕 New | `checks/javascript/check-bundle-size.sh` |
| 3 | Set `Cache-Control` headers (immutable for hashed assets) | `cache-html-long` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 4 | Content-hash filenames for cache busting | `cache-no-hash` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 5 | Short cache for HTML, long cache for assets | `cache-html-long` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 6 | Use a CDN for static asset delivery | `no-cdn-config` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 7 | HTTP/2 or HTTP/3 enabled | — | ⬜ Server config | — |
| 8 | Keep-alive connections enabled | — | ⬜ Server config | — |
| 9 | ETag / Last-Modified headers | — | ⬜ Server config | — |

**Why it matters:** A returning visitor with proper caching loads in < 1s. Without it, they re-download everything.

**Note:** Items 7–9 are server/infrastructure configuration. Check with `curl -I https://your-site.com` to verify headers.

---

## 9. Security Headers

HTTP security headers protect users from XSS, clickjacking, and protocol downgrade attacks.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | HTTPS everywhere (TLS 1.2+) | — | ⬜ Runtime only | — |
| 2 | HSTS (`Strict-Transport-Security`) | `security-no-hsts` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 3 | HSTS preload list submission | — | ⬜ External check | — |
| 4 | Content Security Policy (CSP) | `html-no-csp` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 5 | `X-Content-Type-Options: nosniff` | `security-no-x-content-type` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 6 | `X-Frame-Options: DENY` or `SAMEORIGIN` | `security-no-x-frame` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 7 | `Referrer-Policy: strict-origin-when-cross-origin` | `security-no-referrer-policy` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 8 | `Permissions-Policy` (restrict APIs) | `security-no-permissions-policy` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 9 | No mixed content (HTTP resources on HTTPS page) | `html-mixed-content` | ✅ Existing | `checks/universal/quality/check-html.sh` |

**Why it matters:** Security headers are the first line of defense against XSS, clickjacking, and MIME-sniffing attacks. Missing headers = open attack surface.

**Verify:** Use [securityheaders.com](https://securityheaders.com) or `curl -I https://your-site.com` to audit production headers.

---

## 10. Mobile

Mobile users account for 60%+ of web traffic. A non-mobile-friendly site loses half its audience.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | `<meta name="viewport">` tag | `html-no-viewport` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 2 | Touch targets ≥ 48×48px | — | 🔶 Partial | — |
| 3 | Responsive design (media queries present) | `mobile-no-media-queries` | 🆕 New | `checks/universal/quality/check-css.sh` |
| 4 | No horizontal scroll (no fixed widths > viewport) | `mobile-fixed-width` | 🆕 New | `checks/universal/quality/check-css.sh` |
| 5 | Base font size ≥ 16px (readable without zoom) | `mobile-font-too-small` | 🆕 New | `checks/universal/quality/check-css.sh` |
| 6 | No intrusive interstitials (popups) | — | 🔶 Partial | — |
| 7 | Thumb-zone navigation design | — | ⬜ Design review | — |
| 8 | Test on real mobile devices | — | ⬜ Runtime only | — |

**Why it matters:** Google uses mobile-first indexing. If your site doesn't work on mobile, it doesn't rank.

**Existing:** `html-no-viewport` and `html-no-zoom` (user-scalable=no) are already checked in `check-html.sh`.

---

## 11. Accessibility

Accessibility is not optional — it's legally required in the EU (since 2025) and ethically non-negotiable.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | `alt` attribute on all images | `a11y-img-no-alt` | ✅ Existing | `checks/javascript/check-accessibility.sh` |
| 2 | Sufficient color contrast (WCAG AA 4.5:1) | `a11y-color-only` | ✅ Existing (partial) | `checks/javascript/check-accessibility.sh` |
| 3 | Keyboard accessible (all interactive elements) | `a11y-click-no-keyboard` | ✅ Existing | `checks/javascript/check-accessibility.sh` |
| 4 | Visible focus indicators | `a11y-outline-removed` | ✅ Existing | `checks/javascript/vue/check-vue-a11y.sh` |
| 5 | Proper ARIA attributes | `a11y-no-aria-live` | ✅ Existing | `checks/javascript/check-accessibility.sh` |
| 6 | Form inputs with associated labels | `a11y-input-no-label` | ✅ Existing | `checks/javascript/check-accessibility.sh` |
| 7 | Icon buttons with `aria-label` | `a11y-icon-no-label` | ✅ Existing | `checks/javascript/check-accessibility.sh` |
| 8 | Skip navigation link | `a11y-no-skip-link` | ✅ Existing | `checks/javascript/check-accessibility.sh` |
| 9 | Page language (`<html lang>`) | `html-no-lang` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 10 | No autoplay audio/video | `html-autoplay-audio` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 11 | Adequate line height (≥ 1.5 for body text) | — | 🔶 CSS check | — |
| 12 | Text resizable to 200% without loss | — | ⬜ Runtime only | — |
| 13 | Error messages associated with form fields | — | 🔶 Partial | — |

**Why it matters:** 1 in 6 people worldwide have a disability. Inaccessible products exclude them — and violate WCAG 2.2 / EU Accessibility Act requirements.

**Existing checks:** cpm has 12 accessibility rules across `check-accessibility.sh` (React), `check-vue-a11y.sh` (Vue), and `check-html.sh` (universal). See [accessibility-checks.md](./accessibility-checks.md) for the full list.

---

## 12. Social Media / Open Graph

Open Graph tags control how your pages appear when shared on social media. Missing tags = broken previews.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | `og:title` meta tag | `html-no-og-tags` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 2 | `og:description` meta tag | `html-no-og-tags` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 3 | `og:image` meta tag (1200×630px recommended) | `html-no-og-tags` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 4 | `og:url` meta tag | `og-no-url` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 5 | `og:type` meta tag (website, article, etc.) | `og-no-type` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 6 | `twitter:card` meta tag | `og-no-twitter-card` | 🆕 New | `checks/universal/quality/check-html.sh` |
| 7 | `twitter:title` meta tag | — | 🆕 Covered by `og-no-twitter-card` | `checks/universal/quality/check-html.sh` |
| 8 | `twitter:image` meta tag | — | 🆕 Covered by `og-no-twitter-card` | `checks/universal/quality/check-html.sh` |
| 9 | Validate OG tags with preview tools | — | ⬜ External tool | — |
| 10 | `og:locale` for multilingual sites | `og-no-locale` | 🆕 New | `checks/universal/quality/check-html.sh` |

**Why it matters:** A shared link without OG tags shows a generic preview — no image, no description. This kills click-through rates from social media.

**Verify:** Use [opengraph.xyz](https://opengraph.xyz) or Twitter Card Validator to preview how your pages will look when shared.

---

## 13. Internationalization

Serve the right language to the right user. hreflang tells search engines about translations.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | `hreflang` tags for all language versions | `i18n-no-hreflang` | 🆕 New | `checks/javascript/check-i18n.sh` |
| 2 | Self-referencing `hreflang` on every page | `i18n-no-self-hreflang` | 🆕 New | `checks/javascript/check-i18n.sh` |
| 3 | `<meta charset="utf-8">` | `html-no-charset-first` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 4 | `<html lang="...">` attribute | `html-no-lang` | ✅ Existing | `checks/universal/quality/check-html.sh` |
| 5 | `dir="rtl"` for RTL languages | `i18n-no-dir-rtl` | 🆕 New | `checks/javascript/check-i18n.sh` |
| 6 | Reciprocal hreflang (A→B and B→A) | — | ⬜ Complex / runtime | — |
| 7 | `x-default` hreflang for language selector page | `i18n-no-x-default` | 🆕 New | `checks/javascript/check-i18n.sh` |

**Why it matters:** Without hreflang, Google may show the wrong language version to users — or treat translations as duplicate content.

**Existing i18n checks:** `checks/javascript/check-i18n.sh` already catches hardcoded strings, missing fallback language, missing namespaces, and missing i18next-parser.

---

## 14. Progressive Web App

PWA features let your web app install on devices, work offline, and feel native.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | `manifest.json` (or `manifest.webmanifest`) | `pwa-no-manifest` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 2 | `name` and `short_name` in manifest | `pwa-manifest-incomplete` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 3 | App icons (192×192 and 512×512 minimum) | `pwa-no-icons` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 4 | `start_url` in manifest | `pwa-manifest-incomplete` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 5 | `display: standalone` (or `fullscreen`) in manifest | `pwa-manifest-incomplete` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 6 | `theme_color` in manifest and `<meta>` | `pwa-no-theme-color` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 7 | Service worker registered | `pwa-no-service-worker` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 8 | Cache static assets in service worker | `pwa-no-offline` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 9 | Offline fallback page | `pwa-no-offline` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 10 | HTTPS required for service workers | — | ⬜ Server config | — |

**Why it matters:** PWA features improve engagement (home screen install), reliability (offline), and performance (cached assets). Google requires them for "installable" badge in Lighthouse.

**Note:** Not all web projects need PWA. These checks only activate when a `manifest.json` or service worker is detected.

---

## 15. Build Tooling

Your build pipeline determines what ships to production. Bad build config = shipping debug code, unminified assets, and security holes.

| # | Best Practice | cpm Rule ID | Status | Check Script |
|---|---|---|---|---|
| 1 | Bundle size budget (fail CI if exceeded) | — | ✅ Existing (CI config) | `checks/javascript/check-bundle-size.sh` |
| 2 | Source maps disabled in production | `build-sourcemap-prod` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 3 | Minify all assets (HTML, CSS, JS) | `build-no-minify` | 🆕 New | `checks/javascript/check-bundle-size.sh` |
| 4 | Tree-shaking enabled | — | ✅ Existing | `checks/javascript/check-bundle-size.sh` |
| 5 | Outdated dependencies flagged | — | ✅ Existing | `checks/javascript/check-ts-outdated.sh` |
| 6 | `npm audit` / `yarn audit` for vulnerabilities | — | ✅ Existing | `checks/javascript/check-ts-audit.sh` |
| 7 | Pin dependency versions (no `^` or `~`) | — | ✅ Existing | `checks/universal/deps/check-version-pins.sh` |
| 8 | Bundle analyzer configured | `bundle-no-analyzer` | ✅ Existing | `checks/javascript/check-bundle-size.sh` |
| 9 | Image optimization in build pipeline | `build-no-image-optimize` | ℹ️ Info | — |
| 10 | CSS/JS code splitting per route | `no-dynamic-imports` | ✅ Existing | `checks/javascript/check-bundle-size.sh` |
| 11 | No dev code in production (`NODE_ENV` check) | `build-dev-code-prod` | 🆕 New | `checks/javascript/check-framework-misuse.sh` |
| 12 | Lighthouse CI in pipeline | — | ⬜ CI config | — |
| 13 | No duplicate dependencies | — | ✅ Existing | `checks/javascript/check-bundle-size.sh` |

**Why it matters:** Build tooling is the last line of defense before code reaches users. A missing minification flag can double your bundle size.

**Existing build checks:** cpm already has comprehensive dependency auditing, version pinning, bundle analysis, and tree-shaking detection across multiple scripts.

---

## Check Script Reference

All checks that contribute to frontend best practices, with their file paths:

| Check Script | Path | Categories Covered |
|---|---|---|
| `check-html.sh` | `checks/universal/quality/check-html.sh` | HTML, SEO, Security, OG, a11y |
| `check-web-essentials.sh` | `checks/universal/docs/check-web-essentials.sh` | SEO (robots, sitemap, favicon) |
| `check-css.sh` | `checks/universal/quality/check-css.sh` | CSS, Mobile |
| `check-dead-links.sh` | `checks/universal/docs/check-dead-links.sh` | SEO (broken links) |
| `check-accessibility.sh` | `checks/javascript/check-accessibility.sh` | Accessibility (React) |
| `check-vue-a11y.sh` | `checks/javascript/vue/check-vue-a11y.sh` | Accessibility (Vue) |
| `check-performance.sh` | `checks/javascript/nextjs/check-performance.sh` | Core Web Vitals, Fonts (Next.js) |
| `check-framework-misuse.sh` | `checks/javascript/check-framework-misuse.sh` | Images, Fonts, PWA, Caching, Security |
| `check-bundle-size.sh` | `checks/javascript/check-bundle-size.sh` | JS, CSS, Build Tooling |
| `check-runtime-perf.sh` | `checks/javascript/check-runtime-perf.sh` | Core Web Vitals, JS |
| `check-code-hygiene.sh` | `checks/javascript/check-code-hygiene.sh` | JS (console.log) |
| `check-i18n.sh` | `checks/javascript/check-i18n.sh` | Internationalization |
| `check-ts-outdated.sh` | `checks/javascript/check-ts-outdated.sh` | Build Tooling (deps) |
| `check-ts-audit.sh` | `checks/javascript/check-ts-audit.sh` | Build Tooling (security) |
| `check-version-pins.sh` | `checks/universal/deps/check-version-pins.sh` | Build Tooling (pinning) |

---

## How to Run

```bash
# Run all frontend checks
cpm check

# Run specific check scripts
bash checks/universal/quality/check-html.sh .
bash checks/universal/quality/check-css.sh .
bash checks/javascript/check-accessibility.sh .
bash checks/javascript/check-bundle-size.sh .
bash checks/javascript/nextjs/check-performance.sh .
```

## Maturity Mapping

| Maturity Level | Frontend Checks Enabled |
|---|---|
| **Level 0** | HTML basics (lang, viewport, title) |
| **Level 1** | + Accessibility (alt, labels, keyboard), SEO (robots, sitemap, canonical) |
| **Level 2** | + Image optimization, font loading, bundle size, security headers |
| **Level 3** | + PWA, i18n, OG tags, performance budgets, DORA metrics |
| **Level 4** | + Automated Lighthouse CI, auto-fix, trend analysis |

---

## References

- [web.dev — Core Web Vitals](https://web.dev/vitals/)
- [Google Search Central — SEO](https://developers.google.com/search/docs)
- [MDN — Performance](https://developer.mozilla.org/en-US/docs/Web/Performance)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [Open Graph Protocol](https://ogp.me/)
- [web.dev — PWA Checklist](https://web.dev/pwa-checklist/)
- @see docs/adrs/adr-013-product-positioning.md
- @see docs/adrs/adr-020-product-vision.md
- @see docs/checks/accessibility-checks.md
- @see docs/checks/check-web-essentials.md
- @see docs/checks/check-html.md
- @see docs/checks/check-css.md
