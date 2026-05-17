---
summary: Generate default projects for top frameworks, scan them, prove cpm value from day zero.
status: accepted
---

# ADR-023: Framework Demo Generation Strategy

## Context

cpm claims to work on any repo. We need to prove it by generating default projects from official framework CLIs, scanning them immediately, and showing what cpm finds and fixes — value from the first second.

This also drives feature development: whatever the generators produce that cpm can't check yet becomes a backlog item.

## Decision

Create a `cpm-demos` repo that:

1. Generates projects from official framework CLIs (default options, no customization)
2. Runs `cpm scan` on each
3. Runs `cpm check` where applicable
4. Documents findings per framework
5. Auto-fixes what it can

## Frameworks

| # | Framework | Generator command | Language | Category |
|---|-----------|------------------|----------|----------|
| 1 | React | `npx create-react-app demo-react --template typescript` | TypeScript | Frontend |
| 2 | Next.js | `npx create-next-app demo-nextjs --ts` | TypeScript | Fullstack |
| 3 | Angular | `npx @angular/cli new demo-angular` | TypeScript | Frontend |
| 4 | Vue | `npm create vue@latest demo-vue` | TypeScript | Frontend |
| 5 | Svelte | `npm create svelte@latest demo-svelte` | TypeScript | Frontend |
| 6 | Astro | `npm create astro@latest demo-astro` | TypeScript | Frontend |
| 7 | Nuxt | `npx nuxi init demo-nuxt` | TypeScript | Fullstack |
| 8 | Remix | `npx create-remix demo-remix` | TypeScript | Fullstack |
| 9 | NestJS | `npx @nestjs/cli new demo-nestjs` | TypeScript | Backend |
| 10 | Express | `npx express-generator demo-express` | JavaScript | Backend |
| 11 | Fastify | `npx fastify-cli generate demo-fastify` | TypeScript | Backend |
| 12 | Hono | `npm create hono@latest demo-hono` | TypeScript | Backend |
| 13 | Spring Boot | `spring init --dependencies=web demo-spring` | Java | Backend |
| 14 | Quarkus | `quarkus create app demo-quarkus` | Java | Backend |
| 15 | Django | `django-admin startproject demo_django` | Python | Backend |
| 16 | FastAPI | manual (uvicorn + fastapi) | Python | Backend |
| 17 | Flask | manual (minimal app.py) | Python | Backend |
| 18 | Laravel | `composer create-project laravel/laravel demo-laravel` | PHP | Backend |
| 19 | Symfony | `composer create-project symfony/skeleton demo-symfony` | PHP | Backend |
| 20 | Go (stdlib) | `go mod init demo-go` | Go | Backend |
| 21 | Gin | `go mod init demo-gin` + gin dep | Go | Backend |
| 22 | Rust (Actix) | `cargo new demo-rust` + actix dep | Rust | Backend |
| 23 | C++ (cpm) | `cpm new demo-cpp` | C++ | Systems |
| 24 | Terraform | `terraform init` | HCL | IaC |
| 25 | Pulumi | `pulumi new typescript` | TypeScript | IaC |
| 26 | WordPress | `wp core download` | PHP | CMS |
| 27 | Strapi | `npx create-strapi-app demo-strapi` | TypeScript | CMS |
| 28 | Electron | `npx create-electron-app demo-electron` | TypeScript | Desktop |
| 29 | React Native | `npx react-native init demo-rn` | TypeScript | Mobile |
| 30 | Tauri | `npm create tauri-app demo-tauri` | TypeScript/Rust | Desktop |

## What we expect to find

| Finding type | Likely frameworks | cpm check | New feature? |
|-------------|-------------------|-----------|--------------|
| Unpinned deps (^ ~) | All JS/TS | ✅ scan | — |
| No lockfile | Express, manual setups | ✅ scan | — |
| No test script | Express, Flask | ✅ scan | — |
| Missing description | Most generators | ✅ scan | — |
| No LICENSE | All | ✅ scan | — |
| No CONTRIBUTING | All | ✅ scan | — |
| No CI pipeline | All | ✅ scan | — |
| TypeScript EOL | Older generators | ✅ scan | — |
| Framework misuse | None (fresh) | — | — |
| Bundle size issues | React (lodash etc) | ✅ check | — |
| Accessibility gaps | React, Angular, Vue | ✅ check | — |
| Missing meta/SEO | Next.js, Astro, Nuxt | ✅ check | — |
| No .env.example | NestJS, Laravel, Django | ❌ | Add check |
| No Dockerfile | All backend | ❌ | Add check |
| No health endpoint | Express, NestJS, Spring | ❌ | Add check |
| No rate limiting | Express, Fastify, Hono | ❌ | Add check |
| No CORS config | Express, NestJS | ❌ | Add check |
| No input validation | Express, Flask | ❌ | Add check |
| Default secret keys | Django, Laravel, Spring | ❌ | Add check |
| Debug mode enabled | Django, Laravel | ❌ | Add check |
| No helmet/security headers | Express, Fastify | ❌ | Add check |
| Inconsistent error handling | All | ❌ | Add check |
| No graceful shutdown | All backend | ❌ | Add check |
| No request logging | Express, Go, Rust | ❌ | Add check |
| Hardcoded ports | All backend | ❌ | Add check |
| No .gitignore patterns | Some generators | ✅ scan | — |
| Outdated base images | Docker-based | ❌ | Add check |
| No resource limits | Terraform, K8s | ❌ | Add check |

## What we can auto-fix

| Fix | Command | Frameworks |
|-----|---------|-----------|
| Pin dependencies | `cpm fix deps` (future) | All JS/TS |
| Add LICENSE | `cpm init --license MIT` | All |
| Add CI pipeline | `cpm eject --ci` (future) | All |
| Format code | `cpm format` | All |
| Add lockfile | `npm install` / `composer install` | JS, PHP |

## Repo structure

```text
~/git/hub/cpm-demos/
├── generate.sh          ← scaffolds all frameworks
├── scan-all.sh          ← runs cpm scan on all
├── results/             ← scan findings per framework (JSONL)
├── README.md            ← summary table with findings
└── frameworks/
    ├── demo-react/
    ├── demo-nextjs/
    ├── demo-angular/
    ├── demo-vue/
    ├── demo-nestjs/
    ├── demo-express/
    ├── demo-spring/
    ├── demo-django/
    ├── demo-laravel/
    ├── demo-cpp/
    └── ...
```

## Success criteria

- All high-priority frameworks generated and scanned
- Findings documented per framework
- At least 3 auto-fixable issues identified
- Results feed back into cpm feature backlog

## References

- @see docs/adrs/adr-018-language-framework-scoring.md
- @see docs/adrs/adr-020-product-vision.md
