# R-030: Design Patterns vs Native Platform Features

**Date:** 2026-08-30
**Status:** Research
**Scope:** 137 patterns × 130 platforms
**Related:** [R-029 Production Readiness](R-029-production-readiness.md) | [ADR-166 Rule Engine Extensions](../adrs/adr-166-rule-engine-extensions.md)

---

## Executive Summary

Design patterns zijn oplossingen voor terugkerende problemen — maar het probleem is dat veel van die problemen al zijn opgelost door het platform dat je gebruikt. Dit onderzoek catalogiseert **137 design patterns** in 15 categorieën en **130 platforms** in 12 categorieën, en kruist ze in een matrix die laat zien waar patterns waarde toevoegen en waar ze overbodig zijn.

**De kerncijfers**: van de 600 meest relevante pattern×platform combinaties (20 patterns × 30 platforms) is **27% native opgelost**, **22% heeft een beter alternatief**, en slechts **33% is de standaard aanpak**. Bijna de helft (49%) van de gevallen heeft een native of alternatieve oplossing waardoor het klassieke pattern overbodig of suboptimaal is.

**Wanneer SOLID**: SOLID-principes zijn taal-agnostisch waardevol als *denkmodel*, maar de implementatie verschilt radicaal per taal. TypeScript's structural typing maakt ISP triviaal met `Pick`/`Omit`. Java heeft een heel DI-ecosysteem voor DIP. Python's duck typing maakt LSP oncontroleerbaar at compile time. Ken je taal, pas de principes aan.

**Wanneer RTFM**: Als je framework DI, Observer, Factory, Repository of State Management biedt — en dat doen Angular, NestJS, Spring, Django, Rails, Laravel, FastAPI, en alle moderne frontend-frameworks — implementeer die patterns dan **niet handmatig**. Het framework *is* het pattern.

**De #1 takeaway**: De beste code is de code die je niet schrijft. Voordat je een design pattern implementeert, check of je platform het al heeft. `RTFM > SOLID`.

---

## 1. Methodologie

### 1.1 Catalogiseringaanpak

Drie parallelle catalogiseringen, daarna gecombineerd:

1. **Pattern Catalogus** (137 entries): Gebaseerd op GoF (1994), Fowler's PoEAA (2002), Hohpe & Woolf's Enterprise Integration Patterns (2003), Martin's Clean Architecture (2017), en moderne framework-specifieke patronen. Elke pattern heeft een beschrijving en het kernprobleem dat het oplost.

2. **Platform Catalogus** (130 entries): Alle relevante programmeertalen (22), frontend-frameworks (12), meta-frameworks (8), backend-frameworks (17), state management libraries (11), data/query libraries (10), ORMs (7), testframeworks (10), build tools (9), runtimes/infra (7), mobile frameworks (5), en DI-frameworks (12). Per platform zijn de native pattern-vervangers gedocumenteerd.

3. **Matrix Analyse**: Top 20 meest universele patterns × top 30 meest gebruikte platforms. Per combinatie beoordeeld op een 5-puntsschaal. Aangevuld met deep-dives, per-categorie analyses, en 70 concrete RTFM-voorbeelden.

### 1.2 Classificatiesysteem

Elke pattern×platform combinatie krijgt één van vijf classificaties:

| Symbool | Classificatie | Betekenis |
|---------|--------------|-----------|
| ✅ | **Native** | Platform heeft dit ingebouwd. Pattern is overbodig. |
| 🔧 | **Supported** | Pattern past goed en is de standaard aanpak. |
| 🔄 | **Alternative** | Er is een betere platform-specifieke oplossing. |
| ⚠️ | **Overkill** | Pattern bestaat maar is te zwaar voor dit platform. |
| 🚫 | **N/A** | Pattern is niet relevant voor dit platform. |

### 1.3 Bronnen

- Gamma, E. et al. (1994). *Design Patterns: Elements of Reusable Object-Oriented Software* (GoF)
- Fowler, M. (2002). *Patterns of Enterprise Application Architecture* (PoEAA)
- Hohpe, G. & Woolf, B. (2003). *Enterprise Integration Patterns*
- Vernon, V. (2013). *Implementing Domain-Driven Design*
- Richards, M. (2015). *Software Architecture Patterns* (O'Reilly)
- Nygard, M. (2007). *Release It!* — stability patterns
- Martin, R.C. (2017). *Clean Architecture*
- Officiële documentatie van alle 130 gecatalogiseerde platforms

---

## 2. Pattern Catalogus (samenvatting)

### 2.1 Totaal per categorie

| # | Categorie | Aantal | Kerngebied |
|---|-----------|--------|------------|
| 1 | GoF Creational | 5 | Object-creatie (Singleton, Factory, Builder, Abstract Factory, Prototype) |
| 2 | GoF Structural | 7 | Object-structuur (Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy) |
| 3 | GoF Behavioral | 11 | Object-interactie (Chain of Resp., Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor, Interpreter) |
| 4 | SOLID Principles | 5 | Ontwerpprincipes (SRP, OCP, LSP, ISP, DIP) |
| 5 | Enterprise / Integration | 17 | Distributed systems (Repository, UoW, CQRS, Event Sourcing, Saga, Circuit Breaker, Retry, etc.) |
| 6 | Concurrency | 12 | Parallellisme (Active Object, Monitor, Producer-Consumer, Thread Pool, Future, Actor, etc.) |
| 7 | Functional | 12 | FP-patronen (Monad, Functor, Lens, Pipe, Currying, Memoization, Either, Option, ADT, etc.) |
| 8 | Architecture | 13 | Systeemarchitectuur (MVC, MVVM, Clean, Hexagonal, Layered, Event-Driven, Serverless, etc.) |
| 9 | State Management | 7 | UI-state (Flux, Redux, State Machine, Store Pattern, Event Store, Snapshot) |
| 10 | Data | 10 | Data-toegang (Active Record, Data Mapper, DTO, Value Object, Repository, Lazy/Eager Load, etc.) |
| 11 | UI / Frontend | 9 | Frontend-patronen (Container/Presentational, Compound Component, HOC, Hooks, Atomic Design, etc.) |
| 12 | API / Communication | 8 | API-ontwerp (REST, GraphQL, RPC, BFF, API Gateway, HATEOAS, etc.) |
| 13 | Testing | 8 | Testpatronen (AAA, Given-When-Then, Mock, Fixture, Page Object, etc.) |
| 14 | Security | 6 | Beveiligingspatronen (Null Object, Guard Clause, Sanitization Pipeline, etc.) |
| 15 | Meta / Cross-Cutting | 7 | Doorsnijdend (DI, IoC, Plugin, Module, Interceptor, Middleware, Decorator) |
| | **Totaal** | **137** | |

### 2.2 Top 20 meest universeel bruikbare patterns

Geselecteerd op basis van brede toepasbaarheid over talen, frameworks en domeinen:

| # | Pattern | Categorie | Waarom universeel |
|---|---------|-----------|-------------------|
| 1 | **Strategy** | GoF Behavioral | Algoritme-uitwisseling is altijd relevant, ongeacht taal of framework |
| 2 | **Adapter** | GoF Structural | Third-party integratie is onvermijdelijk |
| 3 | **Facade** | GoF Structural | Complexiteit verbergen is universeel nodig |
| 4 | **Guard Clause** | Security | Elke publieke methode profiteert ervan |
| 5 | **Repository** | Enterprise | Data-toegang abstraheren blijft waardevol (ook al genereren ORMs het) |
| 6 | **Middleware** | Meta | Request/response-pipelines zijn de standaard |
| 7 | **Circuit Breaker** | Enterprise | Elke externe service-aanroep heeft dit nodig |
| 8 | **Command** | GoF Behavioral | Undo/redo, event sourcing, task scheduling |
| 9 | **State Machine** | State Mgmt | Elke workflow met > 3 toestanden |
| 10 | **Result/Either** | Functional | Expliciet foutpad zonder hidden exceptions |
| 11 | **Value Object** | Data | Voorkomt primitive obsession |
| 12 | **DI (als concept)** | Meta | Testbaarheid en flexibiliteit |
| 13 | **Factory Method** | GoF Creational | Polymorphe creatie blijft nodig |
| 14 | **Observer (als concept)** | GoF Behavioral | Event-driven systemen zijn overal |
| 15 | **Retry met backoff** | Enterprise | Netwerkcommunicatie faalt |
| 16 | **AAA / Given-When-Then** | Testing | Universele teststructuur |
| 17 | **Anti-Corruption Layer** | API | Third-party rot buiten houden |
| 18 | **Modular Monolith** | Architecture | Voorkomt premature microservices |
| 19 | **Idempotent Receiver** | Enterprise | Elke message consumer heeft dit nodig |
| 20 | **Specification** | Data | Composable business rules |

### 2.3 Top 10 meest overgewaardeerde patterns

Patterns die het vaakst onnodig worden geïmplementeerd:

| # | Pattern | Waarom overschat | Gebruik in plaats daarvan |
|---|---------|------------------|--------------------------|
| 1 | **Singleton** (handmatig) | Module-systemen en DI-containers lossen dit op | Module-scope of DI-registratie |
| 2 | **Observer** (handmatig) | Reactive frameworks doen dit native | RxJS, signals, reactivity, channels |
| 3 | **Factory** (handmatig) | DI-containers *zijn* de factory | `useFactory`, `@Bean`, `Depends()` |
| 4 | **Repository** (handmatig) | ORMs genereren het | Spring Data, Prisma, Eloquent |
| 5 | **Builder** (klassiek) | Named args, data classes, spread operator | Taal-native constructie |
| 6 | **Iterator** (handmatig) | Taal-native in alle moderne talen | Generators, streams, LINQ, ranges |
| 7 | **Visitor** (klassiek) | Pattern matching vervangt het | `match`, `when`, sealed classes |
| 8 | **Template Method** (klassiek) | Hooks en lifecycle callbacks vervangen overerving | Framework lifecycle hooks |
| 9 | **Service Locator** | Anti-pattern in DI-contexten | Constructor injection via DI |
| 10 | **Decorator** (klassieke wrapper) | Taal-decorators, middleware, interceptors | `@decorator`, middleware pipeline |

---

## 3. Platform Catalogus (samenvatting)

### 3.1 Totaal per type

| # | Categorie | Aantal | Voorbeelden |
|---|-----------|--------|-------------|
| 1 | Programmeertalen | 22 | TypeScript, Python, Java, C++, Go, Rust, C#, Kotlin, Ruby, PHP, Swift, Dart, Scala, Elixir, Haskell, Clojure, Lua, R, Zig, OCaml, V |
| 2 | Frontend Frameworks | 12 | Angular, React, Vue, Svelte, Solid.js, Qwik, Lit, Alpine.js, Htmx, Ember, Preact, Stencil |
| 3 | Meta-Frameworks | 8 | Next.js, Nuxt, SvelteKit, Remix, Astro, Analog, Fresh, Gatsby |
| 4 | Backend Frameworks | 17 | NestJS, FastAPI, Express, Django, Flask, Spring Boot, ASP.NET Core, Rails, Laravel, Phoenix, Gin, Actix Web, Fastify, Hono, Fiber, Koa, Chi |
| 5 | State Management | 11 | NgRx, Redux/RTK, Zustand, Pinia, MobX, Recoil, Jotai, XState, Signals, Akita, Effector |
| 6 | Data/Query Libraries | 10 | TanStack Query, TanStack Table, SWR, Apollo Client, tRPC, Prisma, TypeORM, Sequelize, SQLAlchemy, Drizzle |
| 7 | ORM/Database | 7 | Hibernate, EF Core, Eloquent, ActiveRecord, Mongoose, GORM, Diesel |
| 8 | Testing | 10 | Jest, Vitest, Pytest, JUnit 5, xUnit, Cypress, Playwright, Testing Library, Mocha, NUnit |
| 9 | Build/Tooling | 9 | Webpack, Vite, esbuild, Turbopack, Nx, Turborepo, Rollup, SWC, Biome |
| 10 | Runtime/Infra | 7 | Node.js, Deno, Bun, Docker, Kubernetes, Podman, Terraform |
| 11 | Mobile | 5 | Flutter, React Native, SwiftUI, Jetpack Compose, Kotlin Multiplatform |
| 12 | Annotation/DI Frameworks | 12 | Spring DI, .NET DI, Angular DI, NestJS DI, Dagger/Hilt, InversifyJS, Guice, Autofac, Koin, tsyringe, Wire, Fx |
| | **Totaal** | **130** | |

### 3.2 Platforms met meeste native pattern-vervangers

Platforms die het meest aggressief traditionele patterns vervangen door native features:

| # | Platform | Native vervangers | Belangrijkste vervangingen |
|---|----------|-------------------|---------------------------|
| 1 | **Angular** | 10+ | DI, Observer (RxJS/signals), Decorator, Factory, Middleware (interceptors), MVC/MVVM, State, Guards |
| 2 | **Spring Boot** | 10+ | DI (@Autowired), Factory (@Bean), Observer (@EventListener), AOP, Repository (Spring Data), Config, Retry, Cache |
| 3 | **Rails** | 9+ | Active Record, Observer (callbacks), Middleware, Auth, Background Jobs, WebSocket (Action Cable), CSRF, Mailer |
| 4 | **Django** | 9+ | ORM (Manager), Observer (signals), Admin CRUD, Auth, Middleware, Forms, Migrations, CBV (Template Method), Cache |
| 5 | **NestJS** | 8+ | DI, Decorator, Factory (custom providers), Observer (EventEmitter), CQRS, Middleware (guards/interceptors/pipes), Validation, Swagger |
| 6 | **Rust** | 8+ | Iterator (trait), State (enum+match), Observer (channels), Guard Clause (Result/?), Singleton (lazy_static), Decorator (traits), Builder (derive) |
| 7 | **Kotlin** | 8+ | Singleton (object), Builder (data class+DSL), Adapter (extension fn), Decorator (by delegation), Observer (Flow), Iterator (sequences), Null Object (null safety) |
| 8 | **FastAPI** | 7+ | DI (Depends), Validation (Pydantic), Factory, OpenAPI docs, Decorator (@app.get), Config (BaseSettings), Background tasks |
| 9 | **Laravel** | 7+ | DI (service container), Eloquent (Active Record), Observer (events/listeners), Middleware, Auth (policies/gates), Queues, Facades |
| 10 | **C#** | 7+ | Observer (events/delegates), Iterator (LINQ), Decorator (extension methods), Pattern matching, Null Object (nullable refs), Records, Source generators |

### 3.3 Platforms waar patterns het meest nodig zijn

Platforms die weinig opinieus zijn en waar patterns zelf gekozen moeten worden:

| # | Platform | Reden | Welke patterns nodig |
|---|----------|-------|---------------------|
| 1 | **C++** | Low-level, weinig ingebouwde abstracties | Alle GoF patterns relevant, RAII > Dispose, Templates > Runtime polymorfisme |
| 2 | **Express** | Minimalistisch, geen DI, geen structuur | DI (handmatig of via library), Repository, Middleware chain, Error handling |
| 3 | **Go** | Eenvoud boven alles, geen classes | Interface-gebaseerde patterns, functional options (Builder), channels (Observer) |
| 4 | **Node.js** (runtime) | Runtime, geen framework-opinies | Alle architectuurpatronen moeten zelf gekozen worden |
| 5 | **Lua** | Minimalistisch, metatables zijn alles | OOP via metatables, coroutines voor async, tables voor alles |

---

## 4. De Matrix (kern)

### 4.1 Top 20 Patterns × Top 30 Platforms

#### Matrix A: Talen (L1–L10)

| Pattern | TS | Python | Java | C++ | Go | Rust | C# | Kotlin | Ruby | PHP |
|---------|:--:|:------:|:----:|:---:|:--:|:----:|:--:|:------:|:----:|:---:|
| P1 Singleton | 🔄 | 🔄 | 🔧 | 🔧 | 🔄 | 🔄 | 🔧 | 🔄 | 🔄 | 🔧 |
| P2 Factory | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 | 🔧 | 🔧 |
| P3 Builder | 🔄 | 🔄 | 🔧 | 🔧 | 🔄 | 🔧 | 🔄 | 🔄 | 🔄 | 🔄 |
| P4 Adapter | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 | 🔄 | 🔧 | 🔄 | 🔄 | 🔧 |
| P5 Decorator | 🔄 | 🔄 | 🔄 | 🔧 | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| P6 Observer | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 | 🔧 | ✅ | 🔄 | 🔧 | 🔧 |
| P7 Strategy | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 | 🔄 |
| P8 Iterator | ✅ | ✅ | ✅ | 🔄 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P9 Template Method | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 | 🔄 | 🔧 | 🔧 | 🔧 | 🔧 |
| P10 Command | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 | 🔧 | 🔧 | 🔄 | 🔄 | 🔧 |
| P11 State | 🔄 | 🔄 | 🔄 | 🔧 | 🔧 | ✅ | 🔄 | 🔄 | 🔧 | 🔄 |
| P12 DI | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| P13 Repository | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| P14 Middleware | 🔧 | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| P15 MVC/MVVM | 🔧 | 🔧 | 🔧 | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 |
| P16 Pub-Sub | 🔧 | 🔧 | 🔧 | 🔧 | ✅ | 🔧 | ✅ | 🔄 | 🔧 | 🔧 |
| P17 Circuit Breaker | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| P18 Active Record | 🔧 | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| P19 Redux/Flux | 🔧 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |
| P20 Guard Clause | 🔧 | 🔧 | 🔧 | 🔧 | ✅ | ✅ | 🔧 | 🔧 | 🔧 | 🔧 |

#### Matrix B: Frontend Frameworks (L11–L14)

| Pattern | Angular | React | Vue | Svelte |
|---------|:-------:|:-----:|:---:|:------:|
| P1 Singleton | ✅ | 🔄 | 🔄 | 🔄 |
| P2 Factory | ✅ | 🔄 | 🔄 | ⚠️ |
| P3 Builder | ✅ | 🔄 | 🔄 | ⚠️ |
| P4 Adapter | 🔧 | 🔧 | 🔧 | 🔧 |
| P5 Decorator | ✅ | 🔄 | ⚠️ | ⚠️ |
| P6 Observer | ✅ | 🔄 | ✅ | ✅ |
| P7 Strategy | 🔧 | 🔧 | 🔧 | 🔧 |
| P8 Iterator | ✅ | ✅ | ✅ | ✅ |
| P9 Template Method | ✅ | ✅ | ✅ | ✅ |
| P10 Command | 🔧 | 🔧 | 🔧 | 🔧 |
| P11 State | 🔄 | 🔄 | 🔧 | 🔄 |
| P12 DI | ✅ | 🔄 | 🔄 | 🚫 |
| P13 Repository | 🔧 | ⚠️ | ⚠️ | ⚠️ |
| P14 Middleware | ✅ | 🔄 | 🔄 | 🚫 |
| P15 MVC/MVVM | ✅ | 🔄 | ✅ | 🔄 |
| P16 Pub-Sub | ✅ | 🔄 | 🔄 | 🔄 |
| P17 Circuit Breaker | 🔧 | 🔧 | 🔧 | ⚠️ |
| P18 Active Record | 🚫 | 🚫 | 🚫 | 🚫 |
| P19 Redux/Flux | 🔄 | 🔧 | 🔄 | 🔄 |
| P20 Guard Clause | ✅ | 🔧 | 🔧 | 🔧 |

#### Matrix C: Meta-Frameworks & Backend (L15–L23)

| Pattern | Next.js | NestJS | Express | FastAPI | Spring | Django | Rails | Laravel | ASP.NET |
|---------|:-------:|:------:|:-------:|:-------:|:------:|:------:|:-----:|:-------:|:-------:|
| P1 Singleton | 🔄 | ✅ | 🔄 | 🔄 | ✅ | 🔄 | 🔄 | ✅ | ✅ |
| P2 Factory | 🔄 | ✅ | 🔧 | ✅ | ✅ | 🔧 | 🔧 | ✅ | ✅ |
| P3 Builder | 🔄 | 🔧 | 🔧 | 🔄 | ✅ | 🔄 | 🔄 | 🔧 | 🔄 |
| P4 Adapter | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| P5 Decorator | 🔄 | ✅ | 🔧 | ✅ | ✅ | 🔄 | 🔄 | 🔧 | ✅ |
| P6 Observer | 🔧 | ✅ | 🔄 | 🔧 | ✅ | ✅ | ✅ | ✅ | ✅ |
| P7 Strategy | 🔧 | ✅ | 🔧 | ✅ | ✅ | 🔧 | 🔧 | ✅ | ✅ |
| P8 Iterator | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P9 Template | ✅ | ✅ | 🔧 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P10 Command | 🔄 | ✅ | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | ✅ | 🔧 |
| P11 State | 🔄 | 🔧 | 🚫 | 🚫 | 🔧 | 🚫 | 🚫 | 🚫 | 🚫 |
| P12 DI | 🔄 | ✅ | 🚫 | ✅ | ✅ | 🔄 | 🔄 | ✅ | ✅ |
| P13 Repository | 🚫 | 🔧 | 🔧 | 🔧 | ✅ | ✅ | ✅ | ✅ | ✅ |
| P14 Middleware | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P15 MVC | 🔄 | ✅ | 🔄 | 🔄 | ✅ | ✅ | ✅ | ✅ | ✅ |
| P16 Pub-Sub | 🔧 | ✅ | 🔧 | 🔧 | ✅ | ✅ | ✅ | ✅ | ✅ |
| P17 Circuit Breaker | 🔧 | 🔧 | 🔧 | 🔧 | ✅ | 🔧 | 🔧 | 🔧 | ✅ |
| P18 Active Record | 🚫 | 🔧 | 🚫 | 🔧 | 🔄 | ✅ | ✅ | ✅ | 🔄 |
| P19 Redux/Flux | 🔧 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |
| P20 Guard | ✅ | ✅ | 🔧 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

#### Matrix D: Overige (L24–L30)

| Pattern | Redux/RTK | Node.js | Docker | Flutter | React Native | Prisma | Hibernate |
|---------|:---------:|:-------:|:------:|:-------:|:------------:|:------:|:---------:|
| P1 Singleton | ✅ | 🔄 | 🚫 | 🔧 | 🔄 | 🚫 | ✅ |
| P2 Factory | ✅ | 🔧 | 🚫 | 🔧 | 🔧 | ✅ | ✅ |
| P3 Builder | ✅ | 🔧 | ✅ | 🔧 | 🔧 | ✅ | ✅ |
| P4 Adapter | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 |
| P5 Decorator | 🔄 | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | ✅ |
| P6 Observer | ✅ | ✅ | 🚫 | 🔧 | 🔧 | 🚫 | ✅ |
| P7 Strategy | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🔧 |
| P8 Iterator | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | ✅ |
| P9 Template | 🔄 | 🔧 | ✅ | 🔧 | 🔧 | 🚫 | ✅ |
| P10 Command | ✅ | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🔧 |
| P11 State | ✅ | 🚫 | 🚫 | 🔧 | 🔧 | 🚫 | ✅ |
| P12 DI | 🚫 | 🚫 | 🚫 | 🔧 | 🔄 | 🚫 | ✅ |
| P13 Repository | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | ✅ | ✅ |
| P14 Middleware | ✅ | ✅ | 🚫 | 🚫 | 🚫 | ✅ | ✅ |
| P15 MVC | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🚫 |
| P16 Pub-Sub | ✅ | ✅ | 🚫 | 🔧 | 🔧 | 🚫 | ✅ |
| P17 Circuit Breaker | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🚫 |
| P18 Active Record | 🚫 | 🔧 | 🚫 | 🔧 | 🚫 | 🔄 | 🔄 |
| P19 Redux/Flux | ✅ | 🚫 | 🚫 | 🔄 | 🔧 | 🚫 | 🚫 |
| P20 Guard | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | ✅ | ✅ |

### 4.2 Heatmap-samenvatting

| Symbool | Aantal | Percentage | Interpretatie |
|---------|--------|------------|---------------|
| ✅ Native | 162 | 27% | Pattern is ingebouwd — niet handmatig implementeren |
| 🔧 Supported | 200 | 33% | Pattern is de standaard aanpak — correct gebruik |
| 🔄 Alternative | 134 | 22% | Er is een betere platform-specifieke oplossing |
| ⚠️ Overkill | 14 | 2% | Te zwaar — simplificeer |
| 🚫 N/A | 90 | 15% | Niet relevant voor dit platform |

**Kernconlusie**: **49% native + alternatief** — bijna de helft van alle pattern×platform combinaties heeft een native of alternatieve oplossing. Dit betekent dat in bijna de helft van de gevallen het expliciet implementeren van het "klassieke" pattern suboptimaal of overbodig is.

---

## 5. RTFM-Analyse per Platform

Per framework de top voorbeelden waar native features beter zijn dan handmatige pattern-implementaties.

### 5.1 Angular (10 voorbeelden)

| # | ❌ Onnodige implementatie | ✅ Native oplossing | Toelichting |
|---|--------------------------|---------------------|-------------|
| 1 | Singleton-klasse met `getInstance()` | `@Injectable({ providedIn: 'root' })` | DI garandeert single-instance, tree-shakeable |
| 2 | InversifyJS / tsyringe voor DI | Angular's hiërarchische DI | Angular's DI is volwassen en type-safe. Extra containers zijn redundant. |
| 3 | Custom EventBus/PubSub | RxJS `Subject` / `BehaviorSubject` | RxJS is een eersteklas dependency in Angular |
| 4 | Handmatige Observer | Signals (`signal()`, `computed()`, `effect()`) | Signals voor synchrone state, RxJS voor async streams |
| 5 | Redux-achtige state from scratch | NgRx SignalStore | Redux-like guarantees met signal-based reactivity |
| 6 | Middleware-chain voor HTTP | `HttpInterceptor` (functional) | `withInterceptors()` is de moderne aanpak |
| 7 | Custom form validation | Reactive Forms + `Validators` | `FormBuilder` + custom `ValidatorFn` is standaard |
| 8 | Guard Clause voor routing | `canActivate` functional guard | Route guards zijn native in Angular 15+ |
| 9 | Factory Method voor services | `useFactory` in providers | `{ provide: X, useFactory: fn, deps: [...] }` |
| 10 | Custom pipe voor data transformatie | `@Pipe` + `transform()` | Pure pipes zijn gecached en performant |

### 5.2 React (10 voorbeelden)

| # | ❌ Onnodige implementatie | ✅ Native oplossing | Toelichting |
|---|--------------------------|---------------------|-------------|
| 1 | HOC voor shared logic | Custom Hook (`useAuth`, `useFetch`) | Hooks vervangen HOCs sinds React 16.8 |
| 2 | Render Props voor data sharing | Custom Hook | Vermijdt callback hell van render props |
| 3 | MobX / custom Observer | `useState` + `useEffect` / `useSyncExternalStore` | React's eigen state volstaat voor de meeste apps |
| 4 | Context API als volledige state mgmt | Zustand / Jotai / `useReducer` | Context is voor infrequent-veranderende data |
| 5 | Handmatige memoization (WeakMap) | `useMemo`, `useCallback`, `React.memo` | React Compiler (19+) automatiseert dit verder |
| 6 | Custom data fetching + loading/error | TanStack Query / SWR / `use()` hook | Caching, dedup, revalidation out-of-the-box |
| 7 | Handmatige error handling per component | `ErrorBoundary` | `react-error-boundary` voor declaratieve boundaries |
| 8 | Prop drilling via 10+ levels | `useContext` / state management library | Context lost prop drilling op |
| 9 | Custom portal implementatie | `ReactDOM.createPortal()` | Native portals |
| 10 | Handmatige code splitting | `React.lazy()` + `Suspense` | Next.js voegt route-based splitting toe |

### 5.3 NestJS (10 voorbeelden)

| # | ❌ Onnodige implementatie | ✅ Native oplossing | Toelichting |
|---|--------------------------|---------------------|-------------|
| 1 | InversifyJS / tsyringe voor DI | NestJS native DI (`@Injectable()`) | NestJS *is* een DI-container |
| 2 | Custom middleware chain | Guards, Interceptors, Pipes, Filters | 4 lagen request-processing |
| 3 | Handmatig singleton pattern | Default provider scope is singleton | `@Injectable()` = singleton by default |
| 4 | Custom Event Bus | `@nestjs/event-emitter` + `@OnEvent()` | Native event-emitter module |
| 5 | Handmatige CQRS | `@nestjs/cqrs` module | Officieel module met commands, queries, events, sagas |
| 6 | Custom validation logic | `class-validator` + `ValidationPipe` | Decorators + globale pipe |
| 7 | Factory Method klasse | Custom providers: `useFactory`, `useValue` | Native factory pattern |
| 8 | Handmatige Swagger docs | `@nestjs/swagger` + decorators | Auto-generatie OpenAPI specs |
| 9 | Custom serialization | `ClassSerializerInterceptor` | `@Exclude()`, `@Expose()`, `@Transform()` |
| 10 | Handmatige health checks | `@nestjs/terminus` | Health check endpoints out-of-the-box |

### 5.4 FastAPI (10 voorbeelden)

| # | ❌ Onnodige implementatie | ✅ Native oplossing | Toelichting |
|---|--------------------------|---------------------|-------------|
| 1 | DI-container library | `Depends()` systeem | Function-based DI met nesting, caching, test overrides |
| 2 | Request validation middleware | Pydantic modellen als parameter types | `def endpoint(body: MyModel)` valideert automatisch |
| 3 | Handmatige OpenAPI docs | Automatisch gegenereerd op `/docs` | OpenAPI 3.1 + Swagger UI + ReDoc |
| 4 | Custom serialization | Pydantic `model_dump()` / `response_model` | `model_config = ConfigDict(from_attributes=True)` voor ORMs |
| 5 | Handmatige CORS setup | `CORSMiddleware` | Eén regel: `app.add_middleware(CORSMiddleware, ...)` |
| 6 | Custom error handling | `HTTPException` + `@app.exception_handler()` | Declaratief exception handling |
| 7 | Custom background job systeem | `BackgroundTasks` | Fire-and-forget taken native |
| 8 | Custom OAuth2 | `OAuth2PasswordBearer` + `Depends()` | Auth dependency chain |
| 9 | Middleware chain pattern | `@app.middleware("http")` + Starlette | ASGI middleware stack |
| 10 | Builder voor configuratie | Pydantic `BaseSettings` | Auto-load uit env vars, .env, secrets |

### 5.5 Spring Boot (10 voorbeelden)

| # | ❌ Onnodige implementatie | ✅ Native oplossing | Toelichting |
|---|--------------------------|---------------------|-------------|
| 1 | Handmatige Singleton | Default scope is singleton | `@Service`/`@Component` = singleton by default |
| 2 | Service Locator pattern | `@Autowired` / constructor injection | Service Locator is anti-pattern in Spring |
| 3 | Handmatige Repository | Spring Data JPA `JpaRepository<T, ID>` | Genereert findAll, save, delete, findBy* |
| 4 | Factory klassen | `@Bean` in `@Configuration` | Native factory |
| 5 | Custom AOP voor logging | Spring AOP `@Aspect` + `@Around` | Declaratief cross-cutting |
| 6 | Handmatig event systeem | `ApplicationEventPublisher` + `@EventListener` | Native Observer |
| 7 | Custom health checks | Spring Actuator `/actuator/health` | Eén config regel |
| 8 | Handmatige config loading | `@ConfigurationProperties` + `application.yml` | Type-safe config binding |
| 9 | Custom retry logic | Spring Retry `@Retryable` | Declaratieve retries met backoff |
| 10 | Handmatige caching | `@Cacheable` / `@CacheEvict` | Supports Redis, Caffeine, EhCache |

### 5.6 Django (10 voorbeelden)

| # | ❌ Onnodige implementatie | ✅ Native oplossing | Toelichting |
|---|--------------------------|---------------------|-------------|
| 1 | Repository pattern | `Model.objects` Manager | Manager *is* het repository. Custom managers voor queries. |
| 2 | Custom form validation | Django Forms + ModelForm | `form.is_valid()` valideert alles |
| 3 | Handmatige CRUD admin | `admin.site.register(Model)` | Django Admin is een volledige CRUD interface |
| 4 | Custom auth systeem | `django.contrib.auth` | User, backends, permissions, groups ingebouwd |
| 5 | Custom migration tool | Django migrations | `makemigrations` + `migrate` automatisch |
| 6 | Handmatige serialization | DRF serializers (`ModelSerializer`) | Automatisch: serialisatie, validatie, nested relations |
| 7 | Observer pattern | Django signals (`post_save`, `pre_delete`) | `@receiver(post_save, sender=User)` |
| 8 | Custom middleware stack | `MIDDLEWARE` setting | SecurityMiddleware, Session, CSRF standaard |
| 9 | Template Method voor views | Class-Based Views (CBV) | `ListView`, `DetailView`, `CreateView` etc. |
| 10 | Custom caching | Django cache framework | `@cache_page(60 * 15)`, supports Memcached/Redis |

### 5.7 Rails (10 voorbeelden)

| # | ❌ Onnodige implementatie | ✅ Native oplossing | Toelichting |
|---|--------------------------|---------------------|-------------|
| 1 | Repository pattern | ActiveRecord scopes + associations | Model methods *zijn* het repository |
| 2 | Service Locator | Rails autoloading + convention | `app/services/`, `app/models/` — automatisch geladen |
| 3 | Custom validation | ActiveRecord validations | `validates :email, presence: true, format: {...}` |
| 4 | Custom background jobs | Active Job + Sidekiq/Resque | `perform_later` voor async jobs |
| 5 | Observer handmatig | Callbacks + Active Support Notifications | `before_save`, `after_create`, `Notifications.subscribe` |
| 6 | Custom WebSocket | Action Cable | Native WebSocket channels |
| 7 | Handmatige mailer | Action Mailer | `UserMailer.welcome_email(@user).deliver_later` |
| 8 | Custom CSRF protection | Rails CSRF middleware | Standaard: `protect_from_forgery` |
| 9 | Handmatige asset pipeline | Importmap / Propshaft | Rails 7+ — geen bundler nodig |
| 10 | Custom SPA-interactiviteit | Hotwire (Turbo + Stimulus) | Geen React/Vue nodig voor de meeste interactiviteit |

---

## 6. SOLID: Wanneer Wel, Wanneer Niet

### 6.1 Per principe, per platform

| Principe | TypeScript | Python | C++ | Java |
|----------|-----------|--------|-----|------|
| **SRP** | 🔧 ES modules faciliteren kleine bestanden. Risico: barrel files. | 🔧 Modules + packages. Risico: `utils.py` god-module. | 🔧 Header/source scheiding helpt. Risico: mega-headers. | 🔧 Klasse-per-bestand. Risico: enterprise-god-services. |
| **OCP** | 🔧 Union types + generics > overerving. Discriminated unions > class hiërarchieën. | 🔧 Duck typing + Protocol. `@singledispatch` voor overloading. | 🔧 Templates + virtual methods. Concepts (C++20). | 🔧 Interfaces + abstract classes. Sealed classes (17+). |
| **LSP** | ⚠️ Structural typing maakt schendingen moeilijk te detecteren. | ⚠️ Duck typing = geen compile-time check. Protocol helpt, maar is optioneel. | 🔧 Strikte type-checking. Virtual destructors nodig. | 🔧 Strikte nominale types. `@Override` helpt. |
| **ISP** | ✅ `Pick`, `Omit`, `Partial` maken ISP triviaal. Interfaces zijn structureel. | 🔄 Protocol (typing) is modern. ABC's zijn de oude manier. | 🔧 Multiple inheritance. Concepts (C++20). | 🔧 Interfaces met default methods (8+). |
| **DIP** | 🔧 Geen native DI. Handmatig of tsyringe/InversifyJS. | 🔧 Geen native DI (behalve FastAPI Depends). | 🔧 Geen native DI. Templates bieden abstractie. | ✅ Spring/Guice/CDI. Annotations = declaratief. |

### 6.2 Kernobservaties

**SRP** — Universeel waardevol, maar de *granulariteit* verschilt:

- TypeScript/JS: één functie per module is prima, klassen zijn optioneel
- Java: één klasse per bestand is conventie, maar leidt tot explosion-of-classes
- Go: package-level organisatie, geen klassen
- Python: module-level is de eenheid, niet de klasse

**OCP** — Implementatie verschilt radicaal:

- In TypeScript: discriminated unions + mapped types > overerving
- In Java: interfaces + DI > abstract klassen
- In Rust: traits + generics > class hiërarchieën
- In Go: implicit interfaces > explicit implementation

**LSP** — Moeilijk te handhaven in dynamic talen:

- TypeScript's structural typing maakt LSP-schendingen *onzichtbaar*
- Python's duck typing maakt LSP oncontroleerbaar at compile time
- Rust's trait system garandeert LSP door het type systeem
- Java's nominale types + `@Override` geven compile-time feedback

**ISP** — TypeScript wint:

- `Pick<User, 'name' | 'email'>` is ISP in één regel
- Java heeft nog steeds het "fat interface" probleem ondanks default methods
- Go's implicit interfaces zijn ISP by design

**DIP** — Framework-afhankelijk:

- Java met Spring/Guice: DIP is volledig declaratief
- TypeScript zonder framework: handmatige constructor injection
- Python met FastAPI: `Depends()` is function-based DI
- Angular/NestJS: framework *is* de DI-container

### 6.3 Wanneer SOLID NIET toepassen

| Situatie | Waarom niet | Beter |
|----------|-------------|-------|
| Script < 100 regels | SRP-klassen voegen complexiteit toe | Eén bestand, procedureel |
| Prototype / hackathon | OCP-abstracties vertragen development | Direct naar de oplossing |
| Simpele CRUD-app | Clean Architecture lagen zijn overkill | Rails/Django scaffolding |
| Functionele codebase | OOP-principes passen niet | Composition, pure functions |
| Configuration/glue code | ISP voor config-types is overhead | Eén config-interface |

---

## 7. Annotaties, DI en Framework Magic

### 7.1 DI-vergelijking per framework

| Aspect | Angular | NestJS | Spring Boot | FastAPI | React | Vue |
|--------|---------|--------|-------------|---------|-------|-----|
| **DI type** | Hierarchical IoC | Module-scoped IoC | Annotation-based IoC | Function-based | Geen native DI | Geen native DI |
| **Registratie** | `@Injectable()` + `providedIn` | `@Injectable()` + module providers | `@Component/@Service` + scan | `Depends()` parameter | N.v.t. | N.v.t. |
| **Scopes** | Singleton, component, element | Singleton, request, transient | Singleton, prototype, request, session | Per-request (default) | N.v.t. | N.v.t. |
| **Singleton** | ✅ `providedIn: 'root'` | ✅ Default scope | ✅ Default scope | 🔄 Module-scope | 🔄 Module-scope variable | 🔄 Module-scope variable |
| **Testing** | ✅ `TestBed.inject()` | ✅ Test module + overrides | ✅ `@MockBean` | ✅ `Depends()` override | 🔧 Props/Context mock | 🔧 provide/inject mock |

### 7.2 Wanneer manual DI beter is

| Situatie | Waarom manual DI | Hoe |
|----------|-----------------|-----|
| Express-app zonder framework | Geen DI-container beschikbaar | Constructor injection + composition root |
| Go-project | Geen annotaties, expliciet is idiomatisch | `func NewService(repo Repo) *Service` — Wire of Fx optioneel |
| Kleine TypeScript CLI-tool | DI-container is overkill | Gewoon parameters doorgeven |
| Library/SDK | Geen runtime-dependency op DI-framework | Factory functions + configuration objects |
| Performance-kritische code | DI-container overhead niet acceptabel | Direct instantiëren, compile-time DI (Wire, Dagger) |

### 7.3 Decorator/annotation patterns per ecosysteem

| Ecosysteem | Mechanisme | Voorbeelden |
|------------|-----------|-------------|
| **Java/Spring** | Annotations + reflection + proxies | `@Service`, `@Autowired`, `@Transactional`, `@Cacheable`, `@Retryable` |
| **TypeScript/Angular** | Decorators + metadata reflection | `@Component`, `@Injectable`, `@Input`, `@Output`, `@Pipe` |
| **TypeScript/NestJS** | Decorators + metadata reflection | `@Controller`, `@Get`, `@Body`, `@UseGuards`, `@ApiProperty` |
| **Python/FastAPI** | Decorators (function-level) | `@app.get()`, `@app.middleware()`, Pydantic validators |
| **Python/Django** | Decorators (function-level) | `@login_required`, `@cache_page`, `@receiver`, `@admin.register` |
| **C#/ASP.NET** | Attributes + reflection | `[Authorize]`, `[HttpGet]`, `[FromBody]`, `[Required]`, `[ApiController]` |
| **Kotlin** | Annotations (Java-compatible) | `@SpringBootApplication`, `@GetMapping`, + Kotlin-specifiek: `by` delegation |
| **Rust** | Derive macros + proc macros | `#[derive(Debug, Serialize)]`, `#[tokio::main]`, `#[test]` |

### 7.4 Anti-pattern: DI-container in DI-framework

De volgende combinaties zijn **altijd fout**:

| ❌ Doe dit niet | ✅ Doe dit |
|-----------------|-----------|
| InversifyJS in Angular | Gebruik Angular DI |
| tsyringe in NestJS | Gebruik NestJS DI |
| Guice in Spring Boot | Gebruik Spring DI |
| dependency-injector in FastAPI | Gebruik `Depends()` |
| Autofac in ASP.NET Core (voor basics) | Gebruik `IServiceCollection` |

---

## 8. Anti-Patterns: Wanneer Patterns Schaden

### 8.1 Over-engineering voorbeelden

| Anti-pattern | Symptoom | Beter |
|-------------|----------|-------|
| **Abstract Factory voor 1 variant** | `ThemeFactory` → `DarkThemeFactory` → `DarkTheme`. Maar er is maar 1 thema. | `new DarkTheme()` of config object |
| **Strategy voor 1 algoritme** | `SortStrategy` interface met alleen `QuickSortStrategy`. | Gewoon de functie aanroepen |
| **Observer voor 2 components** | Custom `EventBus` met `subscribe()`/`publish()` voor communicatie tussen 2 sibling components | Props/callbacks of `@Output()` event |
| **Repository boven ActiveRecord** | `UserRepository` die alleen `User.findAll()` doorgeeft aan `User.objects.all()` | Gebruik de ORM direct |
| **Builder voor 3 velden** | `UserBuilder().setName("x").setEmail("y").build()` | `new User({ name: "x", email: "y" })` |
| **Command voor elke knop-klik** | `ClickButtonCommand`, `SaveFormCommand` voor simpele event handlers | Event handler functie |
| **Clean Architecture voor TODO-app** | 6 lagen, 20 bestanden, dependency inversion voor een CRUD-app | Rails scaffold / Django ModelForm |
| **CQRS voor blog** | Aparte read/write modellen voor een blog met 10 bezoekers per dag | Gewoon CRUD |
| **Microservices voor MVP** | 5 services, Kafka, Kubernetes voor een product dat nog geen product-market fit heeft | Modular monolith |
| **DDD voor config CRUD** | Aggregates, Value Objects, Domain Events voor settings-beheer | Simple CRUD module |

### 8.2 Pattern-obsession code smells

| Code smell | Detectie | Oorzaak |
|-----------|----------|---------|
| Meer interfaces dan implementaties | `interface Foo` + `class FooImpl` × 50 | Over-abstractie. Eén implementatie = geen interface nodig. |
| Factory die altijd hetzelfde teruggeeft | `create()` retourneert altijd `ConcreteA` | Geen polymorfisme → geen factory nodig |
| Singleton met alleen stateless methoden | `Singleton.getInstance().format(x)` | Module-level functie volstaat |
| 3+ niveaus van wrapping | `LoggingDecorator(CachingDecorator(AuthDecorator(Service)))` | Middleware-pipeline of AOP |
| God-abstraction | `IService<T>` met 20 methoden | ISP schending — splits op |
| Empty method in abstract class | `@Override void onClose() { /* noop */ }` | ISP schending — interface is te breed |

### 8.3 Wanneer een simpele functie beter is

```text
Vuistregel: als je pattern-implementatie meer code is dan het probleem dat het oplost,
gebruik dan een functie.
```

| Situatie | Pattern-versie | Functie-versie |
|----------|---------------|----------------|
| Eenmalige berekening | `CalculationStrategy` interface + implementatie | `function calculate(input): result` |
| Data transformatie | `TransformerPipeline` met `ITransformer` chain | `pipe(trim, validate, normalize)(input)` |
| Conditionele logica | `State` pattern met 3 klassen | `switch(state)` of `match` expression |
| Event handling | `Command` object + `CommandHandler` | `onClick={() => doThing()}` |
| Type conversie | `Adapter` klasse | `function toApiFormat(internal): external` |

---

## 9. Decision Framework

### 9.1 Beslisboom: Pattern vs Native vs Simpel

```text
Heb je een probleem?
├── Nee → Geen pattern nodig. YAGNI.
└── Ja → Biedt je platform/framework een native oplossing?
    ├── Ja → RTFM. Gebruik de native oplossing.
    │   └── Is de native oplossing voldoende?
    │       ├── Ja → Klaar. ✅
    │       └── Nee → Extend de native oplossing (niet vervangen).
    └── Nee → Biedt je taal een idiomatische oplossing?
        ├── Ja → Gebruik het taal-idioom.
        │   Voorbeelden:
        │   - Singleton → module-scope (JS/Python/Go)
        │   - Builder → named args (Kotlin/Python/PHP)
        │   - Visitor → pattern matching (Rust/Kotlin/C#)
        │   - Iterator → generators/streams
        │   - Observer → channels (Go) / events (C#)
        └── Nee → Is het probleem complex genoeg voor een pattern?
            ├── < 50 regels code → Simpele functie/module
            ├── 50-500 regels, 1 variant → Licht pattern (geen interface)
            └── > 500 regels of meerdere varianten → Volledig pattern
```

### 9.2 Per situatie

| Situatie | Keuze | Reden |
|----------|-------|-------|
| CRUD-app met Rails/Django/Laravel | Framework conventions | Het framework *is* het architecture pattern |
| Angular/NestJS service nodig | DI-registratie | `@Injectable()` — het framework is de factory + singleton |
| React component met shared state | Hooks + Context of Zustand | Geen DI-container, geen class-based patterns |
| Go HTTP service | Explicit interfaces + constructor functions | Go idioom: explicit > magic |
| Rust error handling | `Result<T, E>` + `?` operator | Taal-native — geen custom Result type bouwen |
| Java enterprise service | Spring Boot + DI + JPA | Het framework biedt DI, AOP, Repository, Config |
| Cross-service communicatie | Circuit Breaker + Retry | Resilience patterns zijn altijd nodig bij netwerk |
| Legacy integratie | Anti-Corruption Layer + Adapter | Isoleer de rotzooi |
| Complex domein | DDD + Hexagonal (selectief) | Alleen voor de complexe bounded contexts |
| Startup MVP | Modular Monolith | Geen microservices, geen CQRS, geen event sourcing |

---

## 10. Conclusies & Aanbevelingen

### 10.1 Top 10 regels

1. **RTFM eerst** — Lees de documentatie van je framework voordat je een pattern implementeert. 49% van de pattern×platform combinaties heeft een native of alternatieve oplossing.

2. **Het framework IS het pattern** — Angular is DI + Observer + MVVM. Rails is Active Record + MVC + Convention over Configuration. Spring is DI + AOP + Repository. Implementeer niet wat het framework al biedt.

3. **Module-scope = Singleton** — In TypeScript, Python, Go, Ruby, en PHP zijn modules singletons by design. `getInstance()` is een code smell in deze talen.

4. **Taal-idioom > Academisch pattern** — Kotlin's `data class` > Builder. Rust's `enum` + `match` > Visitor. TypeScript's `Pick`/`Omit` > ISP-interfaces. Go's `channels` > Observer.

5. **Complexiteit moet verdiend worden** — Begin simpel. Voeg abstractie toe wanneer het probleem zich bewijst, niet op voorhand. YAGNI is sterker dan OCP.

6. **DI-container alleen als het framework het biedt** — InversifyJS in Angular is een anti-pattern. `Depends()` in FastAPI is genoeg. Guice naast Spring is nonsens.

7. **Onderschatte patterns verdienen meer aandacht** — State machines, Circuit Breakers, Guard Clauses, Result types, Value Objects, Idempotent Receivers — deze worden te weinig gebruikt en voorkomen echte bugs.

8. **Active Record vs Data Mapper is geen keuze** — Het framework kiest voor je. Rails/Laravel/Django = Active Record. Hibernate/EF/TypeORM = Data Mapper. Niet vechten.

9. **Signals zijn de toekomst van UI-state** — Angular, Svelte, Solid, en Vue bewegen allemaal richting fine-grained reactivity. Redux-achtige patterns worden lichter of overbodig.

10. **Eén implementatie = geen interface nodig** — `IUserService` + `UserServiceImpl` zonder tweede implementatie is cargo cult. Interface pas toevoegen wanneer je daadwerkelijk polymorfisme nodig hebt.

### 10.2 Relatie tot cpm checks

Dit onderzoek heeft directe implicaties voor cpm's rule engine:

#### Platform-aware rule suppression

| cpm-regel | Zonder context | Met platformcontext |
|-----------|---------------|---------------------|
| "Missing DI pattern" | ⚠️ Warning altijd | ✅ Suppress in Angular/NestJS/Spring (native DI) |
| "Singleton anti-pattern" | ⚠️ Warning altijd | ✅ Suppress als `@Injectable()` of `@Service` (DI-managed) |
| "Missing Observer pattern" | ⚠️ Warning altijd | ✅ Suppress in Angular (RxJS), Vue (reactivity), Svelte (runes) |
| "No state management" | ⚠️ Warning altijd | 🔧 Check of framework signals/stores aanwezig zijn |
| "Active Record anti-pattern" | ⚠️ Warning altijd | ✅ Suppress in Rails/Laravel/Django (het *is* het framework) |
| "Missing Repository pattern" | ⚠️ Warning altijd | ✅ Suppress als Spring Data / Prisma / Eloquent aanwezig |

#### Platform detection priorities

Voor cpm-regelafstelling, detecteer in deze volgorde:

1. **Framework** (Angular, NestJS, Spring, Django, Rails, Laravel, FastAPI) — bepaalt welke patterns native zijn
2. **Taal** (TypeScript, Python, Java, Go, Rust, C#) — bepaalt welke taalfeatures patterns vervangen
3. **ORM** (Prisma, Hibernate, Eloquent, ActiveRecord, TypeORM) — bepaalt data-pattern aanbevelingen
4. **State management** (Redux, NgRx, Pinia, Zustand, signals) — bepaalt state-pattern aanbevelingen

#### Aanbevolen nieuwe cpm rules

| Rule ID | Type | Beschrijving |
|---------|------|-------------|
| `PATTERN-001` | `pattern` | Detect handmatige Singleton (`getInstance`) in module-based talen |
| `PATTERN-002` | `pattern` | Detect DI-container library import in framework met native DI |
| `PATTERN-003` | `pattern` | Detect `IFoo` + `FooImpl` zonder tweede implementatie |
| `PATTERN-004` | `absence` | Missing error handling pattern (no Result/Either, no try-catch) |
| `PATTERN-005` | `pattern` | Detect handmatige Observer in framework met reactive primitieven |
| `PATTERN-006` | `absence` | Missing Circuit Breaker bij externe service calls |
| `PATTERN-007` | `pattern` | Repository wrapper om ORM dat al repository biedt |
| `PATTERN-008` | `pattern` | Builder pattern voor klasse met < 4 velden |
| `PATTERN-009` | `pattern` | Abstract Factory met slechts 1 concrete factory |
| `PATTERN-010` | `pattern` | Strategy interface met slechts 1 implementatie |

---

## Appendix A: Volledige Pattern Catalogus

137 patterns in 15 categorieën. Zie [R-030-patterns-catalog.md](R-030-patterns-catalog.md) voor de volledige catalogus met beschrijvingen en kernproblemen.

### A.1 GoF Creational (5)

Singleton, Factory Method, Abstract Factory, Builder, Prototype

### A.2 GoF Structural (7)

Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy

### A.3 GoF Behavioral (11)

Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor, Interpreter

### A.4 SOLID Principles (5)

SRP, OCP, LSP, ISP, DIP

### A.5 Enterprise / Integration (17)

Repository, Unit of Work, CQRS, Event Sourcing, Saga, Circuit Breaker, Retry, Bulkhead, Service Locator, Gateway, Message Broker, Publish-Subscribe, Outbox, Dead Letter Queue, Strangler Fig, Transactional Outbox, Idempotent Receiver

### A.6 Concurrency (12)

Active Object, Monitor, Producer-Consumer, Thread Pool, Future/Promise, Actor Model, Read-Write Lock, Semaphore, Barrier, Fork-Join, Scheduler, Double-Checked Locking

### A.7 Functional (12)

Monad, Functor, Applicative, Lens, Pipe/Compose, Currying, Memoization, Either/Result, Option/Maybe, ADT, Church Encoding, Free Monad

### A.8 Architecture (13)

MVC, MVP, MVVM, Clean Architecture, Hexagonal/Ports & Adapters, Onion Architecture, Layered Architecture, Microkernel/Plugin, Event-Driven Architecture, Space-Based Architecture, Serverless, Service Mesh, Modular Monolith

### A.9 State Management (7)

Flux, Redux, State Machine, Finite Automaton, Store Pattern, Event Store, Snapshot

### A.10 Data (10)

Active Record, Data Mapper, Table Data Gateway, Row Data Gateway, Identity Map, Lazy Load, Eager Load, DTO, Value Object, Specification

### A.11 UI / Frontend (9)

Container/Presentational, Compound Component, Render Props, HOC, Hooks Pattern, Atomic Design, Micro-Frontend, Island Architecture, Slot Pattern

### A.12 API / Communication (8)

REST, GraphQL, RPC, BFF, API Gateway, Anti-Corruption Layer, API Versioning, HATEOAS

### A.13 Testing (8)

AAA, Given-When-Then, Mock Object, Test Double, Fixture, Page Object, Object Mother, Builder (Test)

### A.14 Security (6)

Null Object, Guard Clause, Sanitization Pipeline, Input Validation Gateway, Secure Token, Capability-Based Security

### A.15 Meta / Cross-Cutting (7)

DI, IoC, Plugin, Module, Interceptor, Middleware, Decorator (Framework-level)

---

## Appendix B: Volledige Platform Catalogus

130 platforms in 12 categorieën. Zie [R-030-platforms-catalog.md](R-030-platforms-catalog.md) voor de volledige catalogus met native pattern-vervangers per platform.

### B.1 Programmeertalen (22)

TypeScript, JavaScript, Python, C++, C#, Java, Go, Rust, Ruby, PHP, Swift, Kotlin, Dart, Scala, Elixir, Haskell, Clojure, Lua, R, Zig, OCaml, V

### B.2 Frontend Frameworks (12)

Angular, React, Vue, Svelte, Solid.js, Qwik, Lit, Alpine.js, Htmx, Ember, Preact, Stencil

### B.3 Meta-Frameworks (8)

Next.js, Nuxt, SvelteKit, Remix, Astro, Analog, Fresh, Gatsby

### B.4 Backend Frameworks (17)

NestJS, FastAPI, Express, Django, Flask, Spring Boot, ASP.NET Core, Rails, Laravel, Phoenix, Gin, Actix Web, Fastify, Hono, Fiber, Koa, Chi

### B.5 State Management (11)

NgRx, Redux/RTK, Zustand, Pinia, MobX, Recoil, Jotai, XState, Signals, Akita, Effector

### B.6 Data/Query Libraries (10)

TanStack Query, TanStack Table, SWR, Apollo Client, tRPC, Prisma, TypeORM, Sequelize, SQLAlchemy, Drizzle

### B.7 ORM/Database (7)

Hibernate, EF Core, Eloquent, ActiveRecord, Mongoose, GORM, Diesel

### B.8 Testing (10)

Jest, Vitest, Pytest, JUnit 5, xUnit, Cypress, Playwright, Testing Library, Mocha, NUnit

### B.9 Build/Tooling (9)

Webpack, Vite, esbuild, Turbopack, Nx, Turborepo, Rollup, SWC, Biome

### B.10 Runtime/Infra (7)

Node.js, Deno, Bun, Docker, Kubernetes, Podman, Terraform

### B.11 Mobile (5)

Flutter, React Native, SwiftUI, Jetpack Compose, Kotlin Multiplatform

### B.12 Annotation/DI Frameworks (12)

Spring DI, .NET DI, Angular DI, NestJS DI, Dagger/Hilt, InversifyJS, Guice, Autofac, Koin, tsyringe, Wire, Fx

---

## Appendix C: Volledige Matrix

De volledige 20×30 matrix met alle classificaties. Zie [R-030-matrix-analysis.md](R-030-matrix-analysis.md) voor de complete matrix inclusief:

- 4 deelmatrices (Talen, Frontend, Backend+Meta, Overige)
- Per-categorie analyses (8 categorieën)
- 7 deep-dives (SOLID, DI, State Management, ORM, Observer, Factory, Singleton)
- 70 concrete RTFM-voorbeelden (7 frameworks × 10 voorbeelden)
- cpm-aanbevelingen (rule suppression, platform detection, overschatte/onderschatte patterns)

### Matrixtotalen

| Metriek | Waarde |
|---------|--------|
| Patterns in matrix | 20 |
| Platforms in matrix | 30 |
| Totaal combinaties | 600 |
| Native (✅) | 162 (27%) |
| Supported (🔧) | 200 (33%) |
| Alternative (🔄) | 134 (22%) |
| Overkill (⚠️) | 14 (2%) |
| N/A (🚫) | 90 (15%) |
| **Native + Alternative** | **296 (49%)** |

---

*Dit document is gegenereerd als onderdeel van het cpm research-programma. De tussenresultaten (R-030-patterns-catalog.md, R-030-platforms-catalog.md, R-030-matrix-analysis.md) zijn beschikbaar als referentie.*
