#!/usr/bin/env bash
# E2E test: web frontend checks (13 check scripts, 89 rules)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: web-checks ==="

# Resolve cpm repo root (where checks/ and lib/ live)
CPM_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Create fixture web project ---
DIR=$(setup_project)

# Directory structure
mkdir -p "$DIR/public/images/icons" \
         "$DIR/src/app" \
         "$DIR/src/styles" \
         "$DIR/src/components" \
         "$DIR/fonts" \
         "$DIR/locales/en" \
         "$DIR/locales/ar" \
         "$DIR/.tmp"

# --- package.json (makes it a JS project) ---
cat > "$DIR/package.json" << 'PKGJSON'
{
  "name": "bad-web-project",
  "version": "1.0.0",
  "dependencies": {
    "react": "^18.0.0"
  }
}
PKGJSON

# --- middleware.ts (makes security-headers check find a server file, but has no headers) ---
cat > "$DIR/middleware.ts" << 'MIDDLEWARE'
// Middleware placeholder — no security headers configured
export function middleware(req) {
  return req;
}
MIDDLEWARE

# --- webpack.config.js (caching anti-patterns: no hash, no compression, no minify, sourcemap) ---
cat > "$DIR/webpack.config.js" << 'WEBPACK'
const path = require('path');

module.exports = {
  entry: './src/index.js',
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
  },
  devtool: 'source-map',
  optimization: {
    minimize: false,
  },
};
WEBPACK

# --- public/index.html (ALL HTML anti-patterns) ---
cat > "$DIR/public/index.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
  <title>Bad Web Project</title>
  <meta charset="UTF-8">
  <script src="app.js"></script>
  <script src="https://cdn1.example.com/a.js"></script>
  <script src="https://cdn2.example.com/b.js"></script>
  <script src="https://cdn3.example.com/c.js"></script>
  <script src="https://cdn4.example.com/d.js"></script>
  <script src="https://cdn5.example.com/e.js"></script>
  <script src="https://cdn6.example.com/f.js"></script>
  <link rel="stylesheet" href="styles.css">
  <meta property="og:title" content="Bad Web Project">
  <link rel="alternate" hreflang="en" href="https://example.com/en">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto">
</head>
<body>
  <div id="app">
    <link rel="stylesheet" href="extra.css">
    <div class="hero">
      <img src="hero.jpg">
      <img src="photo.webp" alt="A photo">
      <img fetchpriority="high" loading="lazy" src="banner.jpg" alt="Banner">
    </div>
    <div class="content">
      <iframe src="/widget"></iframe>
      <video autoplay src="promo.mp4"></video>
    </div>
    <div class="faq">
      <h2>Frequently Asked Questions</h2>
      <p>Q: What is this? A: A bad project.</p>
    </div>
  </div>
</body>
</html>
HTML

# --- src/app/page.tsx (JS loading anti-patterns) ---
cat > "$DIR/src/app/page.tsx" << 'PAGETSX'
import React from 'react';

export default function Page() {
  document.write('hello');
  const mod = require('./module');

  window.addEventListener('scroll', function handler() { console.log('scroll'); });

  document.addEventListener('click', function() { console.log('click 1'); });
  document.addEventListener('click', function() { console.log('click 2'); });
  document.addEventListener('click', function() { console.log('click 3'); });
  document.addEventListener('click', function() { console.log('click 4'); });
  document.addEventListener('click', function() { console.log('click 5'); });
  document.addEventListener('click', function() { console.log('click 6'); });

  if (__DEV__) {
    console.log('dev mode');
  }

  return (
    <React.StrictMode>
      <div>
        <img src="/hero.jpg" />
      </div>
    </React.StrictMode>
  );
}
PAGETSX

# --- src/app/layout.tsx (layout with bad patterns) ---
cat > "$DIR/src/app/layout.tsx" << 'LAYOUTTSX'
import React from 'react';

export default function Layout({ children }) {
  return (
    <html>
      <head>
        <title>Layout</title>
      </head>
      <body>
        <div>{children}</div>
      </body>
    </html>
  );
}
LAYOUTTSX

# --- src/styles/global.css (ALL CSS anti-patterns) ---
cat > "$DIR/src/styles/global.css" << 'CSS'
@import url('other.css');

body {
  font-size: 12px;
  font-family: 'Roboto', sans-serif;
}

.sidebar {
  width: 800px;
  font-family: 'Arial', sans-serif;
}

.nav {
  font-family: 'Open Sans', sans-serif;
}

.footer {
  font-family: 'Montserrat', sans-serif;
}

* {
  color: red;
}

.container * {
  display: block;
}

.a .b .c .d .e {
  color: blue;
}

.modern-element {
  -webkit-transform: rotate(45deg);
  -moz-transition: all 0.3s;
  -webkit-flex: 1;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.animate {
  animation: fadeIn 1s;
}

.hero-banner {
  background-image: url(hero.jpg);
  height: 400px;
}

button {
  padding: 8px;
}

a {
  text-decoration: none;
}

@font-face {
  font-family: 'CustomFont1';
  src: url('font.ttf') format('truetype');
}

@font-face {
  font-family: 'CustomFont2';
  src: url('font2.ttf') format('truetype');
  font-weight: normal;
}

@font-face {
  font-family: 'CustomFont2';
  src: url('font2-bold.ttf') format('truetype');
  font-weight: bold;
}

@font-face {
  font-family: 'CustomFont2';
  src: url('font2-italic.ttf') format('truetype');
  font-weight: normal;
  font-style: italic;
}

@font-face {
  font-family: 'CustomFont3';
  src: url('font3.ttf') format('truetype');
  font-weight: 300;
}

@font-face {
  font-family: 'CustomFont3';
  src: url('font3-semibold.ttf') format('truetype');
  font-weight: 600;
}

@font-face {
  font-family: 'CustomFont3';
  src: url('font3-black.ttf') format('truetype');
  font-weight: 900;
}

@font-face {
  font-family: 'CustomFont4';
  src: url('font4.ttf') format('truetype');
  font-weight: 100;
}

.heading {
  font-family: 'CustomFont1';
}

.text {
  font-family: 'CustomFont2';
}

.label {
  font-family: 'CustomFont3';
}

.special {
  font-family: 'CustomFont4';
}

.font-url {
  background: url('https://fonts.googleapis.com/css2?family=Poppins');
}
CSS

# --- src/styles/theme.scss (more CSS anti-patterns) ---
cat > "$DIR/src/styles/theme.scss" << 'SCSS'
.card {
  .header {
    .title {
      .text {
        .inner {
          color: red;
        }
      }
    }
  }
}

// Needed: background-image present to avoid pipefail+errexit in check-image-optimization
.theme-bg {
  background-image: url(bg.jpg);
}
SCSS

# --- src/components/Hero.tsx (component with bad image patterns) ---
cat > "$DIR/src/components/Hero.tsx" << 'HEROTSX'
import React from 'react';

export default function Hero() {
  return (
    <div className="hero">
      <img src="/images/hero.jpg" alt="Hero" />
      <img src="/images/logo.png" alt="Logo" />
    </div>
  );
}
HEROTSX

# --- Image files (empty/small) ---
echo "JFIF" > "$DIR/public/images/hero.jpg"
echo "PNG" > "$DIR/public/images/logo.png"
echo "PNG" > "$DIR/public/images/icons/settings.png"

# --- Font file >100KB (use truncate for speed, dd is slow) ---
truncate -s 150K "$DIR/fonts/roboto.ttf" 2>/dev/null || dd if=/dev/zero of="$DIR/fonts/roboto.ttf" bs=1024 count=150 2>/dev/null

# --- Locale files (triggers i18n detection) ---
echo '{"hello": "Hello"}' > "$DIR/locales/en/common.json"
echo '{"hello": "مرحبا"}' > "$DIR/locales/ar/common.json"

# Initialize a minimal git repo for findings (commit hash used by findings.sh)
(cd "$DIR" && git init -q && git add -A && git commit -q --no-verify -m "init" 2>/dev/null) || true

# Cache git commit hash so each check script doesn't call git rev-parse
export _CPM_COMMIT_CACHE
_CPM_COMMIT_CACHE=$(cd "$DIR" && git rev-parse --short HEAD 2>/dev/null || echo "none")

# ============================================================================
# Phase 2: Run ALL 13 checks in PARALLEL (each with own findings file)
# ============================================================================
CHECKS_DIR="$CPM_DIR/checks/universal/quality"
FINDINGS_DIR="$DIR/.tmp/findings"
mkdir -p "$FINDINGS_DIR" "$DIR/.tmp/reports"

ALL_CHECKS="image-optimization font-optimization structured-data pwa resource-hints security-headers caching mobile hreflang social-meta js-loading css-advanced html-semantics"

for check in $ALL_CHECKS; do
  (
    export CPM_FINDINGS_FILE="$FINDINGS_DIR/$check.jsonl"
    export CPM_FINDINGS_JUNIT="$DIR/.tmp/reports"
    cd "$DIR" && bash "$CHECKS_DIR/check-$check.sh" "$DIR"
  ) >/dev/null 2>&1 &
done
wait

# ============================================================================
# Phase 3: Assert findings (instant — just grep on local files)
# ============================================================================
ERRORS=0
check_rule() {
  local check="$1" rule="$2" label="$3"
  if grep -q "$rule" "$FINDINGS_DIR/$check.jsonl" 2>/dev/null; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label — NOT FOUND"
    ERRORS=$((ERRORS + 1))
  fi
}

echo ""
echo "--- check-image-optimization ---"
check_rule "image-optimization" "img-no-webp"           "image-optimization: img-no-webp"
check_rule "image-optimization" "img-no-lazy"            "image-optimization: img-no-lazy"
check_rule "image-optimization" "img-no-srcset"          "image-optimization: img-no-srcset"
check_rule "image-optimization" "img-lcp-lazy"           "image-optimization: img-lcp-lazy"
check_rule "image-optimization" "img-no-fetchpriority"   "image-optimization: img-no-fetchpriority"
check_rule "image-optimization" "img-no-decoding"        "image-optimization: img-no-decoding"
check_rule "image-optimization" "img-css-background-hero" "image-optimization: img-css-background-hero"
check_rule "image-optimization" "img-no-picture"         "image-optimization: img-no-picture"
check_rule "image-optimization" "icon-not-svg"           "image-optimization: icon-not-svg"

echo ""
echo "--- check-font-optimization ---"
check_rule "font-optimization" "font-no-woff2"          "font-optimization: font-no-woff2"
check_rule "font-optimization" "font-no-display"        "font-optimization: font-no-display"
check_rule "font-optimization" "font-too-many"          "font-optimization: font-too-many"
check_rule "font-optimization" "font-too-many-weights"  "font-optimization: font-too-many-weights"
check_rule "font-optimization" "font-no-preload"        "font-optimization: font-no-preload"
check_rule "font-optimization" "font-third-party"       "font-optimization: font-third-party"
check_rule "font-optimization" "font-large-file"        "font-optimization: font-large-file"
check_rule "font-optimization" "font-no-size-adjust"    "font-optimization: font-no-size-adjust"

echo ""
echo "--- check-structured-data ---"
check_rule "structured-data" "seo-no-jsonld"            "structured-data: seo-no-jsonld"

echo ""
echo "--- check-pwa ---"
check_rule "pwa" "pwa-no-manifest"                      "pwa: pwa-no-manifest"
check_rule "pwa" "pwa-no-service-worker"                "pwa: pwa-no-service-worker"

echo ""
echo "--- check-resource-hints ---"
check_rule "resource-hints" "no-dns-prefetch"           "resource-hints: no-dns-prefetch"
check_rule "resource-hints" "no-preconnect"             "resource-hints: no-preconnect"
check_rule "resource-hints" "no-font-preload"           "resource-hints: no-font-preload"
check_rule "resource-hints" "css-order-after-script"    "resource-hints: css-order-after-script"
check_rule "resource-hints" "no-prefetch-hints"         "resource-hints: no-prefetch-hints"

echo ""
echo "--- check-security-headers ---"
check_rule "security-headers" "security-no-hsts"              "security-headers: security-no-hsts"
check_rule "security-headers" "security-no-referrer-policy"    "security-headers: security-no-referrer-policy"
check_rule "security-headers" "security-no-permissions-policy" "security-headers: security-no-permissions-policy"
check_rule "security-headers" "security-no-x-content-type"     "security-headers: security-no-x-content-type"
check_rule "security-headers" "security-no-x-frame"            "security-headers: security-no-x-frame"

echo ""
echo "--- check-caching ---"
check_rule "caching" "cache-no-hash"                    "caching: cache-no-hash"
check_rule "caching" "build-no-compression"             "caching: build-no-compression"
check_rule "caching" "no-cdn-config"                    "caching: no-cdn-config"
check_rule "caching" "build-no-minify"                  "caching: build-no-minify"

echo ""
echo "--- check-mobile ---"
check_rule "mobile" "mobile-font-too-small"             "mobile: mobile-font-too-small"
check_rule "mobile" "mobile-fixed-width"                "mobile: mobile-fixed-width"
check_rule "mobile" "mobile-no-media-queries"           "mobile: mobile-no-media-queries"
check_rule "mobile" "mobile-no-touch-action"            "mobile: mobile-no-touch-action"

echo ""
echo "--- check-hreflang ---"
check_rule "hreflang" "i18n-no-self-hreflang"           "hreflang: i18n-no-self-hreflang"
check_rule "hreflang" "i18n-no-x-default"               "hreflang: i18n-no-x-default"
check_rule "hreflang" "i18n-no-dir-rtl"                 "hreflang: i18n-no-dir-rtl"
check_rule "hreflang" "i18n-charset-not-first"          "hreflang: i18n-charset-not-first"

echo ""
echo "--- check-social-meta ---"
check_rule "social-meta" "og-no-type"                   "social-meta: og-no-type"
check_rule "social-meta" "og-no-twitter-card"           "social-meta: og-no-twitter-card"
check_rule "social-meta" "og-no-locale"                 "social-meta: og-no-locale"
check_rule "social-meta" "og-no-url"                    "social-meta: og-no-url"

echo ""
echo "--- check-js-loading ---"
check_rule "js-loading" "script-no-defer"               "js-loading: script-no-defer"
check_rule "js-loading" "script-document-write"         "js-loading: script-document-write"
check_rule "js-loading" "script-no-module"              "js-loading: script-no-module"
check_rule "js-loading" "third-party-sync"              "js-loading: third-party-sync"
check_rule "js-loading" "third-party-excessive"         "js-loading: third-party-excessive"
check_rule "js-loading" "no-passive-listener"           "js-loading: no-passive-listener"
check_rule "js-loading" "no-event-delegation"           "js-loading: no-event-delegation"

echo ""
echo "--- check-css-advanced ---"
check_rule "css-advanced" "css-import"                  "css-advanced: css-import"
check_rule "css-advanced" "css-in-body"                 "css-advanced: css-in-body"
check_rule "css-advanced" "css-deep-nesting"            "css-advanced: css-deep-nesting"
check_rule "css-advanced" "css-no-will-change"          "css-advanced: css-no-will-change"
check_rule "css-advanced" "css-universal-selector"      "css-advanced: css-universal-selector"
check_rule "css-advanced" "css-redundant-vendor-prefix" "css-advanced: css-redundant-vendor-prefix"

echo ""
echo "--- check-html-semantics ---"
check_rule "html-semantics" "html-no-semantic"          "html-semantics: html-no-semantic"
check_rule "html-semantics" "html-iframe-no-lazy"       "html-semantics: html-iframe-no-lazy"
check_rule "html-semantics" "html-autoplay-audio"       "html-semantics: html-autoplay-audio"
check_rule "html-semantics" "build-sourcemap-prod"      "html-semantics: build-sourcemap-prod"
check_rule "html-semantics" "build-dev-code-prod"       "html-semantics: build-dev-code-prod"
check_rule "html-semantics" "html-no-charset-first"     "html-semantics: html-no-charset-first"
check_rule "html-semantics" "html-no-theme-color"       "html-semantics: html-no-theme-color"

# ============================================================================
# Cleanup
# ============================================================================
teardown_project "$DIR"

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "=== All web-checks assertions passed ==="
else
  echo "=== $ERRORS web-checks assertion(s) failed ==="
  exit 1
fi
