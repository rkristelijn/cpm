---
title: Missing framework/tech rules — 29 popular frameworks without checks
type: feat
created: 2026-08-30T11:15:00+02:00
labels: [feat, rules, frameworks]
priority: high
---

## What

cpm has framework-specific rules for Django, Flask, Express, Next.js, Spring Boot, Laravel, Rails, Mongoose, and Nginx. But 29 popular frameworks have zero rules. These are real gaps — projects using these frameworks get no framework-specific security or quality feedback.

## Gap analysis

### Priority 1 — High popularity + security-critical (should have rules)

| Framework | Lang | Stars | Why it matters | Suggested rules |
|-----------|------|-------|----------------|-----------------|
| **FastAPI** | Python | 80K+ | #1 modern Python API framework. CORS misconfiguration, missing rate limiting, debug mode, unvalidated Pydantic models, no HTTPS redirect | 8-10 rules |
| **Gin** | Go | 80K+ | #1 Go web framework. Missing middleware (CORS, recovery), trusted proxies, debug mode, no rate limiting | 6-8 rules |
| **Hono** | TS | 20K+ | Fastest growing TS framework (Cloudflare/Bun/Deno). Missing middleware, CORS, env secrets in code | 5-6 rules |
| **Actix-web** | Rust | 22K+ | #1 Rust web framework. Unsafe blocks in handlers, missing extractors validation, no rate limiting | 5-6 rules |
| **Axum** | Rust | 19K+ | #2 Rust web (Tokio). Missing middleware layers, no tower rate limiting, unvalidated extractors | 5-6 rules |
| **htmx** | HTML/JS | 40K+ | Growing server-side rendering. XSS via hx-vals, unescaped content in hx-swap, CSP issues | 4-5 rules |
| **tRPC** | TS | 35K+ | Type-safe APIs but server-side validation still needed. Missing input validation, no rate limiting | 4-5 rules |
| **Drizzle** | TS | 25K+ | Growing ORM. Raw SQL via sql\`\`, missing prepared statements, no query timeout | 4-5 rules |

### Priority 2 — Popular frameworks, moderate security surface

| Framework | Lang | Why | Suggested rules |
|-----------|------|-----|-----------------|
| **Ktor** | Kotlin | JVM alternative to Spring. Missing content negotiation, no CORS config, exposed routes | 4-5 rules |
| **Micronaut** | Java | Cloud-native JVM. Missing security annotations, exposed endpoints, debug config | 4-5 rules |
| **Quarkus** | Java | Red Hat cloud-native. Dev mode in prod, missing security extensions, exposed health | 4-5 rules |
| **Fiber** | Go | Express-inspired Go. Same patterns as Express — missing helmet equiv, CORS, rate limit | 4-5 rules |
| **Rocket** | Rust | Rust web framework. Missing fairings (middleware), debug mode, no CSRF | 3-4 rules |
| **SvelteKit** | TS | Full-stack Svelte. Form actions without CSRF, load functions with secrets, env leaks | 4-5 rules |
| **Remix** | TS | React full-stack. Loader/action without auth check, exposed env in loader, no CSRF | 4-5 rules |
| **SolidJS/Start** | TS | React alternative. Server function secrets, missing CSP, createEffect cleanup | 3-4 rules |
| **Elysia** | TS | Bun-native. Similar to Hono — missing middleware, CORS, validation | 3-4 rules |

### Priority 3 — Niche or lower security surface

| Framework | Lang | Why | Suggested rules |
|-----------|------|-----|-----------------|
| **Starlette** | Python | FastAPI's foundation — rules would be inherited | covered by FastAPI |
| **Uvicorn** | Python | ASGI server. Workers config, SSL, proxy headers | 2-3 rules |
| **Qwik** | TS | Resumable framework. Server$ functions, env leaks | 2-3 rules |
| **Gatsby** | TS | Static site. Exposed env vars at build time, dangerouslySetInnerHTML | 2-3 rules |
| **Hugo** | Go | Static site generator. Template injection, unsafe shortcodes | 2-3 rules |
| **Strapi** | TS | Headless CMS. Default admin credentials, exposed API, permissions | 4-5 rules |
| **Directus** | TS | Headless CMS. Public permissions, exposed REST/GraphQL | 3-4 rules |
| **Payload** | TS | Headless CMS. Access control config, exposed admin | 3-4 rules |
| **Celery** | Python | Task queue. Pickle serialization (RCE), no result backend auth | 3-4 rules |
| **WebSocket** | Multi | Missing auth on ws://, no origin check, no rate limiting | 3-4 rules |

## Implementation plan

### Phase 1: Top 3 frameworks (highest ROI)

1. **FastAPI** — `rules/fastapi/` (8-10 rules)
   - CORS misconfiguration (allow_origins=["*"] with credentials)
   - Debug mode / reload in production
   - Missing rate limiting middleware
   - Unvalidated request body (no Pydantic model)
   - SQL injection via f-string in raw queries
   - Missing HTTPS redirect middleware
   - Exposed /docs and /redoc in production
   - Missing authentication dependency

2. **Gin** — `rules/gin/` (6-8 rules)
   - Debug mode (gin.SetMode not set or "debug")
   - Missing Recovery() middleware
   - Trusted proxies not configured
   - CORS wildcard with credentials
   - Missing rate limiting
   - Raw SQL in handlers

3. **Hono** — `rules/hono/` (5-6 rules)
   - Missing CORS middleware
   - Env secrets in code (not c.env)
   - No rate limiting
   - Missing CSP headers
   - Debug/dev routes in production

### Phase 2: Rust + htmx + tRPC + Drizzle
### Phase 3: JVM alternatives (Ktor, Micronaut, Quarkus)
### Phase 4: Meta-frameworks (SvelteKit, Remix, SolidStart)
### Phase 5: CMS + infrastructure (Strapi, Celery, WebSocket)

## Effort estimate

- Phase 1: ~3 hours (25 rules)
- Phase 2: ~3 hours (20 rules)
- Phase 3: ~2 hours (15 rules)
- Phase 4: ~2 hours (15 rules)
- Phase 5: ~2 hours (15 rules)
- Total: ~12 hours for ~90 new rules

All rules are declarative .rule files — no C++ changes needed.

## Definition of done

- [ ] Rules created and pass smoke test (regex compiles in RE2)
- [ ] At least 1 test fixture per framework in cpm-eval
- [ ] README updated with new framework count
- [ ] Benchmark re-run to verify no false positive explosion
