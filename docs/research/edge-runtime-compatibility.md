# Edge & Serverless Runtime Compatibility Guide

> ℹ️ **Note:** This research was conducted for Node.js ecosystem analysis, not for cpm internals.

Which APIs work where — and which packages you still need (or can drop) per runtime.

---

## 🏗️ Runtime Overview

| Runtime | Engine | Node.js compat | Max execution | Bundle limit |
|---|---|---|---|---|
| **Node.js 26** | V8 14.6 | Full | Unlimited | N/A |
| **Cloudflare Workers** | workerd (V8) | Most (with `nodejs_compat`) | 30s (paid) / 10ms (free) | 10MB |
| **Vercel Edge** | V8 (lightweight) | Minimal subset | 25s | 1-4MB |
| **Deno Deploy** | V8 + Rust | Good (node: imports) | 50s | 20MB |
| **Bun** | JavaScriptCore | Near-full | Unlimited | N/A |
| **AWS Lambda@Edge** | V8 (Node.js) | Full (Node 20) | 30s | 50MB |
| **Netlify Edge** | Deno (V8) | Partial (node: imports) | 50s | 20MB |

---

## 📋 Node.js Module Support by Runtime

| Module | Node 26 | Cloudflare Workers | Vercel Edge | Deno Deploy | Bun |
|---|---|---|---|---|---|
| `node:fs` | ✅ | ✅ (virtual) | ❌ | ✅ | ✅ |
| `node:path` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:crypto` | ✅ | ✅ | ❌ (use Web Crypto) | ✅ | ✅ |
| `node:buffer` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `node:stream` | ✅ | ✅ | ❌ (use Web Streams) | ✅ | ✅ |
| `node:http` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:net` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:dns` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:child_process` | ✅ | ❌ (stub) | ❌ | ❌ | ✅ |
| `node:cluster` | ✅ | ❌ (stub) | ❌ | ❌ | ❌ |
| `node:os` | ✅ | 🟡 partial | ❌ | ✅ | ✅ |
| `node:zlib` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:url` | ✅ | ✅ | ✅ (URL API) | ✅ | ✅ |
| `node:util` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:assert` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:events` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `node:timers` | ✅ | ✅ | ✅ (limited) | ✅ | ✅ |
| `node:tls` | ✅ | 🟡 partial | ❌ | ✅ | ✅ |
| `node:test` | ✅ | ❌ | ❌ | ✅ | ✅ |
| `node:sqlite` | ✅ | ❌ (use D1) | ❌ | ❌ | ✅ |

---

## 🌐 Web API Support by Runtime

| API | Node 26 | Cloudflare Workers | Vercel Edge | Deno Deploy | Bun |
|---|---|---|---|---|---|
| `fetch()` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `Request` / `Response` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `URL` / `URLSearchParams` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `AbortController` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `FormData` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `Blob` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `crypto.randomUUID()` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `crypto.subtle` (Web Crypto) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `structuredClone()` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `TextEncoder` / `TextDecoder` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `ReadableStream` / `WritableStream` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `WebSocket` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `setTimeout` / `setInterval` | ✅ | ✅ (limited) | ✅ (limited) | ✅ | ✅ |
| `Intl.*` (DateTimeFormat, etc.) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `Temporal.*` | ✅ (Node 26) | ❌ | ❌ | ❌ | ❌ |
| `navigator` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `performance.now()` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `queueMicrotask()` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `EventSource` | ✅ | ✅ | ❌ | ✅ | ✅ |

---

## 🚫 What's blocked per edge runtime

### Cloudflare Workers

| Blocked | Reason | Alternative |
|---|---|---|
| `eval()` | Security | Pre-compile logic |
| `new Function()` | Security | Pre-compile logic |
| `__dirname` / `__filename` | No filesystem concept | Use `import.meta.url` |
| `require()` | CJS not supported | Use ESM `import` |
| `process.exit()` | No process lifecycle | Return from handler |
| `node:child_process` | No subprocess spawning | Use Workers for Platforms |
| `node:sqlite` | No local DB | Use D1 binding |
| Dynamic `import()` with variables | Security | Static imports only |

### Vercel Edge

| Blocked | Reason | Alternative |
|---|---|---|
| `node:fs` | No filesystem | Use Vercel Blob / KV |
| `node:crypto` (full) | Too heavy | Use `crypto.subtle` (Web Crypto) |
| `node:net` / `node:dns` | No raw sockets | Use `fetch()` |
| `node:child_process` | No subprocesses | Use serverless functions |
| `eval()` / `new Function()` | Security | Pre-compile |
| `__dirname` / `__filename` | ESM only | Use `import.meta.url` |
| `require()` | ESM only | Use `import` |
| `process.env` (full) | Limited | Use `process.env` (read-only subset) |
| Packages > 1-4MB | Bundle limit | Tree-shake or use Node.js runtime |

### Deno Deploy

| Blocked | Reason | Alternative |
|---|---|---|
| `node:child_process` | Security sandbox | Use Deno.Command (limited) |
| `node:cluster` | Single-process model | Use isolates |
| Dynamic `require()` | ESM only | Use `import` |
| Native addons (.node) | No native compilation | Use WASM |

---

## 📦 Package compatibility matrix

Which packages work on which runtime **without polyfills**:

| Package | Node 26 | CF Workers | Vercel Edge | Deno | Bun |
|---|---|---|---|---|---|
| `express` | ✅ | ✅ (with compat) | ❌ | ✅ | ✅ |
| `hono` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `drizzle-orm` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `prisma` | ✅ | ✅ (edge adapter) | ✅ (edge) | ❌ | ✅ |
| `pg` (node-postgres) | ✅ | ✅ (with compat) | ❌ | ✅ | ✅ |
| `ioredis` | ✅ | ❌ | ❌ | ✅ | ✅ |
| `@upstash/redis` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `jose` (JWT) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `zod` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `lodash` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `sharp` (images) | ✅ | ❌ (native) | ❌ | ❌ | ✅ |
| `bcrypt` | ✅ | ❌ (native) | ❌ | ❌ | ✅ |
| `puppeteer` | ✅ | ✅ (Browser Run) | ❌ | ❌ | ❌ |
| `next` (App Router) | ✅ | ✅ (OpenNext) | ✅ | ❌ | ❌ |
| `ws` (WebSocket) | ✅ | ❌ (use native) | ❌ (use native) | ❌ | ✅ |

---

## ⚡ Performance recommendations per runtime

### Cloudflare Workers

| Instead of | Use | Why |
|---|---|---|
| `axios` / `got` | `fetch()` | Native, connection pooling via Undici |
| `uuid` | `crypto.randomUUID()` | Native Web Crypto |
| `jsonwebtoken` | `jose` | Web Crypto compatible |
| `bcrypt` | `@noble/hashes` | Pure JS, no native deps |
| `express` | `hono` | 10x smaller, edge-native |
| `ioredis` | `@upstash/redis` | HTTP-based, edge-compatible |
| `pg` | Hyperdrive + `pg` | Connection pooling at edge |
| `sharp` | Cloudflare Images | No binary deps |
| `ws` | Native WebSocket API | Built into runtime |
| `node-fetch` | `fetch()` | Already native |

### Vercel Edge

| Instead of | Use | Why |
|---|---|---|
| `node:crypto` | `crypto.subtle` | Web Crypto only |
| `node:fs` | Vercel Blob / KV | No filesystem |
| `axios` | `fetch()` | Native |
| `express` | Next.js middleware | Edge-native routing |
| `ioredis` | `@vercel/kv` | Edge-compatible |
| `pg` | `@vercel/postgres` | Edge adapter |
| Heavy packages (>1MB) | Switch to Node.js runtime | Bundle limit |

### Deno Deploy

| Instead of | Use | Why |
|---|---|---|
| `node-fetch` | `fetch()` | Native |
| `express` | `hono` or `oak` | Deno-native |
| `dotenv` | `Deno.env.get()` | Built-in |
| `uuid` | `crypto.randomUUID()` | Native |
| `chalk` | Deno built-in colors | `%c` in console.log |

---

## 🔄 Universal packages (work everywhere)

These packages are safe to use across all runtimes:

| Package | Why it works everywhere |
|---|---|
| `hono` | Web Standards only (Request/Response) |
| `zod` | Pure JS validation |
| `jose` | Web Crypto API |
| `drizzle-orm` | Adapter pattern per runtime |
| `@upstash/redis` | HTTP-based (fetch) |
| `@upstash/ratelimit` | HTTP-based |
| `nanoid` (with Web Crypto) | Uses `crypto.getRandomValues()` |
| `superjson` | Pure JS serialization |
| `date-fns` (pure functions) | No runtime deps |
| `valibot` | Pure JS validation (smaller than zod) |

---

*Last updated: 2026-05-25 — based on Cloudflare Workers (nodejs_compat v2), Vercel Edge Runtime, Deno Deploy, Bun 1.x, Node.js 26*
