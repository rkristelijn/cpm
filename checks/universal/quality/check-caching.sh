#!/usr/bin/env bash
# checks/universal/quality/check-caching.sh
# @see ADR-129
# Web caching anti-patterns: no content-hash, no compression, wrong cache headers, no CDN, no minification
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "caching" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# IS_WEB detectie
IS_WEB=false
[ -f "$REPO/index.html" ] && IS_WEB=true
[ -d "$REPO/public" ] && IS_WEB=true
[ -d "$REPO/app" ] && [ -f "$REPO/package.json" ] && IS_WEB=true
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && IS_WEB=true
[ -f "$REPO/angular.json" ] && IS_WEB=true
[ -f "$REPO/vite.config.ts" ] && IS_WEB=true
[ -f "$REPO/nuxt.config.ts" ] && IS_WEB=true
[ "$IS_WEB" = false ] && exit 0

# --- Collect build config files ---
BUILD_CONFIGS=$(find "$REPO" \( \
  -name "webpack.config.*" -o \
  -name "vite.config.*" -o \
  -name "rollup.config.*" -o \
  -name "next.config.*" -o \
  -name "esbuild.config.*" \
  \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" 2>/dev/null || true)

# --- Rule 1: cache-no-hash — Build config without content-hash in output filenames ---
if [ -n "$BUILD_CONFIGS" ]; then
  HAS_HASH=false
  while IFS= read -r cfg; do
    [ -z "$cfg" ] && continue
    # Check for [contenthash], [hash], contenthash, hashDigest, hash: true, etc.
    if grep -qE '\[contenthash\]|\[hash\]|\[chunkhash\]|contenthash|hashDigest|\.hash\b' "$cfg" 2>/dev/null; then
      HAS_HASH=true
      break
    fi
    # Vite/Rollup: entryFileNames/chunkFileNames/assetFileNames with hash
    if grep -qE 'entryFileNames.*hash|chunkFileNames.*hash|assetFileNames.*hash' "$cfg" 2>/dev/null; then
      HAS_HASH=true
      break
    fi
  done <<< "$BUILD_CONFIGS"

  if [ "$HAS_HASH" = false ]; then
    FIRST_CFG=$(echo "$BUILD_CONFIGS" | head -1)
    REL_CFG="${FIRST_CFG#$REPO/}"
    findings_add "warning" "$REL_CFG" "cache-no-hash" \
      "Build config without content-hash in output filenames — browsers serve stale assets after deploy" \
      "Add [contenthash] to output filenames (webpack) or configure build.rollupOptions.output with hash (vite)" \
      "https://developer.chrome.com/docs/lighthouse/performance/uses-long-cache-ttl"
  fi
fi

# --- Rule 2: build-no-compression — No gzip/brotli compression plugin ---
if [ -n "$BUILD_CONFIGS" ]; then
  HAS_COMPRESSION=false
  while IFS= read -r cfg; do
    [ -z "$cfg" ] && continue
    if grep -qEi 'CompressionPlugin|compression-webpack-plugin|vite-plugin-compression|rollup-plugin-gzip|brotli|@rollup/plugin-terser.*compress' "$cfg" 2>/dev/null; then
      HAS_COMPRESSION=true
      break
    fi
  done <<< "$BUILD_CONFIGS"

  # Also check package.json for compression plugins
  if [ "$HAS_COMPRESSION" = false ] && [ -f "$REPO/package.json" ]; then
    if grep -qEi 'compression-webpack-plugin|vite-plugin-compression|rollup-plugin-gzip' "$REPO/package.json" 2>/dev/null; then
      HAS_COMPRESSION=true
    fi
  fi

  if [ "$HAS_COMPRESSION" = false ]; then
    FIRST_CFG=$(echo "$BUILD_CONFIGS" | head -1)
    REL_CFG="${FIRST_CFG#$REPO/}"
    findings_add "warning" "$REL_CFG" "build-no-compression" \
      "No gzip/brotli compression plugin in build config — serving uncompressed assets wastes bandwidth" \
      "Add compression-webpack-plugin (webpack) or vite-plugin-compression (vite)" \
      "https://developer.chrome.com/docs/lighthouse/performance/uses-text-compression"
  fi
fi

# --- Rule 3: cache-html-long — Server config with long cache-control for HTML ---
SERVER_CONFIGS=$(find "$REPO" \( \
  -name "nginx.conf" -o -name "nginx*.conf" -o \
  -name "vercel.json" -o \
  -name "_headers" -o \
  -name "netlify.toml" -o \
  -name ".htaccess" \
  \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null || true)

if [ -n "$SERVER_CONFIGS" ]; then
  while IFS= read -r srvconf; do
    [ -z "$srvconf" ] && continue
    REL_SRV="${srvconf#$REPO/}"

    case "$(basename "$srvconf")" in
      nginx*.conf|nginx.conf)
        # Look for html location block with long cache (max-age > 3600 for html)
        if grep -A5 'location.*\.html' "$srvconf" 2>/dev/null | grep -qE 'max-age=[0-9]{5,}|immutable' 2>/dev/null; then
          findings_add "warning" "$REL_SRV" "cache-html-long" \
            "Long cache-control on HTML files — users won't see updates without hard refresh" \
            "Use 'Cache-Control: no-cache' or 'max-age=0, must-revalidate' for HTML files" \
            "https://web.dev/articles/http-cache"
        fi
        ;;
      vercel.json)
        # Check headers for HTML with long max-age
        if grep -B2 -A5 'text/html\|\.html' "$srvconf" 2>/dev/null | grep -qE 'max-age=[0-9]{5,}|immutable' 2>/dev/null; then
          findings_add "warning" "$REL_SRV" "cache-html-long" \
            "Long cache-control on HTML files in vercel.json — users won't see updates" \
            "Set 'Cache-Control: no-cache' for HTML responses" \
            "https://vercel.com/docs/edge-network/headers#cache-control"
        fi
        ;;
      _headers)
        # Netlify _headers: check if /*.html or / has long cache
        if grep -A3 -E '^\s*/($|\*\.html)' "$srvconf" 2>/dev/null | grep -qE 'max-age=[0-9]{5,}|immutable' 2>/dev/null; then
          findings_add "warning" "$REL_SRV" "cache-html-long" \
            "Long cache-control on HTML files — users won't see updates" \
            "Use 'Cache-Control: no-cache' for HTML, long cache only for hashed assets" \
            "https://web.dev/articles/http-cache"
        fi
        ;;
      .htaccess)
        # Apache: check for long ExpiresByType on text/html
        if grep -A2 'text/html' "$srvconf" 2>/dev/null | grep -qEi 'access plus [0-9]+ (month|year)|max-age=[0-9]{5,}' 2>/dev/null; then
          findings_add "warning" "$REL_SRV" "cache-html-long" \
            "Long cache-control on HTML in .htaccess — users won't see updates" \
            "Set short TTL for text/html, long TTL only for fingerprinted assets" \
            "https://web.dev/articles/http-cache"
        fi
        ;;
    esac
  done <<< "$SERVER_CONFIGS"
fi

# --- Rule 4: no-cdn-config — No CDN or edge deployment config ---
HAS_CDN=false
[ -f "$REPO/vercel.json" ] && HAS_CDN=true
[ -f "$REPO/netlify.toml" ] && HAS_CDN=true
[ -f "$REPO/wrangler.toml" ] && HAS_CDN=true
[ -f "$REPO/fly.toml" ] && HAS_CDN=true

# Check for CDN references in package.json or config
if [ "$HAS_CDN" = false ] && [ -f "$REPO/package.json" ]; then
  grep -qEi 'cloudfront|fastly|akamai|cloudflare|netlify|vercel' "$REPO/package.json" 2>/dev/null && HAS_CDN=true
fi

# Check for CDN in build config
if [ "$HAS_CDN" = false ] && [ -n "$BUILD_CONFIGS" ]; then
  echo "$BUILD_CONFIGS" | xargs grep -lEi 'publicPath.*cdn|CDN_URL|ASSET_PREFIX' 2>/dev/null | head -1 | grep -q . && HAS_CDN=true
fi

if [ "$HAS_CDN" = false ]; then
  findings_add "info" "$REPO" "no-cdn-config" \
    "No CDN or edge deployment config found — static assets served from origin" \
    "Deploy via Vercel, Netlify, Cloudflare Pages, or add a CDN (CloudFront, Fastly)" \
    "https://web.dev/articles/content-delivery-networks"
fi

# --- Rule 5: build-no-minify — Build config without minification ---
if [ -n "$BUILD_CONFIGS" ]; then
  HAS_MINIFY=false
  while IFS= read -r cfg; do
    [ -z "$cfg" ] && continue
    # Check for minify/minimize/terser/uglify/cssnano/esbuild minify
    if grep -qEi 'minimize\s*:\s*true|minify|TerserPlugin|UglifyJsPlugin|cssnano|OptimizeCssAssetsPlugin|CssMinimizerPlugin|esbuild.*minify' "$cfg" 2>/dev/null; then
      HAS_MINIFY=true
      break
    fi
    # Vite: build.minify defaults to esbuild (true unless explicitly false)
    if basename "$cfg" | grep -q "vite" 2>/dev/null; then
      if ! grep -qE 'minify\s*:\s*false|minify\s*:\s*.false.' "$cfg" 2>/dev/null; then
        HAS_MINIFY=true
        break
      fi
    fi
  done <<< "$BUILD_CONFIGS"

  # Frameworks with built-in minification (Next.js, Angular, CRA)
  if [ "$HAS_MINIFY" = false ]; then
    [ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && HAS_MINIFY=true
    [ -f "$REPO/angular.json" ] && HAS_MINIFY=true
  fi

  if [ "$HAS_MINIFY" = false ]; then
    FIRST_CFG=$(echo "$BUILD_CONFIGS" | head -1)
    REL_CFG="${FIRST_CFG#$REPO/}"
    findings_add "warning" "$REL_CFG" "build-no-minify" \
      "Build config without minification — shipping unminified JS/CSS increases load time" \
      "Enable minimize: true (webpack), or add terser/cssnano plugin" \
      "https://developer.chrome.com/docs/lighthouse/performance/unminified-javascript"
  fi
fi
