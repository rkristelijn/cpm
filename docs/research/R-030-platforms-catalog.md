# R-030: Platforms & Frameworks Catalogus (Tussenresultaat)

**Date:** 2026-08-30
**Status:** Tussenresultaat (Fase 2/5)

## Samenvatting

**130 platforms** gecatalogiseerd in **12 categorieën**.

Deze catalogus dient als referentie voor het identificeren van platform-native features die traditionele design patterns vervangen. Het doel is om cpm-regels af te stemmen op wat elk platform al biedt, zodat findings relevant en niet-redundant zijn.

---

## Catalogus

### 1. Programmeertalen (22 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 1 | TypeScript | Taal | Multi-paradigm | Generics (vervangt veel factory patterns), decorators (vervangt handmatige metadata/AOP), mapped types & conditional types (vervangt runtime type-transformatie), utility types (`Partial`, `Pick`, `Omit` — vervangt builder-achtige constructies), union types & discriminated unions (vervangt visitor/state pattern), template literal types |
| 2 | JavaScript | Taal | Multi-paradigm | Prototypal inheritance (vervangt klassieke OOP-overerving), Proxy/Reflect (vervangt decorator/interceptor pattern), closures (vervangt command pattern), Promises/async-await (vervangt callback/observer chains), iterators/generators (vervangt custom iterator pattern), modules (vervangt namespace pattern), destructuring & spread (vervangt sommige builder patterns) |
| 3 | Python | Taal | Multi-paradigm | Decorators (vervangt AOP/wrapper pattern), descriptors & properties (vervangt getter/setter boilerplate), metaclasses (vervangt abstract factory voor class-creatie), context managers (`with` — vervangt RAII/dispose pattern), dataclasses (vervangt builder pattern), dunder methods (vervangt operator overloading patterns), generators (vervangt iterator pattern), type hints + Protocol (vervangt interface pattern), match statement (vervangt visitor pattern) |
| 4 | C++ | Taal | Multi-paradigm | Templates & SFINAE/concepts (vervangt runtime polymorfisme), RAII (vervangt dispose/cleanup pattern), smart pointers (vervangt handmatig memory management), operator overloading (vervangt wrapper patterns), constexpr (vervangt runtime computation patterns), move semantics (vervangt defensive copying), ranges (vervangt iterator boilerplate), modules (C++20, vervangt header-gebaseerde inclusie) |
| 5 | C# | Taal | Multi-paradigm | Properties (vervangt getter/setter pattern), delegates & events (vervangt observer pattern), LINQ (vervangt iterator/filter chains), async/await (vervangt callback pattern), extension methods (vervangt decorator/utility pattern), pattern matching (vervangt visitor pattern), records (vervangt immutable DTO pattern), nullable reference types (vervangt null object pattern), source generators (vervangt runtime reflection/codegen) |
| 6 | Java | Taal | OOP | Annotations (vervangt handmatige metadata), generics (vervangt type-unsafe containers), streams API (vervangt iterator/filter pattern), lambdas & functional interfaces (vervangt single-method interface pattern), records (vervangt DTO/value object boilerplate), sealed classes (vervangt open-hierarchy problemen), pattern matching (vervangt instanceof chains), modules (JPMS — vervangt classpath chaos), virtual threads (Project Loom — vervangt thread pool patterns) |
| 7 | Go | Taal | Multi-paradigm | Interfaces (impliciet — vervangt expliciete interface-implementatie), goroutines & channels (vervangt thread/actor pattern), defer (vervangt finally/cleanup pattern), embedding (vervangt inheritance), error-als-waarde (vervangt exception handling pattern), context package (vervangt request-scoped data passing), generics (1.18+ — vervangt interface{} type assertions) |
| 8 | Rust | Taal | Multi-paradigm | Ownership & borrowing (vervangt GC en memory management patterns), traits (vervangt interfaces + mixins), enums + pattern matching (vervangt visitor/state pattern), Result/Option types (vervangt null/exception patterns), lifetimes (vervangt dangling pointer bugs), macros (vervangt codegen/metaprogramming), async/await (vervangt callback chains), derive macros (vervangt boilerplate code), trait objects (vervangt runtime polymorfisme) |
| 9 | Ruby | Taal | Multi-paradigm | Mixins/modules (vervangt multiple inheritance), blocks & procs (vervangt strategy/command pattern), open classes (vervangt decorator pattern), method_missing (vervangt proxy pattern), DSL-ondersteuning (vervangt configuratie-boilerplate), symbols (vervangt string-based enums), eigenclass (vervangt metaclass patterns) |
| 10 | PHP | Taal | Multi-paradigm | Traits (vervangt multiple inheritance), attributes (PHP 8 — vervangt annotation/docblock metadata), named arguments (vervangt builder pattern), enums (PHP 8.1 — vervangt constant-klassen), fibers (vervangt async callback patterns), match expression (vervangt switch/strategy pattern), union/intersection types (vervangt interface-combos) |
| 11 | Swift | Taal | Multi-paradigm | Protocols + extensions (vervangt interface + mixin pattern), optionals (vervangt null object pattern), enums met associated values (vervangt visitor/union pattern), property wrappers (vervangt decorator pattern), actors (vervangt lock-based concurrency), structured concurrency (vervangt callback hell), result builders (vervangt builder pattern), value types (vervangt defensive copying) |
| 12 | Kotlin | Taal | Multi-paradigm | Data classes (vervangt DTO/value object boilerplate), sealed classes (vervangt restricted hierarchies), extension functions (vervangt utility/decorator pattern), coroutines (vervangt callback/thread patterns), null safety (vervangt null checks), delegation (`by` — vervangt decorator/proxy pattern), DSL builders (vervangt builder pattern), inline functions (vervangt wrapper overhead) |
| 13 | Dart | Taal | OOP | Mixins (vervangt multiple inheritance), factory constructors (vervangt factory pattern), extension methods (vervangt utility pattern), null safety (vervangt null checks), isolates (vervangt thread-based concurrency), named constructors (vervangt telescoping constructor), async/await + streams (vervangt observer pattern), records & patterns (Dart 3 — vervangt DTO boilerplate) |
| 14 | Scala | Taal | Multi-paradigm | Case classes (vervangt DTO/value object pattern), traits (vervangt interface + mixin), pattern matching (vervangt visitor pattern), implicits/givens (vervangt dependency injection), higher-kinded types (vervangt sommige abstract factory patterns), for-comprehensions (vervangt monad chaining), companion objects (vervangt static factory), type classes (vervangt adapter pattern), macros (vervangt codegen) |
| 15 | Elixir | Taal | Functioneel | Processes & OTP (vervangt actor/thread patterns), pattern matching (vervangt conditional chains), protocols (vervangt interface/adapter pattern), behaviours (vervangt abstract class/template method), macros (vervangt metaprogramming), pipe operator (vervangt method chaining), supervisors (vervangt error recovery patterns), GenServer (vervangt stateful service pattern) |
| 16 | Haskell | Taal | Functioneel | Type classes (vervangt interface/strategy pattern), monads (vervangt callback/chaining patterns), algebraic data types (vervangt visitor/union pattern), pattern matching (vervangt conditional dispatch), higher-order functions (vervangt strategy/command pattern), lazy evaluation (vervangt iterator/generator pattern), do-notation (vervangt imperative sequencing), GADTs (vervangt type-safe builder) |
| 17 | Clojure | Taal | Functioneel | Persistent data structures (vervangt defensive copying), protocols (vervangt interface pattern), multimethods (vervangt visitor/double dispatch), macros (vervangt codegen/DSL pattern), atoms/refs/agents (vervangt lock-based concurrency), destructuring (vervangt accessor boilerplate), transducers (vervangt composable pipeline pattern), spec (vervangt validation/schema pattern) |
| 18 | Lua | Taal | Multi-paradigm | Metatables (vervangt OOP inheritance), coroutines (vervangt async/state machine pattern), first-class functions (vervangt strategy/command pattern), tables-als-alles (vervangt separate struct/map/array types), weak tables (vervangt cache/observer cleanup), metamethods (vervangt operator overloading patterns) |
| 19 | R | Taal | Multi-paradigm | Vectorized operations (vervangt loop patterns), S3/S4/R5 dispatch (vervangt strategy pattern), formulas (vervangt expression tree pattern), environments (vervangt scope/namespace pattern), tidyverse pipes (vervangt method chaining), non-standard evaluation (vervangt query builder pattern) |
| 20 | Zig | Taal | Procedureel | Comptime (vervangt runtime metaprogramming/generics), optionals (vervangt null pointer patterns), error unions (vervangt exception pattern), allocator-passing (vervangt global allocator pattern), inline assembly (vervangt FFI voor low-level), packed structs (vervangt bitfield patterns), sentinel-terminated types (vervangt C-string patterns) |
| 21 | OCaml | Taal | Multi-paradigm | Algebraic data types (vervangt union/visitor pattern), pattern matching (vervangt conditional dispatch), modules & functors (vervangt dependency injection + generics), option type (vervangt null pattern), first-class modules (vervangt plugin pattern), GADTs (vervangt type-safe builder), polymorphic variants (vervangt extensible enums) |
| 22 | V | Taal | Multi-paradigm | Compile-time code generation (vervangt macros/templates), autofree (vervangt GC/manual memory), built-in testing (vervangt test framework setup), built-in JSON (vervangt serialization libraries), optionals (vervangt null pattern), sum types (vervangt visitor pattern), comptime (vervangt runtime reflection) |

---

### 2. Frontend Frameworks (12 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 23 | Angular | Framework | OOP/Multi | Built-in DI (vervangt service locator), RxJS integration (vervangt observer/pub-sub), signals (vervangt manuele change detection), two-way binding (vervangt mediator pattern), pipes (vervangt formatter/transformer pattern), guards/interceptors (vervangt middleware/chain of responsibility), modules/standalone (vervangt namespace pattern), template-driven & reactive forms (vervangt form state management), control flow (@if/@for — vervangt structural directives) |
| 24 | React | Library | Functioneel/Declaratief | Hooks (vervangt HOC/render props/lifecycle patterns), Context API (vervangt prop drilling/basic DI), JSX (vervangt template engine pattern), Suspense (vervangt loading state pattern), React.memo/useMemo/useCallback (vervangt caching pattern), useReducer (vervangt state machine pattern), ref forwarding (vervangt imperative handle pattern), server components (vervangt data-fetching patterns), concurrent features (vervangt debounce/scheduling patterns) |
| 25 | Vue | Framework | Multi-paradigm | Composition API (vervangt mixin pattern), reactivity system (vervangt observer pattern), provide/inject (vervangt DI/prop drilling), computed properties (vervangt memoization pattern), watchers (vervangt observer pattern), v-model (vervangt two-way binding boilerplate), Teleport (vervangt portal pattern), Suspense (vervangt async loading pattern), auto-imports (vervangt import boilerplate) |
| 26 | Svelte | Compiler/Framework | Declaratief | Compile-time reactivity (vervangt runtime virtual DOM), runes ($state/$derived — vervangt store/signal patterns), built-in transitions/animations (vervangt animation library), two-way binding (vervangt controlled input pattern), stores (vervangt state management library), scoped CSS (vervangt CSS-in-JS), slot/snippet (vervangt render props), $effect (vervangt useEffect/lifecycle) |
| 27 | Solid.js | Library | Functioneel/Reactief | Fine-grained reactivity (vervangt virtual DOM diffing), signals & effects (vervangt useState/useEffect), createResource (vervangt data fetching pattern), Suspense (vervangt loading pattern), stores (vervangt immutable state pattern), createMemo (vervangt computed/derived state), context (vervangt DI), JSX zonder re-renders (vervangt memoization patterns) |
| 28 | Qwik | Framework | Declaratief | Resumability (vervangt hydration pattern), lazy loading by default (vervangt code splitting strategy), $() serialization (vervangt manual lazy loading), useSignal/useStore (vervangt state management), useTask$/useVisibleTask$ (vervangt lifecycle/effect patterns), QwikCity (vervangt routing setup), progressive hydration (vervangt SSR hydration cost) |
| 29 | Lit | Library | OOP/Web Components | Web Components native (vervangt framework-specific components), reactive properties (vervangt observer pattern), html template tag (vervangt JSX/template engines), decorators (vervangt boilerplate), shadow DOM (vervangt CSS scoping), lifecycle callbacks (vervangt framework lifecycle), CSS custom properties (vervangt theming pattern) |
| 30 | Alpine.js | Library | Declaratief | Directive-based (vervangt jQuery-achtige DOM manipulation), x-data (vervangt component state setup), x-bind/x-on (vervangt event listener boilerplate), Alpine.store (vervangt global state pattern), x-effect (vervangt watcher pattern), teleport (vervangt portal pattern), $dispatch (vervangt custom event pattern) |
| 31 | Htmx | Library | Declaratief/Hypermedia | HTML-attributen (vervangt JavaScript fetch/XHR), hx-swap (vervangt DOM manipulation), hx-trigger (vervangt event listener setup), hx-target (vervangt response handling), server-driven UI (vervangt client-side state management), progressive enhancement (vervangt SPA-eerste aanpak), WebSocket & SSE attributen (vervangt realtime client code) |
| 32 | Ember | Framework | OOP | Convention over configuration (vervangt configuratie boilerplate), Ember Data (vervangt data layer setup), tracked properties (vervangt observer pattern), services (vervangt DI container), Glimmer components (vervangt class-based components), route model hooks (vervangt data fetching pattern), helpers (vervangt utility pattern) |
| 33 | Preact | Library | Functioneel | API-compatibel met React (vervangt React bij size-constraint), signals (vervangt hooks/state), hooks (vervangt class components), 3kB footprint (vervangt React bundle), preact/compat (vervangt migration tooling) |
| 34 | Stencil | Compiler/Framework | OOP/Web Components | Web Component compiler (vervangt handmatig WC schrijven), decorators (vervangt boilerplate), lazy loading (vervangt code splitting), JSX (vervangt template engines), virtual DOM (vervangt manual DOM updates), framework-agnostisch output (vervangt framework lock-in) |

---

### 3. Meta-Frameworks (8 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 35 | Next.js | Meta-framework | Multi | App Router/file-based routing (vervangt router config), Server Components (vervangt API-route + fetch pattern), server actions (vervangt API endpoints voor mutations), ISR/SSG/SSR (vervangt cache invalidation patterns), middleware (vervangt proxy/interceptor pattern), Image/Font/Script optimization (vervangt manuele optimalisatie), parallel & intercepting routes (vervangt complex routing patterns) |
| 36 | Nuxt | Meta-framework | Multi | Auto-imports (vervangt import boilerplate), file-based routing (vervangt router config), useFetch/useAsyncData (vervangt data fetching setup), server routes (vervangt separate API server), Nitro engine (vervangt server adapter pattern), modules ecosystem (vervangt plugin configuratie), useState (vervangt state management setup), middleware (vervangt route guard pattern) |
| 37 | SvelteKit | Meta-framework | Declaratief | File-based routing (vervangt router config), load functions (vervangt data fetching pattern), form actions (vervangt API endpoint + form handling), hooks (vervangt middleware pattern), adapters (vervangt deployment config), progressive enhancement (vervangt JavaScript-first pattern), +page/+layout/+server (vervangt routing conventions) |
| 38 | Remix | Meta-framework | Multi | Nested routing met loaders/actions (vervangt data fetching + mutation pattern), form-centric (vervangt SPA form handling), progressive enhancement (vervangt JS-dependent patterns), error boundaries per route (vervangt global error handling), HTTP caching (vervangt client-side caching), resource routes (vervangt API endpoints), defer/Await (vervangt streaming pattern) |
| 39 | Astro | Meta-framework | Multi | Islands architecture (vervangt full-page hydration), content collections (vervangt CMS integration pattern), zero JS by default (vervangt bundle optimization), framework-agnostisch (vervangt framework lock-in), file-based routing (vervangt router), MDX integration (vervangt content pipeline), view transitions (vervangt SPA navigation) |
| 40 | Analog | Meta-framework | Multi (Angular) | File-based routing voor Angular (vervangt RouterModule config), API routes (vervangt separate backend), Vite-powered (vervangt Angular CLI/Webpack), markdown content (vervangt CMS pattern), server-side data loading (vervangt resolver pattern) |
| 41 | Fresh | Meta-framework | Multi (Deno) | Islands architecture (vervangt full-page hydration), Deno-native (vervangt Node.js setup), Preact-based (vervangt React bundle size), no build step (vervangt build pipeline), file-based routing (vervangt router config) |
| 42 | Gatsby | Meta-framework | Multi (React) | GraphQL data layer (vervangt data fetching pattern), plugin ecosystem (vervangt custom integrations), static site generation (vervangt server rendering), image optimization (vervangt manual image pipeline), deferred static generation (vervangt build-time bottleneck) |

---

### 4. Backend Frameworks (17 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 43 | NestJS | Framework | OOP | Built-in DI (vervangt service locator), decorators (vervangt handmatige routing/metadata), modules (vervangt namespace/packaging pattern), guards/interceptors/pipes (vervangt middleware chain pattern), CQRS module (vervangt custom CQRS implementatie), microservices transport (vervangt message broker setup), OpenAPI/Swagger integratie (vervangt API doc generation) |
| 44 | FastAPI | Framework | Multi | Type hints als schema (vervangt request validation boilerplate), automatic OpenAPI docs (vervangt API doc tools), dependency injection systeem (vervangt DI container), async native (vervangt thread-based serving), Pydantic models (vervangt serialization/validation pattern), path operation decorators (vervangt route registration), background tasks (vervangt task queue voor simpele jobs) |
| 45 | Express | Framework | Multi | Middleware chain (vervangt interceptor/filter pattern), routing (vervangt URL dispatch), error handling middleware (vervangt try-catch boilerplate), mounting (vervangt sub-application pattern), template engine support (vervangt view rendering setup), static file serving (vervangt file server setup) |
| 46 | Django | Framework | OOP/MTV | ORM (vervangt SQL boilerplate), admin interface (vervangt CRUD admin tools), migrations (vervangt schema management), middleware (vervangt request/response interceptors), forms + model forms (vervangt input validation), template engine (vervangt view rendering), signals (vervangt observer pattern), class-based views (vervangt view boilerplate), auth system (vervangt auth implementation) |
| 47 | Flask | Framework | Multi | Decorators voor routing (vervangt route config), blueprints (vervangt module pattern), Jinja2 templating (vervangt view rendering), context locals (vervangt request-scoped data passing), extensions ecosystem (vervangt DIY middleware), werkzeug utilities (vervangt HTTP utilities) |
| 48 | Spring Boot | Framework | OOP | Annotation-based DI (vervangt XML config/factory pattern), auto-configuration (vervangt boilerplate setup), Spring Data (vervangt DAO pattern), Spring Security (vervangt auth implementation), AOP (vervangt cross-cutting concern patterns), actuator (vervangt health check implementation), profiles (vervangt environment-based config), Spring Cloud (vervangt microservices infrastructure) |
| 49 | ASP.NET Core | Framework | OOP | Built-in DI container (vervangt third-party DI), middleware pipeline (vervangt interceptor pattern), model binding/validation (vervangt request parsing), Razor Pages/MVC (vervangt view rendering), Entity Framework integration (vervangt ORM setup), Identity (vervangt auth implementation), minimal APIs (vervangt controller boilerplate), gRPC support (vervangt RPC setup) |
| 50 | Rails | Framework | OOP/CoC | Convention over Configuration (vervangt configuratie boilerplate), ActiveRecord (vervangt DAO/repository pattern), migrations (vervangt schema management), Action Cable (vervangt WebSocket setup), Active Job (vervangt background job pattern), Action Mailer (vervangt email setup), scaffolding (vervangt CRUD boilerplate), concerns (vervangt mixin/decorator pattern), Turbo/Hotwire (vervangt SPA patterns) |
| 51 | Laravel | Framework | OOP | Eloquent ORM (vervangt DAO/repository pattern), Blade templating (vervangt view rendering), Artisan CLI (vervangt command-line tool setup), queues (vervangt async job pattern), events/listeners (vervangt observer pattern), middleware (vervangt interceptor pattern), service container (vervangt DI), facades (vervangt service locator), policies/gates (vervangt authorization pattern), Livewire (vervangt SPA voor interactie) |
| 52 | Phoenix | Framework | Functioneel | LiveView (vervangt SPA + WebSocket pattern), channels (vervangt real-time communication setup), Ecto (vervangt ORM/query builder), plugs (vervangt middleware pattern), contexts (vervangt service layer pattern), PubSub (vervangt message broker voor intra-app), presence (vervangt online user tracking), telemetry (vervangt metrics setup) |
| 53 | Gin | Framework | Multi | High-performance router (vervangt http.ServeMux), middleware chaining (vervangt interceptor pattern), JSON binding/validation (vervangt request parsing), grouped routes (vervangt route organization), recovery middleware (vervangt panic handling), rendering (vervangt template setup) |
| 54 | Actix Web | Framework | Multi | Actor model (vervangt thread-based concurrency), extractors (vervangt request parsing pattern), middleware (vervangt interceptor pattern), guards (vervangt route matching pattern), WebSocket support (vervangt real-time setup), type-safe routing (vervangt string-based routes) |
| 55 | Fastify | Framework | Multi | Schema-based validation (vervangt validation middleware), plugin system (vervangt module pattern), hooks lifecycle (vervangt middleware ordering), decorators (vervangt service extension pattern), serialization (vervangt JSON.stringify overhead), TypeScript-first (vervangt type bolting), encapsulation (vervangt DI scoping) |
| 56 | Hono | Framework | Multi | Multi-runtime (vervangt platform-specifieke code), middleware (vervangt interceptor pattern), validators (vervangt input validation), RPC mode (vervangt API client generation), JSX support (vervangt template engine), adapters (vervangt deployment-specifieke code), tiny bundle (vervangt framework overhead) |
| 57 | Fiber | Framework | Multi | Express-compatible API (vervangt Express op Go), built-in middleware (vervangt third-party middleware), zero-allocation routing (vervangt overhead van standaard routers), template engines (vervangt view rendering), rate limiter/CORS/helmet (vervangt security middleware setup), WebSocket/SSE (vervangt real-time setup) |
| 58 | Koa | Framework | Multi | Async middleware (vervangt callback-based middleware), context object (vervangt req/res manipulation), cascading middleware (vervangt onion model setup), minimalistisch (vervangt opinionated frameworks), generators support (vervangt complex async flows) |
| 59 | Chi | Framework | Multi | stdlib-compatible (vervangt custom router), middleware stack (vervangt interceptor pattern), URL parameters (vervangt manual parsing), composable routing (vervangt monolithic router), context-based (vervangt request-scoped data) |

---

### 5. State Management (11 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 60 | NgRx | Library | Functioneel/Reactief | Redux voor Angular (vervangt custom state services), Effects (vervangt side-effect management), Selectors (vervangt memoized computed state), Entity adapter (vervangt CRUD state boilerplate), Component Store (vervangt lightweight state pattern), SignalStore (vervangt RxJS-heavy state) |
| 61 | Redux/RTK | Library | Functioneel | createSlice (vervangt action/reducer boilerplate), RTK Query (vervangt data fetching + caching), createAsyncThunk (vervangt async action pattern), Immer integration (vervangt immutable update patterns), createEntityAdapter (vervangt normalized state), configureStore (vervangt store setup boilerplate), createSelector (vervangt reselect setup) |
| 62 | Zustand | Library | Functioneel | Simpele store API (vervangt Redux boilerplate), geen provider nodig (vervangt context wrapper pattern), middleware (vervangt store enhancers), persist middleware (vervangt local storage sync), devtools (vervangt debug setup), slices pattern (vervangt module federation) |
| 63 | Pinia | Library | Multi | Vue 3 officieel (vervangt Vuex), composition API support (vervangt options API stores), TypeScript-first (vervangt type bolting), devtools (vervangt debug setup), plugins (vervangt store middleware), HMR support (vervangt development workflow), geen mutations nodig (vervangt mutation boilerplate) |
| 64 | MobX | Library | Reactief/OOP | Observable state (vervangt manual subscription pattern), computed values (vervangt memoization), reactions (vervangt watcher pattern), actions (vervangt state mutation tracking), makeAutoObservable (vervangt decorator boilerplate), flow (vervangt async action pattern) |
| 65 | Recoil | Library | Functioneel/Reactief | Atoms (vervangt global state slices), selectors (vervangt derived/computed state), async selectors (vervangt data fetching in state), atom families (vervangt parameterized state), snapshot (vervangt state serialization), concurrent mode compatible (vervangt scheduling workarounds) |
| 66 | Jotai | Library | Functioneel/Atomair | Atomic state model (vervangt centralized store), derived atoms (vervangt computed state), async atoms (vervangt data fetching), geen provider vereist (vervangt context wrapper), utils (vervangt common state patterns), integrations (vervangt glue code voor libraries) |
| 67 | XState | Library | State Machines | Finite state machines (vervangt boolean flag patterns), statecharts (vervangt complex conditional logic), actors (vervangt concurrent state management), guards (vervangt conditional transitions), services (vervangt side-effect management), typegen (vervangt type-unsafe state), inspector (vervangt state debugging) |
| 68 | Signals (TC39/framework) | Pattern/Library | Reactief | Fine-grained reactivity (vervangt dirty checking), auto-tracking (vervangt manual subscriptions), computed signals (vervangt memoization), effect scheduling (vervangt manual update batching), framework-agnostisch (vervangt framework-specifieke reactivity) |
| 69 | Akita | Library | OOP/Reactief | Entity stores (vervangt CRUD state management), queries (vervangt selector pattern), Angular-geoptimaliseerd (vervangt generic state libs), plugins (vervangt devtools setup), persistState (vervangt storage sync), arrayAdd/Remove/Update (vervangt immutable update helpers) |
| 70 | Effector | Library | Functioneel/Reactief | Stores/events/effects (vervangt Redux action/reducer/thunk), combine (vervangt selector pattern), domain (vervangt store scoping), fork (vervangt SSR state isolation), attach (vervangt effect composition) |

---

### 6. Data/Query Libraries (10 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 71 | TanStack Query | Library | Declaratief | Auto caching/refetching (vervangt manuele cache invalidation), stale-while-revalidate (vervangt loading state pattern), query keys (vervangt cache key management), mutations (vervangt optimistic update boilerplate), infinite queries (vervangt pagination state), prefetching (vervangt preload pattern), devtools (vervangt cache debugging) |
| 72 | TanStack Table | Library | Declaratief | Headless table (vervangt UI-gekoppelde table components), column definitions (vervangt table rendering logic), sorting/filtering/pagination (vervangt custom table state), virtualization (vervangt render optimization), framework-agnostisch (vervangt framework-specifieke tables) |
| 73 | SWR | Library | Declaratief | Stale-while-revalidate (vervangt cache pattern), auto revalidation (vervangt polling pattern), mutation (vervangt cache update), focus revalidation (vervangt manual refresh), pagination (vervangt offset tracking), SSR support (vervangt server-side data prep), deduplication (vervangt request dedup) |
| 74 | Apollo Client | Library | Declaratief/GraphQL | Normalized cache (vervangt manuele caching), reactive variables (vervangt local state management), optimistic UI (vervangt pessimistic update pattern), type policies (vervangt cache customization), link chain (vervangt middleware pattern), code generation (vervangt handmatige type definitions) |
| 75 | tRPC | Library | Type-safe RPC | End-to-end type safety (vervangt API type generation), procedure definitions (vervangt REST endpoint boilerplate), middleware (vervangt auth/validation chain), subscriptions (vervangt WebSocket setup), inference (vervangt schema duplication), adapters (vervangt server integration code) |
| 76 | Prisma | ORM/Library | Declaratief | Schema-first (vervangt migration boilerplate), type-safe queries (vervangt raw SQL risks), auto-generated client (vervangt query builder setup), migrations (vervangt manual schema changes), introspection (vervangt reverse engineering), Prisma Studio (vervangt DB GUI tools), relations (vervangt join boilerplate) |
| 77 | TypeORM | ORM/Library | OOP | Decorators voor entities (vervangt schema files), repository pattern (vervangt custom DAO), migrations (vervangt schema management), query builder (vervangt raw SQL), relations (vervangt join management), subscribers (vervangt database event handling), multiple DB support (vervangt adapter pattern) |
| 78 | Sequelize | ORM/Library | OOP | Model definitions (vervangt schema management), associations (vervangt relationship management), migrations (vervangt DDL scripts), hooks (vervangt lifecycle event handling), transactions (vervangt manual transaction management), scopes (vervangt query presets), paranoid mode (vervangt soft-delete pattern) |
| 79 | SQLAlchemy | ORM/Library | Multi | Core + ORM dual layer (vervangt query builder vs ORM keuze), session management (vervangt connection handling), declarative mapping (vervangt schema definition), hybrid properties (vervangt computed column pattern), events (vervangt database lifecycle hooks), alembic migrations (vervangt schema versioning) |
| 80 | Drizzle | ORM/Library | Functioneel | TypeScript-first schema (vervangt schema files), SQL-like API (vervangt abstraction overhead), zero-overhead (vervangt ORM performance penalty), migrations (vervangt schema management), relational queries (vervangt join boilerplate), Drizzle Kit (vervangt migration tooling), prepared statements (vervangt query optimization) |

---

### 7. ORM/Database (7 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 81 | Hibernate | ORM | OOP | JPA annotations (vervangt XML mapping), HQL/JPQL (vervangt native SQL), lazy loading (vervangt manual fetch optimization), caching (L1/L2 — vervangt cache layer), criteria API (vervangt dynamic query building), entity lifecycle (vervangt manual state tracking), automatic DDL (vervangt manual schema creation) |
| 82 | Entity Framework Core | ORM | OOP | LINQ-to-SQL (vervangt raw queries), code-first migrations (vervangt manual DDL), change tracking (vervangt dirty checking pattern), conventions (vervangt explicit configuration), shadow properties (vervangt audit column boilerplate), value conversions (vervangt type mapping), compiled queries (vervangt query optimization) |
| 83 | Eloquent | ORM | OOP/ActiveRecord | ActiveRecord pattern (vervangt DAO/repository), mass assignment protection (vervangt input filtering), accessors/mutators (vervangt getter/setter), scopes (vervangt query presets), relationships (vervangt join management), soft deletes (vervangt delete flag pattern), factories (vervangt test data generation), casts (vervangt type conversion) |
| 84 | ActiveRecord (Ruby) | ORM | OOP/ActiveRecord | Convention-based mapping (vervangt config), callbacks (vervangt lifecycle hooks), validations (vervangt input validation), associations (vervangt join queries), scopes (vervangt named queries), migrations (vervangt DDL scripts), serialization (vervangt output formatting) |
| 85 | Mongoose | ODM | OOP | Schema definitions (vervangt schemaless chaos), middleware/hooks (vervangt lifecycle pattern), virtuals (vervangt computed properties), population (vervangt manual join), plugins (vervangt cross-cutting concerns), validation (vervangt input checking), discriminators (vervangt single-table inheritance) |
| 86 | GORM | ORM | Multi | Convention-based (vervangt config), auto-migration (vervangt DDL management), hooks (vervangt lifecycle callbacks), associations (vervangt join handling), soft delete (vervangt delete flag), composite primary keys (vervangt workarounds), transaction support (vervangt manual tx management), preload/joins (vervangt N+1 solving) |
| 87 | Diesel | ORM | Functioneel/Type-safe | Compile-time query checking (vervangt runtime SQL errors), schema DSL (vervangt raw migrations), type-safe queries (vervangt SQL injection risks), connection pooling (vervangt manual pool management), associations (vervangt join boilerplate), custom types (vervangt type mapping), migrations (vervangt schema management) |

---

### 8. Testing (10 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 88 | Jest | Framework | Multi | Snapshot testing (vervangt manual output comparison), mocking (vervangt dependency injection voor tests), coverage (vervangt coverage tool setup), watch mode (vervangt file watcher), parallel execution (vervangt test runner config), expect matchers (vervangt assertion library), timer mocks (vervangt time manipulation) |
| 89 | Vitest | Framework | Multi | Vite-native (vervangt Webpack-gebaseerde test setup), Jest-compatible API (vervangt migration effort), in-source testing (vervangt separate test files), workspace support (vervangt monorepo test config), browser mode (vervangt DOM simulation), benchmark (vervangt performance test tools), type testing (vervangt type-level tests) |
| 90 | Pytest | Framework | Multi | Fixtures (vervangt setup/teardown boilerplate), parametrize (vervangt test duplication), conftest.py (vervangt shared setup), plugins (vervangt test utility libraries), markers (vervangt test categorization), assert rewriting (vervangt assertion library), monkeypatch (vervangt mock library) |
| 91 | JUnit 5 | Framework | OOP | Annotations (vervangt test registration), parameterized tests (vervangt data-driven boilerplate), extensions (vervangt test runners), nested tests (vervangt test organization), display names (vervangt test naming convention), assumptions (vervangt conditional test execution), dynamic tests (vervangt test generation) |
| 92 | xUnit | Framework | OOP | Constructor DI (vervangt setup methods), theories (vervangt parameterized tests), collection fixtures (vervangt shared context), trait-based filtering (vervangt test categories), IAsyncLifetime (vervangt async setup/teardown), output helpers (vervangt logging in tests) |
| 93 | Cypress | Framework | Declaratief | Auto-waiting (vervangt explicit waits/sleeps), time travel debugging (vervangt manual debugging), network stubbing (vervangt mock server), screenshots/video (vervangt manual evidence), component testing (vervangt unit test for components), real browser (vervangt simulated DOM) |
| 94 | Playwright | Framework | Multi | Multi-browser (vervangt per-browser test tools), auto-waiting (vervangt explicit waits), codegen (vervangt manual test writing), trace viewer (vervangt debugging tools), fixtures (vervangt setup/teardown), API testing (vervangt REST test tools), visual comparison (vervangt screenshot diff tools) |
| 95 | Testing Library | Library | Declaratief | User-centric queries (vervangt implementation-detail testing), framework adapters (vervangt framework-specifieke test utils), accessibility-first selectors (vervangt CSS selector testing), userEvent (vervangt manual event simulation), screen queries (vervangt container queries), async utilities (vervangt wait helpers) |
| 96 | Mocha | Framework | Multi | BDD/TDD interface (vervangt test organization), hooks (vervangt setup/teardown), reporters (vervangt output formatting), async support (vervangt callback testing), watch mode (vervangt file watcher), extensible (vervangt monolithic test frameworks) |
| 97 | NUnit | Framework | OOP | Attributes (vervangt test registration), TestFixture lifecycle (vervangt setup/teardown), Assert.That fluent API (vervangt basic assertions), parameterized tests (vervangt data-driven boilerplate), categories (vervangt test filtering), parallel execution (vervangt sequential running) |

---

### 9. Build/Tooling (9 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 98 | Webpack | Bundler | Config-driven | Code splitting (vervangt manual chunking), tree shaking (vervangt dead code removal), loaders (vervangt file transformation pipeline), plugins (vervangt build step scripting), HMR (vervangt full page reload), module federation (vervangt micro-frontend setup), asset modules (vervangt file-loader/url-loader) |
| 99 | Vite | Bundler/DevServer | Convention-based | Native ESM dev server (vervangt bundle-first development), HMR (vervangt full page reload), Rollup-based production (vervangt custom build), env variables (vervangt dotenv setup), CSS modules/PostCSS (vervangt CSS tooling setup), glob import (vervangt dynamic require), library mode (vervangt library bundling setup) |
| 100 | esbuild | Bundler | Minimalistisch | Go-based speed (vervangt slow JS bundlers), built-in minification (vervangt terser), built-in JSX/TS (vervangt Babel), CSS bundling (vervangt CSS tooling), tree shaking (vervangt dead code removal), serve mode (vervangt dev server setup) |
| 101 | Turbopack | Bundler | Incremental | Incremental computation (vervangt full rebuild), Rust-based speed (vervangt JS bundler overhead), Next.js integration (vervangt Webpack voor Next), function-level caching (vervangt file-level caching) |
| 102 | Nx | Monorepo Tool | Multi | Computation caching (vervangt redundante builds), affected commands (vervangt full rebuild), dependency graph (vervangt manual dep tracking), code generators (vervangt scaffolding scripts), remote caching (vervangt CI cache setup), module boundaries (vervangt dependency rules), plugins (vervangt custom tooling) |
| 103 | Turborepo | Monorepo Tool | Multi | Task caching (vervangt redundante builds), pipeline definitions (vervangt task ordering), remote caching (vervangt CI cache setup), pruned workspaces (vervangt Docker build optimization), parallel execution (vervangt sequential scripts) |
| 104 | Rollup | Bundler | Minimalistisch | Tree shaking (vervangt dead code removal), ES module output (vervangt CommonJS bundles), plugin API (vervangt custom transforms), code splitting (vervangt manual chunking), library-optimized (vervangt app-focused bundlers) |
| 105 | SWC | Compiler | Performance | Rust-based transpilation (vervangt Babel), minification (vervangt terser), plugin support (vervangt Babel plugins), TypeScript stripping (vervangt tsc voor transpilation) |
| 106 | Biome | Linter/Formatter | Unified | Lint + format (vervangt ESLint + Prettier combo), Rust-based speed (vervangt JS tooling overhead), zero config (vervangt config boilerplate), import sorting (vervangt import-sort plugins) |

---

### 10. Runtime/Infra (7 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 107 | Node.js | Runtime | Event-driven | Event loop (vervangt thread-per-request), npm/yarn/pnpm (vervangt dependency management), native modules (vervangt C/C++ FFI), worker threads (vervangt multi-process patterns), native fetch (vervangt node-fetch/axios), native test runner (vervangt Jest/Mocha voor basics), corepack (vervangt package manager management) |
| 108 | Deno | Runtime | Secure-by-default | Permissions (vervangt security middleware), native TypeScript (vervangt tsc setup), built-in formatter/linter/test (vervangt toolchain setup), URL imports (vervangt package manager), Web API compatibility (vervangt polyfills), KV store (vervangt external DB voor simple state), Fresh framework (vervangt meta-framework keuze) |
| 109 | Bun | Runtime | Performance | All-in-one (vervangt Node + npm + bundler), native TypeScript/JSX (vervangt transpiler), built-in test runner (vervangt test framework), built-in bundler (vervangt Webpack/Vite), SQLite built-in (vervangt external DB driver), FFI (vervangt N-API), hot reloading (vervangt nodemon) |
| 110 | Docker | Platform | Containerization | Container images (vervangt "works on my machine"), Dockerfile (vervangt environment setup scripts), compose (vervangt multi-service orchestration), multi-stage builds (vervangt build optimization scripts), volumes (vervangt data persistence setup), networks (vervangt inter-service communication), BuildKit (vervangt legacy builder) |
| 111 | Kubernetes | Platform | Orchestration | Pods/Deployments (vervangt manual scaling), Services (vervangt load balancer config), ConfigMaps/Secrets (vervangt config management), Ingress (vervangt reverse proxy setup), HPA (vervangt auto-scaling scripts), namespaces (vervangt environment isolation), operators (vervangt operational automation), Helm (vervangt deployment templating) |
| 112 | Podman | Platform | Containerization | Daemonless (vervangt Docker daemon), rootless (vervangt privileged containers), pod concept (vervangt multi-container orchestration), Docker-compatible CLI (vervangt migration effort), systemd integration (vervangt container management) |
| 113 | Terraform | IaC | Declaratief | HCL declarative syntax (vervangt imperative infra scripts), state management (vervangt manual tracking), plan/apply (vervangt risky deployments), providers (vervangt vendor-specifieke CLI), modules (vervangt infra code reuse), workspaces (vervangt environment management) |

---

### 11. Mobile (5 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 114 | Flutter | Framework | Declaratief/OOP | Widget tree (vervangt imperative UI building), hot reload (vervangt slow rebuild cycles), platform channels (vervangt native bridge pattern), Riverpod/Provider (vervangt state management boilerplate), Material/Cupertino widgets (vervangt custom UI components), Dart isolates (vervangt threading patterns), built-in testing (vervangt test framework setup) |
| 115 | React Native | Framework | Declaratief | Cross-platform native UI (vervangt dual codebase), hot reload (vervangt rebuild cycles), bridge/JSI (vervangt native module FFI), Expo (vervangt native build toolchain), Reanimated (vervangt native animation), New Architecture/Fabric (vervangt legacy bridge overhead), Hermes engine (vervangt JavaScriptCore) |
| 116 | SwiftUI | Framework | Declaratief | Declarative syntax (vervangt UIKit imperative code), @State/@Binding/@Published (vervangt observer pattern), Combine integration (vervangt reactive setup), previews (vervangt simulator rebuilds), property wrappers (vervangt boilerplate), NavigationStack (vervangt UINavigationController), async/await (vervangt completion handlers) |
| 117 | Jetpack Compose | Framework | Declaratief | Composable functions (vervangt XML layouts), remember/state (vervangt lifecycle-aware state), side effects (vervangt lifecycle callbacks), theming (vervangt style resources), navigation compose (vervangt fragment management), coroutines integration (vervangt callback patterns), Modifier chains (vervangt XML attributes) |
| 118 | Kotlin Multiplatform | Framework | Multi | Shared business logic (vervangt duplicate code), expect/actual (vervangt platform abstraction), coroutines (vervangt platform-specifieke async), Ktor (vervangt platform-specifieke networking), SQLDelight (vervangt platform-specifieke DB), Compose Multiplatform (vervangt per-platform UI) |

---

### 12. Annotation/DI Frameworks (12 entries)

| # | Platform | Type | Paradigma | Native Pattern-Vervangers |
|---|----------|------|-----------|---------------------------|
| 119 | Spring DI (Java) | DI Framework | OOP | @Autowired/@Component/@Service (vervangt manual DI), profiles (vervangt environment-based wiring), @Qualifier (vervangt ambiguity resolution), @Scope (vervangt lifecycle management), @Configuration/@Bean (vervangt factory pattern), @ConditionalOn (vervangt feature flags), component scanning (vervangt explicit registration) |
| 120 | .NET DI | DI Framework | OOP | IServiceCollection (vervangt third-party containers), Scoped/Transient/Singleton (vervangt lifecycle management), IOptions pattern (vervangt config injection), hosted services (vervangt background task management), keyed services (vervangt named registrations), minimal API integration (vervangt controller DI) |
| 121 | Angular DI | DI Framework | OOP | Hierarchical injectors (vervangt flat DI), providedIn (vervangt module registration), InjectionToken (vervangt interface-based injection), multi providers (vervangt plugin registration), useFactory/useValue/useClass (vervangt factory pattern), environment injector (vervangt lazy-loaded service scoping) |
| 122 | NestJS DI | DI Framework | OOP | Module-scoped providers (vervangt global registration), @Injectable (vervangt manual factory), custom providers (vervangt complex factory patterns), async providers (vervangt async initialization), request-scoped (vervangt per-request state), circular dependency handling (vervangt workarounds) |
| 123 | Dagger/Hilt (Android) | DI Framework | OOP | Compile-time DI (vervangt runtime reflection DI), @Module/@Provides (vervangt manual factory), @HiltViewModel (vervangt ViewModel factory), @InstallIn (vervangt component scoping), multi-bindings (vervangt plugin registration), assisted inject (vervangt parameterized factories) |
| 124 | InversifyJS | DI Library | OOP | TypeScript decorators (vervangt manual binding), container (vervangt service locator), @injectable/@inject (vervangt constructor boilerplate), named bindings (vervangt ambiguity resolution), contextual bindings (vervangt conditional wiring), middleware (vervangt interception), auto-named (vervangt string identifiers) |
| 125 | Guice (Java) | DI Framework | OOP | Annotations (vervangt XML config), modules (vervangt factory pattern), scopes (vervangt lifecycle management), multibindings (vervangt plugin pattern), AOP support (vervangt proxy pattern), type-safe binding (vervangt string keys), just-in-time bindings (vervangt explicit registration) |
| 126 | Autofac (.NET) | DI Library | OOP | Module system (vervangt registration boilerplate), lifetime scopes (vervangt manual lifecycle), property injection (vervangt constructor-only DI), interceptors (vervangt proxy pattern), decorators (vervangt manual decoration), assembly scanning (vervangt explicit registration) |
| 127 | Koin (Kotlin) | DI Library | Multi | DSL-based (vervangt annotation processing), no code generation (vervangt compile-time overhead), module composition (vervangt factory pattern), scope management (vervangt lifecycle handling), ViewModel injection (vervangt factory pattern), Compose integration (vervangt manual wiring) |
| 128 | tsyringe | DI Library | OOP | Decorator-based (vervangt manual registration), container (vervangt service locator), @injectable/@inject (vervangt constructor wiring), singleton/transient (vervangt lifecycle management), child containers (vervangt scoped registrations) |
| 129 | Wire (Go) | DI Tool | Multi | Compile-time code generation (vervangt runtime reflection), provider functions (vervangt manual wiring), injector generation (vervangt factory boilerplate), interface bindings (vervangt explicit implementations), cleanup functions (vervangt lifecycle management) |
| 130 | Fx (Go/Uber) | DI Framework | Multi | Constructor injection (vervangt manual wiring), lifecycle hooks (vervangt startup/shutdown management), module composition (vervangt init() chains), Provide/Invoke (vervangt factory pattern), decoration (vervangt wrapper pattern) |

---

## Statistieken

| Categorie | Aantal |
|-----------|--------|
| 1. Programmeertalen | 22 |
| 2. Frontend Frameworks | 12 |
| 3. Meta-Frameworks | 8 |
| 4. Backend Frameworks | 17 |
| 5. State Management | 11 |
| 6. Data/Query Libraries | 10 |
| 7. ORM/Database | 7 |
| 8. Testing | 10 |
| 9. Build/Tooling | 9 |
| 10. Runtime/Infra | 7 |
| 11. Mobile | 5 |
| 12. Annotation/DI Frameworks | 12 |
| **Totaal** | **130** |

## Observaties

### Cross-cutting patronen die door platforms worden vervangen

1. **Dependency Injection** — Native in Angular, NestJS, Spring, ASP.NET Core, FastAPI, Dagger, Guice; geen apart DI framework nodig
2. **Observer/Pub-Sub** — Vervangen door signals (Angular/Solid/Svelte), RxJS (Angular), MobX observables, Vue reactivity
3. **Builder Pattern** — Vervangen door named arguments (Python/Kotlin/PHP), data classes/records (Kotlin/Java/C#), DSL builders (Kotlin)
4. **Factory Pattern** — Vervangen door DI containers, factory constructors (Dart), companion objects (Scala/Kotlin)
5. **Iterator Pattern** — Vervangen door generators (JS/Python), streams (Java), ranges (C++), for-comprehensions (Scala)
6. **Visitor Pattern** — Vervangen door pattern matching (Rust/Kotlin/Scala/C#/Python), sealed classes, algebraic data types
7. **State Pattern** — Vervangen door state machines (XState), discriminated unions (TS), sealed classes (Kotlin)
8. **Null Object Pattern** — Vervangen door optionals (Swift/Rust/Kotlin), null safety (Dart/Kotlin), Result types (Rust)
9. **Proxy/Decorator Pattern** — Vervangen door Proxy/Reflect (JS), AOP (Spring/AspectJ), middleware (Express/NestJS), interceptors (Angular)
10. **Template Method** — Vervangen door hooks (React), lifecycle callbacks (Angular/Vue), behaviours (Elixir)

---

## Volgende stappen

Dit tussenresultaat wordt in Fase 3 gebruikt om:

1. Per-platform pattern-relevantie te bepalen
2. cpm-regels te taggen met platform-awareness
3. False positives te elimineren (bijv. geen "missing DI" waarschuwen bij Angular)
4. Platform-specifieke checks toe te voegen
