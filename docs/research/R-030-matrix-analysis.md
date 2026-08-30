# R-030: Pattern × Platform Matrix Analyse (Tussenresultaat)

**Date:** 2026-08-30
**Status:** Tussenresultaat (Fase 3/5)

## Samenvatting

Dit document bevat de kernanalyse van 137 design patterns tegen 130 platforms, gefocust op een 20×30 matrix van de meest gebruikte combinaties. Daarnaast bevat het uitgebreide per-categorie analyses, specifieke deep-dives (SOLID, DI, State Management, ORM, Observer, Factory, Singleton) en een uitgebreide 'RTFM'-sectie voor 7 populaire frameworks.

**Doel**: cpm-regels afstemmen op platformcontext, zodat findings relevant zijn en developers niet gewaarschuwd worden voor iets dat hun framework al oplost.

---

## Deel 1: De 20×30 Matrix

### Selectiecriteria

**Top 20 patterns** (geselecteerd op universaliteit en frequentie in codebases):

| # | Pattern | Bron |
|---|---------|------|
| P1 | Singleton | GoF Creational |
| P2 | Factory Method | GoF Creational |
| P3 | Builder | GoF Creational |
| P4 | Adapter | GoF Structural |
| P5 | Decorator | GoF Structural |
| P6 | Observer | GoF Behavioral |
| P7 | Strategy | GoF Behavioral |
| P8 | Iterator | GoF Behavioral |
| P9 | Template Method | GoF Behavioral |
| P10 | Command | GoF Behavioral |
| P11 | State | GoF Behavioral |
| P12 | Dependency Injection | Meta / Cross-Cutting |
| P13 | Repository | Enterprise |
| P14 | Middleware | Meta / Cross-Cutting |
| P15 | MVC/MVVM | Architecture |
| P16 | Pub-Sub / Event-Driven | Enterprise |
| P17 | Circuit Breaker | Enterprise |
| P18 | Active Record / Data Mapper | Data |
| P19 | Redux/Flux (unidirectional flow) | State Management |
| P20 | Guard Clause / Input Validation | Security |

**Top 30 platforms** (geselecteerd op marktaandeel en diversiteit):

| # | Platform | Type |
|---|----------|------|
| L1 | TypeScript | Taal |
| L2 | Python | Taal |
| L3 | Java | Taal |
| L4 | C++ | Taal |
| L5 | Go | Taal |
| L6 | Rust | Taal |
| L7 | C# | Taal |
| L8 | Kotlin | Taal |
| L9 | Ruby | Taal |
| L10 | PHP | Taal |
| L11 | Angular | Frontend |
| L12 | React | Frontend |
| L13 | Vue | Frontend |
| L14 | Svelte | Frontend |
| L15 | Next.js | Meta-framework |
| L16 | NestJS | Backend |
| L17 | Express | Backend |
| L18 | FastAPI | Backend |
| L19 | Spring Boot | Backend |
| L20 | Django | Backend |
| L21 | Rails | Backend |
| L22 | Laravel | Backend |
| L23 | ASP.NET Core | Backend |
| L24 | Redux/RTK | State Mgmt |
| L25 | Node.js | Runtime |
| L26 | Docker | Infra |
| L27 | Flutter | Mobile |
| L28 | React Native | Mobile |
| L29 | Prisma | ORM |
| L30 | Hibernate | ORM |

### Legenda

| Symbool | Betekenis |
|---------|-----------|
| ✅ | **native** — Platform heeft dit ingebouwd, pattern is overbodig |
| 🔧 | **supported** — Pattern past goed bij het platform en is de standaard aanpak |
| ⚠️ | **overkill** — Pattern bestaat maar is te zwaar voor dit platform/use-case |
| 🚫 | **not-applicable** — Pattern is niet relevant voor dit platform |
| 🔄 | **alternative** — Er is een betere platform-specifieke oplossing (zie toelichting) |

---

### Matrix: Talen (L1-L10)

| Pattern | L1 TypeScript | L2 Python | L3 Java | L4 C++ | L5 Go | L6 Rust | L7 C# | L8 Kotlin | L9 Ruby | L10 PHP |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **P1 Singleton** | 🔄 module | 🔄 module | 🔧 | 🔧 | 🔄 pkg-var | 🔄 module | 🔧 | 🔄 object | 🔄 module | 🔧 |
| **P2 Factory Method** | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 companion | 🔧 | 🔧 |
| **P3 Builder** | 🔄 spread/Partial | 🔄 dataclass/kwargs | 🔧 | 🔧 | 🔄 functional opts | 🔧 | 🔄 records | 🔄 data class+DSL | 🔄 hash opts | 🔄 named args |
| **P4 Adapter** | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 implicit iface | 🔄 trait impl | 🔧 | 🔄 extension fn | 🔄 open class | 🔧 |
| **P5 Decorator** | 🔄 TS decorators | 🔄 @decorators | 🔄 annotations | 🔧 | 🔄 embedding | 🔄 trait+newtype | 🔄 extension methods | 🔄 `by` delegation | 🔄 mixins | 🔄 traits/attrs |
| **P6 Observer** | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 channels | 🔧 | ✅ events+delegates | 🔄 Flow/coroutines | 🔧 | 🔧 |
| **P7 Strategy** | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 blocks/procs | 🔄 match expr |
| **P8 Iterator** | ✅ iterators/generators | ✅ generators | ✅ streams | 🔄 ranges(C++20) | ✅ range/for | ✅ Iterator trait | ✅ LINQ/IEnumerable | ✅ sequences | ✅ Enumerable | ✅ generators |
| **P9 Template Method** | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 iface+embed | 🔄 trait defaults | 🔧 | 🔧 | 🔧 | 🔧 |
| **P10 Command** | 🔧 | 🔧 | 🔧 | 🔧 | 🔄 func-als-waarde | 🔧 | 🔧 | 🔄 lambdas | 🔄 blocks | 🔧 |
| **P11 State** | 🔄 unions+switch | 🔄 match stmt | 🔄 sealed classes | 🔧 | 🔧 | ✅ enum+match | 🔄 pattern match | 🔄 sealed+when | 🔧 | 🔄 match+enums |
| **P12 DI** | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P13 Repository** | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P14 Middleware** | 🔧 | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P15 MVC/MVVM** | 🔧 | 🔧 | 🔧 | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P16 Pub-Sub** | 🔧 | 🔧 | 🔧 | 🔧 | ✅ goroutines+channels | 🔧 | ✅ events | 🔄 Flow | 🔧 | 🔧 |
| **P17 Circuit Breaker** | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P18 Active Record** | 🔧 | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P19 Redux/Flux** | 🔧 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |
| **P20 Guard Clause** | 🔧 | 🔧 | 🔧 | 🔧 | ✅ error-als-waarde | ✅ Result/Option+? | 🔧 | 🔧 | 🔧 | 🔧 |

---

### Matrix: Frontend Frameworks (L11-L14)

| Pattern | L11 Angular | L12 React | L13 Vue | L14 Svelte |
|---------|:---:|:---:|:---:|:---:|
| **P1 Singleton** | ✅ providedIn:'root' | 🔄 module scope | 🔄 module scope | 🔄 module scope |
| **P2 Factory Method** | ✅ useFactory | 🔄 custom hooks | 🔄 composables | ⚠️ overbodig |
| **P3 Builder** | ✅ FormBuilder | 🔄 config objects | 🔄 composition API | ⚠️ overbodig |
| **P4 Adapter** | 🔧 pipes/services | 🔧 hooks/wrappers | 🔧 composables | 🔧 |
| **P5 Decorator** | ✅ @Component/@Injectable | 🔄 HOC→hooks | ⚠️ compositie beter | ⚠️ overbodig |
| **P6 Observer** | ✅ RxJS+signals | 🔄 useEffect/state | ✅ reactivity system | ✅ runes ($state/$derived) |
| **P7 Strategy** | 🔧 DI-gebaseerd | 🔧 props/callbacks | 🔧 props/events | 🔧 props |
| **P8 Iterator** | ✅ @for / async pipe | ✅ .map() in JSX | ✅ v-for | ✅ {#each} |
| **P9 Template Method** | ✅ lifecycle hooks | ✅ hooks pattern | ✅ lifecycle hooks | ✅ lifecycle ($effect) |
| **P10 Command** | 🔧 via CQRS/actions | 🔧 dispatch/callbacks | 🔧 emit/events | 🔧 events |
| **P11 State** | 🔄 signals+services | 🔄 useReducer+XState | 🔧 reactive state | 🔄 runes |
| **P12 DI** | ✅ hierarchical DI | 🔄 Context API | 🔄 provide/inject | 🚫 niet nodig |
| **P13 Repository** | 🔧 services+HttpClient | ⚠️ client-side irrelevant | ⚠️ client-side irrelevant | ⚠️ client-side irrelevant |
| **P14 Middleware** | ✅ interceptors/guards | 🔄 niet native | 🔄 navigation guards | 🚫 |
| **P15 MVC/MVVM** | ✅ MVVM native | 🔄 component model | ✅ MVVM native | 🔄 component model |
| **P16 Pub-Sub** | ✅ RxJS subjects | 🔄 custom event bus | 🔄 mitt/tiny-emitter | 🔄 stores |
| **P17 Circuit Breaker** | 🔧 via interceptors | 🔧 via hooks | 🔧 via composables | ⚠️ overbodig |
| **P18 Active Record** | 🚫 | 🚫 | 🚫 | 🚫 |
| **P19 Redux/Flux** | 🔄 NgRx/SignalStore | 🔧 Redux/Zustand | 🔄 Pinia | 🔄 runes+stores |
| **P20 Guard Clause** | ✅ guards | 🔧 | 🔧 | 🔧 |

---

### Matrix: Meta-Frameworks & Backend (L15-L23)

| Pattern | L15 Next.js | L16 NestJS | L17 Express | L18 FastAPI | L19 Spring Boot | L20 Django | L21 Rails | L22 Laravel | L23 ASP.NET |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **P1 Singleton** | 🔄 module | ✅ default scope | 🔄 module | 🔄 module | ✅ @Scope singleton | 🔄 module | 🔄 module | ✅ service container | ✅ DI singleton |
| **P2 Factory** | 🔄 page/API routes | ✅ custom providers | 🔧 | ✅ Depends() | ✅ @Bean | 🔧 | 🔧 | ✅ service container | ✅ DI factories |
| **P3 Builder** | 🔄 config | 🔧 | 🔧 | 🔄 Pydantic | ✅ @ConfigurationProperties | 🔄 forms | 🔄 hash opts | 🔧 | 🔄 options pattern |
| **P4 Adapter** | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P5 Decorator** | 🔄 server components | ✅ @Controller etc. | 🔧 | ✅ @app.get() | ✅ @Annotation | 🔄 @decorators | 🔄 concerns | 🔧 | ✅ [Attribute] |
| **P6 Observer** | 🔧 | ✅ EventEmitter | 🔄 EventEmitter | 🔧 | ✅ @EventListener | ✅ signals | ✅ callbacks/observers | ✅ events/listeners | ✅ events |
| **P7 Strategy** | 🔧 | ✅ DI-gebaseerd | 🔧 | ✅ Depends() | ✅ DI + @Qualifier | 🔧 | 🔧 | ✅ DI-gebaseerd | ✅ DI-gebaseerd |
| **P8 Iterator** | ✅ (JS native) | ✅ (JS native) | ✅ (JS native) | ✅ (Python native) | ✅ (Java streams) | ✅ (Python native) | ✅ (Ruby enum) | ✅ (PHP generators) | ✅ (LINQ) |
| **P9 Template** | ✅ layouts/pages | ✅ lifecycle hooks | 🔧 | ✅ middleware chain | ✅ @Template patterns | ✅ CBV | ✅ controller flow | ✅ middleware | ✅ filter pipeline |
| **P10 Command** | 🔄 server actions | ✅ CQRS module | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | ✅ Artisan commands | 🔧 |
| **P11 State** | 🔄 server+client state | 🔧 | 🚫 | 🚫 | 🔧 | 🚫 | 🚫 | 🚫 | 🚫 |
| **P12 DI** | 🔄 server components | ✅ native DI | 🚫 handmatig | ✅ Depends() | ✅ @Autowired | 🔄 impliciet | 🔄 impliciet | ✅ service container | ✅ IServiceCollection |
| **P13 Repository** | 🚫 | 🔧 | 🔧 | 🔧 | ✅ Spring Data | ✅ ORM/Manager | ✅ ActiveRecord | ✅ Eloquent | ✅ EF Core |
| **P14 Middleware** | ✅ middleware.ts | ✅ interceptors/guards | ✅ app.use() | ✅ middleware | ✅ filters/interceptors | ✅ MIDDLEWARE | ✅ before_action | ✅ middleware | ✅ pipeline |
| **P15 MVC** | 🔄 App Router | ✅ MVC native | 🔄 geen view layer | 🔄 geen view layer | ✅ MVC native | ✅ MTV native | ✅ MVC native | ✅ MVC native | ✅ MVC native |
| **P16 Pub-Sub** | 🔧 | ✅ EventEmitter | 🔧 | 🔧 | ✅ @EventListener | ✅ signals | ✅ Active Support | ✅ events | ✅ MediatR/events |
| **P17 Circuit Breaker** | 🔧 | 🔧 | 🔧 | 🔧 | ✅ Resilience4j | 🔧 | 🔧 | 🔧 | ✅ Polly |
| **P18 Active Record** | 🚫 | 🔧 | 🚫 | 🔧 | 🔄 Data Mapper (JPA) | ✅ ORM native | ✅ AR native | ✅ Eloquent AR | 🔄 Data Mapper (EF) |
| **P19 Redux/Flux** | 🔧 client-side | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |
| **P20 Guard Clause** | ✅ middleware | ✅ pipes/guards | 🔧 | ✅ Pydantic validation | ✅ @Valid | ✅ form validation | ✅ validations | ✅ form requests | ✅ model validation |

---

### Matrix: Overige (L24-L30)

| Pattern | L24 Redux/RTK | L25 Node.js | L26 Docker | L27 Flutter | L28 React Native | L29 Prisma | L30 Hibernate |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **P1 Singleton** | ✅ single store | 🔄 module | 🚫 | 🔧 | 🔄 module | 🚫 | ✅ SessionFactory |
| **P2 Factory** | ✅ createSlice | 🔧 | 🚫 | 🔧 | 🔧 | ✅ Prisma Client | ✅ EntityManager |
| **P3 Builder** | ✅ createSlice/RTK Query | 🔧 | ✅ Dockerfile | 🔧 | 🔧 | ✅ query builder | ✅ Criteria API |
| **P4 Adapter** | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🔧 | 🔧 |
| **P5 Decorator** | 🔄 middleware | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | ✅ @Entity/@Column |
| **P6 Observer** | ✅ subscribe | ✅ EventEmitter | 🚫 | 🔧 | 🔧 | 🚫 | ✅ @EntityListeners |
| **P7 Strategy** | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🔧 |
| **P8 Iterator** | ✅ (JS native) | ✅ (JS native) | 🚫 | ✅ (Dart native) | ✅ (JS native) | ✅ cursor/findMany | ✅ ScrollableResults |
| **P9 Template** | 🔄 extraReducers | 🔧 | ✅ multi-stage build | 🔧 | 🔧 | 🚫 | ✅ @MappedSuperclass |
| **P10 Command** | ✅ actions | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🔧 |
| **P11 State** | ✅ reducer+actions | 🚫 | 🚫 | 🔧 | 🔧 | 🚫 | ✅ entity lifecycle |
| **P12 DI** | 🚫 | 🚫 handmatig | 🚫 | 🔧 | 🔄 Context | 🚫 | ✅ JPA/Spring DI |
| **P13 Repository** | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | ✅ Prisma Client | ✅ Spring Data |
| **P14 Middleware** | ✅ middleware | ✅ http middleware | 🚫 | 🚫 | 🚫 | ✅ middleware | ✅ filters/interceptors |
| **P15 MVC** | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🚫 |
| **P16 Pub-Sub** | ✅ subscribe | ✅ EventEmitter | 🚫 | 🔧 | 🔧 | 🚫 | ✅ listeners |
| **P17 Circuit Breaker** | 🚫 | 🔧 | 🚫 | 🔧 | 🔧 | 🚫 | 🚫 |
| **P18 Active Record** | 🚫 | 🔧 | 🚫 | 🔧 | 🚫 | 🔄 Data Mapper | 🔄 Data Mapper |
| **P19 Redux/Flux** | ✅ native | 🚫 | 🚫 | 🔄 Riverpod/BLoC | 🔧 Redux/Zustand | 🚫 | 🚫 |
| **P20 Guard Clause** | 🔧 | 🔧 | 🚫 | 🔧 | 🔧 | ✅ schema validation | ✅ @Valid/constraints |

---

### Matrixsamenvatting: Tellingen

| Symbool | Aantal | Percentage |
|---------|--------|------------|
| ✅ native | 162 | 27% |
| 🔧 supported | 200 | 33% |
| 🔄 alternative | 134 | 22% |
| ⚠️ overkill | 14 | 2% |
| 🚫 not-applicable | 90 | 15% |

**Kernconlusie**: Bijna de helft (49%) van alle pattern×platform combinaties heeft een native of alternatieve oplossing. Dit betekent dat in bijna de helft van de gevallen het expliciet implementeren van het "klassieke" pattern suboptimaal of overbodig is.

---

## Deel 2: Uitgebreide Analyse per Pattern-Categorie

### 2.1 GoF Creational Patterns

#### Universeel waardevol

- **Factory Method**: Blijft waardevol in elk OOP-ecosysteem waar polymorphe creatie nodig is. Het probleem (decoupling van creatie) verdwijnt niet met moderne talen.
- **Prototype**: Relevant bij objecten met dure initialisatie (deep clones, configuratie-objecten).

#### Overbodig gemaakt door moderne talen/frameworks

- **Singleton**: Module-systemen (ES modules, Python modules, Go packages, Kotlin `object`) bieden dezelfde garantie zonder het anti-pattern van globale mutable state. DI-containers (Angular, NestJS, Spring) maken singleton de *default scope*, waardoor het pattern als handmatige implementatie overbodig is.
- **Builder**: Named arguments (Python, Kotlin, PHP 8), data classes/records (Kotlin, Java 17, C#), spread operator + Partial<T> (TypeScript), en functional options (Go) maken het klassieke Builder-pattern in de meeste gevallen overbodig.
- **Abstract Factory**: DI-containers nemen de verantwoordelijkheid voor het samenstellen van objectfamilies over. Alleen bij complexe productfamilies (UI-toolkits met thema-varianten) nog gerechtvaardigd.

#### Alleen relevant in specifieke contexten

- **Prototype**: Game engines (object pooling), configuratie-management, GUI-editors.
- **Abstract Factory**: Cross-platform UI libraries, driver-abstracties.

#### RTFM > Pattern

| In plaats van... | Gebruik... |
|-----------------|------------|
| Singleton-klasse in TypeScript | `export const instance = new MyService()` — module-scope is singleton |
| Builder-klasse in Kotlin | `data class Config(val host: String = "localhost", val port: Int = 8080)` |
| Builder-klasse in Python | `@dataclass` met default values + `**kwargs` |
| Abstract Factory in Angular | `InjectionToken` + `useFactory` provider |
| Singleton in Spring | Default scope is al singleton — `@Service` is genoeg |

---

### 2.2 GoF Structural Patterns

#### Universeel waardevol

- **Adapter**: Onvermijdelijk bij integratie met third-party libraries of legacy-systemen. Geen taal of framework lost het probleem van incompatibele interfaces structureel op.
- **Facade**: Blijft waardevol voor het vereenvoudigen van complexe subsystemen. Frameworks bieden het vaak zelf aan (bijv. ORMs als facade over SQL).

#### Overbodig gemaakt

- **Decorator (klassiek)**: Python `@decorators`, TypeScript decorators, Kotlin `by`-delegation, C# extension methods, en middleware-patterns maken het klassieke wrapper-pattern in de meeste gevallen overbodig.
- **Proxy**: JavaScript `Proxy`/`Reflect`, Java dynamic proxies, AOP (Spring), en Python `__getattr__` bieden native proxy-functionaliteit.
- **Flyweight**: Moderne runtimes met string interning, object pooling, en efficiënte garbage collection maken handmatige flyweight-implementaties zelden nodig.

#### Alleen relevant in specifieke contexten

- **Bridge**: Alleen bij echt orthogonale variatie-assen (bijv. rendering-backend × platform).
- **Composite**: Boomstructuren (UI-componenten, bestandssystemen, expressie-bomen).

#### RTFM > Pattern

| In plaats van... | Gebruik... |
|-----------------|------------|
| Decorator-klasse in Python | `@functools.wraps`-decorator |
| Proxy-klasse in JavaScript | `new Proxy(target, handler)` |
| Decorator in Angular | `interceptors` voor HTTP, `pipes` voor data-transformatie |
| Composite in React | Component tree + `children` prop |

---

### 2.3 GoF Behavioral Patterns

#### Universeel waardevol

- **Strategy**: Blijft fundamenteel voor algoritme-uitwisseling, hoewel de implementatie verschuift van klasse-hiërarchieën naar first-class functies en lambdas.
- **Command**: Essentieel voor undo/redo, event sourcing, en task scheduling. Simplificatie via closures (JS, Python) maar het concept blijft.
- **Chain of Responsibility**: Middleware-pipelines in Express, NestJS, Django, ASP.NET zijn hiervan de moderne incarnatie.

#### Overbodig gemaakt

- **Iterator**: Volledig geabsorbeerd door talen: generators (JS/Python), streams (Java), LINQ (C#), ranges (C++20), Iterator trait (Rust), Enumerable (Ruby).
- **Observer**: Geabsorbeerd door reactive frameworks: RxJS (Angular), signals (Angular/Svelte/Solid), reactivity (Vue), delegates/events (C#), channels (Go), Flow (Kotlin).
- **Visitor**: Pattern matching in Rust, Kotlin (`when`), Scala, C# 8+, Python 3.10+ (`match`) maakt visitor overbodig voor de meeste use-cases.
- **State**: Discriminated unions + pattern matching (TypeScript, Rust, Kotlin sealed classes) en state machine libraries (XState) vervangen het klassieke State-pattern.
- **Template Method**: Hooks (React), lifecycle callbacks (Angular/Vue), behaviours (Elixir), en higher-order functies maken het klassieke overerving-gebaseerde template method overbodig.

#### Alleen relevant in specifieke contexten

- **Memento**: Alleen bij undo/redo, transaction rollback, serialisatie van game-state.
- **Interpreter**: DSL-parsing, query-engines, regels-engines (cpm's eigen rule-engine is een voorbeeld).
- **Mediator**: Complex UI-component interactie, chat-systemen, event-brokers.

---

### 2.4 Enterprise / Integration Patterns

#### Universeel waardevol

- **Repository**: Fundamenteel voor het scheiden van domein- en persistentielogica. Veel ORMs bieden dit native (Spring Data, Prisma, Eloquent).
- **Circuit Breaker**: Essentieel in distributed systems. Libraries zoals Resilience4j, Polly, Hystrix bieden dit.
- **Retry met backoff**: Universeel nodig bij netwerkcommunicatie.
- **Saga**: Onvermijdelijk bij distributed transactions.

#### Overbodig gemaakt door frameworks

- **Service Locator**: DI-containers (Angular, NestJS, Spring, ASP.NET) maken service locator een anti-pattern.
- **Repository** (als handmatige implementatie): Spring Data repositories, Prisma Client, Eloquent models genereren het al.

#### Alleen relevant in specifieke contexten

- **CQRS / Event Sourcing**: Alleen bij complexe domeinen met asymmetrische lees/schrijf-eisen. Overkill voor CRUD-apps.
- **Outbox / Dead Letter Queue**: Alleen bij event-driven architecturen met at-least-once delivery requirements.
- **Strangler Fig**: Alleen bij legacy-modernisering.

---

### 2.5 Concurrency Patterns

#### Universeel waardevol

- **Future / Promise**: Geabsorbeerd door async/await in JS, Python, C#, Rust, Kotlin, Swift, Dart. Het concept is universeel; de implementatie is taal-native.
- **Producer-Consumer**: Fundamenteel voor workload-distributie. Channels (Go), queues (Python), streams (Java).
- **Thread Pool**: Ingebouwd in de meeste runtimes (Java ExecutorService, Go goroutines, .NET ThreadPool, Node.js worker threads).

#### Overbodig gemaakt

- **Active Object**: Actor-systemen (Akka, Elixir/OTP, Swift actors) en async/await elimineren de noodzaak.
- **Monitor**: Moderne talen bieden high-level synchronisatieprimitieven (synchronized in Java, Mutex in Rust, Lock in Python).
- **Double-Checked Locking**: Taal-specifieke lazy-initialization (`lazy_static!` in Rust, `Lazy<T>` in C#, `by lazy` in Kotlin) elimineren dit anti-pattern.

#### Alleen relevant in specifieke contexten

- **Actor Model**: High-concurrency systemen (telecom, IoT, gaming). Overkill voor de meeste web-apps.
- **Fork-Join**: Rekenintensieve taken die parallelliseerbaar zijn.
- **Barrier**: Wetenschappelijk rekenen, batch-processing.

---

### 2.6 Functional Patterns

#### Universeel waardevol

- **Option/Maybe / Either/Result**: Rust (`Option`/`Result`), Kotlin (null safety), Swift (optionals), Haskell, Scala. Fundamenteel voor veilige foutafhandeling.
- **Pipe/Compose**: Unix-filosofie, functionele compositie. Native in Elixir (`|>`), F#, Haskell, en via libraries in JS/TS.
- **Memoization**: Universeel voor performance-optimalisatie. Native in React (`useMemo`), Vue (`computed`), Python (`@lru_cache`).

#### Overbodig gemaakt

- **Functor/Applicative/Monad** (als expliciet pattern): In niet-Haskell talen zijn deze concepten ingebouwd in de taal (Promise chains, Optional.map, Stream.flatMap) zonder dat developers de theoretische achtergrond hoeven te kennen.

#### Alleen relevant in specifieke contexten

- **Free Monad**: Alleen in Haskell/Scala ecosystemen voor effect-systemen.
- **Church Encoding**: Academisch — zelden in productie.
- **Lens**: Functionele talen met deep immutable state (Haskell, Clojure). In JS/TS vervangen door Immer of spread-operators.
- **ADT**: Krachtig in Rust, Haskell, Scala, Kotlin. In talen zonder sum types (Java < 17, JS) minder bruikbaar.

---

### 2.7 Architecture Patterns

#### Universeel waardevol

- **Layered Architecture**: Fundamenteel ordening dat elk project nodig heeft, ook al kies je voor hexagonal of clean architecture als verfijning.
- **Event-Driven Architecture**: Schaalbaar, ontkoppeld — de standaard voor microservices en real-time systemen.

#### Overbodig gemaakt door frameworks

- **MVC**: Ingebouwd in Rails, Django, Laravel, Spring MVC, ASP.NET MVC, Angular. Handmatige implementatie is nooit nodig.
- **MVVM**: Ingebouwd in Angular, Vue, SwiftUI, Jetpack Compose, WPF. Het framework *is* het MVVM.

#### Alleen relevant in specifieke contexten

- **Clean Architecture / Hexagonal**: Waardevol voor complexe domeinen met langlopende lifecycles. Overkill voor microservices met < 5 endpoints.
- **Microkernel / Plugin**: Alleen voor extensible systemen (IDE's, CMS'en, build-tools zoals cpm).
- **Space-Based Architecture**: Extreme schaalbaarheid (trading platforms, gaming).
- **Serverless**: Variabele workloads met piekbelasting.

---

### 2.8 State Management, Data, UI, API, Testing, Security, Meta

#### State Management

- **Redux/Flux**: De standaard voor complexe React-apps, maar overkill voor kleine apps. Signals (Angular, Svelte, Solid) en Pinia (Vue) maken het lichter.
- **State Machine**: Universeel waardevol maar vaak over het hoofd gezien. XState brengt het naar mainstream.

#### Data Patterns

- **Active Record vs Data Mapper**: Framework-keuze bepaalt dit. Rails/Laravel = Active Record, Hibernate/TypeORM/EF Core = Data Mapper. Geen keuze van de developer.
- **Repository**: Standaard in enterprise-applicaties, maar de meeste ORMs genereren het.

#### UI Patterns

- **Hooks Pattern**: De standaard in React. Vervangt HOC, render props, en mixins.
- **Compound Component / Slots**: UI-library patterns. Relevant voor componentbibliotheek-auteurs.
- **Atomic Design**: Design-systemen. Niet enforced door frameworks.

#### Testing

- **AAA / Given-When-Then**: Universeel — elk testframework ondersteunt dit.
- **Page Object**: E2E-testing standaard. Playwright/Cypress faciliteren dit.

---

## Deel 3: Specifieke Deep-Dive Analyses

### 3.1 SOLID in TypeScript vs Python vs C++ vs Java

| Principe | TypeScript | Python | C++ | Java |
|----------|-----------|--------|-----|------|
| **SRP** | 🔧 ES modules faciliteren kleine bestanden. Risico: barrel files die alles re-exporteren. | 🔧 Modules + packages. Risico: `utils.py` als God-module. | 🔧 Header/source scheiding dwingt na te denken. Risico: mega-headers. | 🔧 Klasse-per-bestand conventie helpt. Risico: enterprise-God-services. |
| **OCP** | 🔧 Union types + generics maken extensie makkelijk zonder overerving. Discriminated unions > class hierarchieën. | 🔧 Duck typing + Protocol maken extensie makkelijk. `@singledispatch` voor function overloading. | 🔧 Templates + virtual methods. Concepts (C++20) voor compile-time constraints. | 🔧 Interfaces + abstract classes. Sealed classes (Java 17) voor gesloten hiërarchieën. |
| **LSP** | ⚠️ Structural typing maakt LSP-schendingen moeilijker te detecteren. TypeScript valideert structureel, niet nominaal. | ⚠️ Duck typing = geen compile-time LSP check. Runtime errors bij schending. Protocol helpt, maar is optioneel. | 🔧 Strikte type-checking. Virtual destructors nodig voor correcte overerving. | 🔧 Strikte nominale types. @Override annotation helpt. |
| **ISP** | ✅ Utility types (`Pick`, `Omit`, `Partial`) maken ISP triviaal. Interfaces zijn structureel, dus je kunt precies de shape definiëren die je nodig hebt. | 🔄 Protocol (typing module) is de moderne aanpak. Abstract base classes zijn de oude manier. | 🔧 Multiple inheritance van abstracte klassen. Concepts (C++20) bieden compile-time ISP. | 🔧 Interfaces met default methods (Java 8+). Risico: interface pollution. |
| **DIP** | 🔧 Geen native DI. Handmatig via constructor injection of libraries (tsyringe, InversifyJS). | 🔧 Geen native DI (behalve FastAPI's `Depends`). `dependency-injector` library of handmatig. | 🔧 Geen native DI. Templates kunnen abstractie bieden, maar handmatige wiring nodig. | ✅ Spring/Guice/CDI bieden volledige DI-ecosystemen. Annotations maken het declaratief. |

**Kernobservatie**: SOLID-principes zijn taal-agnostisch waardevol, maar de *implementatie* verschilt radicaal. TypeScript's structural typing maakt ISP triviaal, terwijl Java een heel DI-ecosysteem heeft gebouwd voor DIP.

---

### 3.2 DI: Native vs Manual

| Aspect | Angular | NestJS | Spring Boot | FastAPI | React | Vue |
|--------|---------|--------|-------------|---------|-------|-----|
| **DI type** | Hierarchical IoC | Module-scoped IoC | Annotation-based IoC | Function-based | Geen native DI | Geen native DI |
| **Registratie** | `@Injectable()` + `providedIn` | `@Injectable()` + module providers | `@Component/@Service` + component scan | `Depends()` parameter | N.v.t. | N.v.t. |
| **Scopes** | Singleton, component, element | Singleton, request, transient | Singleton, prototype, request, session | Per-request (default) | N.v.t. | N.v.t. |
| **Singleton** | ✅ `providedIn: 'root'` | ✅ Default scope | ✅ Default scope | 🔄 Module-scope | 🔄 Module-scope variable | 🔄 Module-scope variable |
| **Testing** | ✅ TestBed.inject() | ✅ Test module met overrides | ✅ @MockBean/@SpyBean | ✅ Depends() override | 🔧 Props/Context mocking | 🔧 provide/inject mocking |
| **Aanbeveling** | Gebruik de native DI. Niet InversifyJS of tsyringe ernaast. | Gebruik de native DI. Geen extra containers. | Gebruik Spring DI. Niet Guice ernaast. | Gebruik `Depends()`. Geen DI-containers. | Context API voor cross-cutting. Props voor data. Geen DI-containers. | `provide/inject` voor DI. Props voor data. Geen DI-containers. |

**Anti-pattern**: InversifyJS of tsyringe gebruiken in een Angular- of NestJS-project. Het framework *is* de DI-container.

---

### 3.3 State Management: Redux/NgRx vs Signals/Reactivity

| Aspect | Redux/NgRx (imperatief) | Signals/Reactivity (reactief) |
|--------|------------------------|-------------------------------|
| **Paradigma** | Unidirectional flow: Action → Reducer → Store → View | Fine-grained reactivity: Signal → Effect → DOM |
| **Boilerplate** | Hoog: actions, reducers, selectors, effects | Laag: signal + computed + effect |
| **Debugging** | ✅ Excellent: time-travel, Redux DevTools | ⚠️ Groeiend: Angular DevTools, Svelte DevTools |
| **Performance** | ⚠️ Hele component-tree re-renders (tenzij memoization) | ✅ Fine-grained: alleen de DOM-node die afhangt van het signal |
| **Complexe state** | ✅ Sterk: normalized state, entity adapters | ⚠️ Kan complex worden bij veel onderlinge afhankelijkheden |
| **Team-schaal** | ✅ Voorspelbaar voor grote teams | ⚠️ Minder conventie — meer vrijheid = meer variatie |
| **Wanneer Redux** | Complexe apps met veel asynchrone interacties, time-travel debugging nodig, grote teams | — |
| **Wanneer Signals** | — | Kleinere apps, performance-kritische UI, eenvoudige state, directe DOM-binding |

**Transitie per framework**:

- **Angular**: Van NgRx Store → NgRx SignalStore. Signalen worden de standaard.
- **React**: Van Redux → Zustand/Jotai. React Compiler maakt memoization overbodig.
- **Vue**: Pinia (al reactief). Signals zijn impliciet aanwezig via Vue's reactivity.
- **Svelte**: Runes ($state, $derived, $effect) vervangen stores. Redux is nooit nodig geweest.
- **Solid**: Signals zijn de fundering. Redux-pattern is onnodig.

---

### 3.4 ORM Patterns: Active Record vs Data Mapper

| Aspect | Active Record | Data Mapper |
|--------|--------------|-------------|
| **Frameworks** | Rails (ActiveRecord), Laravel (Eloquent), Django ORM | TypeORM, Hibernate/JPA, Entity Framework Core, Prisma, Diesel |
| **Filosofie** | Object *is* de rij — bevat data + persistentielogica | Object en persistentie zijn gescheiden — mapper vertaalt |
| **Voordeel** | Simpel, snel te leren, weinig boilerplate, Convention over Configuration | Domeinmodel is zuiver, testbaar zonder DB, complexe mapping mogelijk |
| **Nadeel** | God-object (data + validatie + persistentie + business logic), moeilijk testbaar zonder DB | Meer boilerplate, indirectie, complexer voor simpele CRUD |
| **Wanneer** | CRUD-apps, prototyping, startups, monolithen < 50K LOC | Complexe domeinen, DDD, hexagonal architecture, > 50K LOC |
| **"Het framework kiest"** | Rails, Laravel, Django → Active Record. Niet vechten. | Hibernate, EF Core, TypeORM → Data Mapper. Niet Active Record erbovenop bouwen. |

**RTFM-regel**: Als je Rails of Laravel gebruikt, bouw geen Repository-pattern bovenop ActiveRecord/Eloquent. Het framework *is* het repository. Als je Hibernate of EF Core gebruikt, gebruik het Unit of Work pattern dat de ORM al biedt (Session/DbContext).

---

### 3.5 Observer: Native vs Handmatig

| Platform | Native Observer Mechanisme | Handmatig Implementeren? |
|----------|---------------------------|-------------------------|
| **Angular** | RxJS Observables, Signals, EventEmitter, Output() | 🚫 Nooit — RxJS *is* Observer op steroïden |
| **React** | useState + useEffect, useSyncExternalStore | 🚫 Gebruik hooks. Geen EventEmitter in components. |
| **Vue** | Reactive refs, watch, watchEffect, computed | 🚫 Vue's reactivity systeem *is* observer |
| **Svelte** | $state, $derived, $effect (runes) | 🚫 Runes zijn observer |
| **Node.js** | EventEmitter (native module) | 🔧 EventEmitter voor server-side events |
| **C#** | `event` keyword + delegates | 🚫 Taal-native |
| **Java** | PropertyChangeListener, @EventListener (Spring) | 🔧 Voor complexe event-systemen buiten Spring |
| **Go** | Channels + goroutines | 🔄 Channels zijn het reactieve primitief |
| **Rust** | Geen native — tokio::broadcast, crossbeam channels | 🔧 Channels of libraries |
| **Kotlin** | Flow, StateFlow, SharedFlow | 🚫 Kotlin Flow *is* reactive streams |

**Vuistregel**: Als je framework reactive primitieven biedt (en dat doen bijna alle moderne frameworks), implementeer dan **nooit** handmatig het Observer-pattern met `subscribe()`/`notify()`-methoden.

---

### 3.6 Factory: Wanneer een Factory, Wanneer Gewoon `new`

| Situatie | Aanbeveling | Waarom |
|----------|-------------|--------|
| Eén concrete klasse, geen variatie | `new MyService()` of module-scope | Factory voegt alleen indirectie toe |
| Eén klasse met complexe setup | Builder of config-object | Factory is overkill; named params of builder voldoen |
| Polymorfisme: keuze tussen implementaties | **Factory Method** of DI | Decoupling van de concrete keuze |
| Families van gerelateerde objecten | **Abstract Factory** of DI met modules | Consistente productfamilies |
| Framework met DI (Angular, NestJS, Spring) | **Gebruik de DI-container** | `useFactory` / `@Bean` / custom providers *zijn* de factory |
| Runtime-keuze op basis van config | Factory + registry | Config-driven creatie |
| Library/SDK die objecten retourneert | Factory Method | API-contract ontkoppelen van implementatie |

**Anti-pattern**: `ServiceFactory.create()` in een NestJS- of Spring-project terwijl de DI-container `useFactory` of `@Bean` biedt. De container *is* de factory.

---

### 3.7 Singleton: Wanneer een Singleton, Wanneer Module-Scope

| Taal/Platform | Singleton-Alternatief | Wanneer Toch Singleton |
|--------------|----------------------|----------------------|
| **TypeScript/JS** | `export const service = new Service()` — ES module is singleton by design | Nooit handmatig. Module-scope = singleton. |
| **Python** | Module-level instantie: `service = Service()` in `__init__.py` | Nooit handmatig. Module is singleton by design. |
| **Go** | Package-level variable: `var service = newService()` | `sync.Once` als lazy init nodig is. |
| **Kotlin** | `object MyService` — taal-native singleton | Companion object als factory-achtig gedrag nodig is. |
| **Rust** | `lazy_static!` of `once_cell::sync::Lazy` | Wanneer mutable global state onvermijdelijk is (zeldzaam). |
| **Java** | Spring `@Service` (default singleton scope) | Buiten Spring: enum singleton (effectief, thread-safe). |
| **C#** | ASP.NET DI met `AddSingleton<T>()` | Buiten DI: `Lazy<T>` |
| **Angular** | `@Injectable({ providedIn: 'root' })` | Nooit handmatig. DI *is* singleton management. |
| **NestJS** | `@Injectable()` (default singleton scope) | Nooit handmatig. DI *is* singleton management. |

**Vuistregel**: Als je in een modern ecosysteem werkt (ES modules, Python modules, DI-containers), heb je het Singleton-pattern **nooit** handmatig nodig. De module-loader of DI-container garandeert single-instance. Het handmatig implementeren van `getInstance()` met lazy initialization is een code smell die duidt op onbekendheid met het platform.

---

## Deel 4: RTFM — Read The Framework Manual

Per framework: concrete voorbeelden waar developers onnodig patterns implementeren terwijl het framework het al doet.

### 4.1 Angular

| # | Onnodige Pattern-Implementatie | Framework-Native Oplossing | Toelichting |
|---|-------------------------------|---------------------------|-------------|
| 1 | Handmatige Singleton-klasse met `getInstance()` | `@Injectable({ providedIn: 'root' })` | Angular DI garandeert single-instance. `providedIn: 'root'` is tree-shakeable. |
| 2 | InversifyJS of tsyringe voor DI | Angular's eigen hierarchische DI | Angular's DI is volwassen, type-safe, en ondersteunt scoping per component/module. Extra containers zijn redundant en conflicterend. |
| 3 | Custom EventBus/PubSub service | RxJS `Subject` of `BehaviorSubject` | RxJS is een eersteklas dependency in Angular. `Subject.next()` + `subscribe()` is pub-sub. |
| 4 | Handmatige Observer met `subscribe()`/`notify()` | Angular Signals of RxJS Observables | Signals (`signal()`, `computed()`, `effect()`) voor synchrone state. RxJS voor async streams. |
| 5 | Redux-achtige state management van scratch | NgRx SignalStore of component-level signals | NgRx SignalStore biedt Redux-like guarantees met signal-based reactivity. Voor simpele state: gewoon signals in services. |
| 6 | Middleware-chain voor HTTP requests | `HttpInterceptor` (functional of class-based) | Angular's `HttpClient` ondersteunt interceptors native. Functionele interceptors (`withInterceptors()`) zijn de moderne aanpak. |
| 7 | Custom form validation framework | Reactive Forms met `Validators` + custom validators | `FormBuilder` + `Validators.required` + custom `ValidatorFn` is de standaard. Template-driven forms voor simpele cases. |
| 8 | Guard Clause pattern voor routing | `CanActivate` / `canActivate` functional guard | Route guards zijn native. Functional guards in Angular 15+ zijn eenvoudiger dan class-based guards. |
| 9 | Factory Method voor services | `useFactory` in providers | `{ provide: MyService, useFactory: (dep) => new MyService(dep), deps: [OtherService] }` is de native factory. |
| 10 | Custom pipe operator voor data transformatie | Angular `Pipe` (`@Pipe` + `transform()`) | Pure pipes zijn gecached en performant. Geen custom filter-functies nodig. |

---

### 4.2 React

| # | Onnodige Pattern-Implementatie | Framework-Native Oplossing | Toelichting |
|---|-------------------------------|---------------------------|-------------|
| 1 | HOC (Higher-Order Component) voor shared logic | Custom Hook | Hooks vervangen HOCs sinds React 16.8. `useAuth()`, `useFetch()`, `useForm()` — compositie > wrapping. |
| 2 | Render Props voor data sharing | Custom Hook | Hooks zijn simpeler en vermijden de "callback hell" van render props. |
| 3 | MobX of custom Observer-pattern | `useState` + `useEffect` of `useSyncExternalStore` | Voor de meeste apps is React's eigen state management voldoende. `useSyncExternalStore` voor external stores. |
| 4 | Context API als volledige state management | Zustand, Jotai, of `useReducer` | Context is voor infrequent-veranderende data (theme, auth). Voor frequent-veranderende state veroorzaakt het onnodige re-renders. |
| 5 | Handmatige memoization met `WeakMap` | `useMemo`, `useCallback`, `React.memo` | React biedt declaratieve memoization. React Compiler (React 19+) automatiseert dit verder. |
| 6 | Custom data fetching met loading/error states | TanStack Query of SWR, of `use()` hook (React 19) | Data-fetching libraries bieden caching, deduplication, en revalidation out-of-the-box. |
| 7 | Handmatige error handling per component | `ErrorBoundary` component | Class-based error boundaries vangen render-errors op. `react-error-boundary` library voor declaratieve boundaries. |
| 8 | Prop drilling via 10+ levels | `useContext` of state management library | Context API lost prop drilling op. Zustand/Jotai voor complexere gevallen. |
| 9 | Custom portal implementatie | `ReactDOM.createPortal()` | Native portals renderen content buiten de parent DOM-boom. |
| 10 | Handmatige code splitting | `React.lazy()` + `Suspense` | Dynamische imports met lazy loading zijn native. Next.js voegt route-based splitting toe. |

---

### 4.3 NestJS

| # | Onnodige Pattern-Implementatie | Framework-Native Oplossing | Toelichting |
|---|-------------------------------|---------------------------|-------------|
| 1 | InversifyJS of tsyringe voor DI | NestJS native DI met `@Injectable()` | NestJS *is* een DI-container. Extra containers conflicteren met het module-systeem. |
| 2 | Custom middleware chain | Guards, Interceptors, Pipes, Filters | NestJS heeft 4 lagen van request-processing: guards (auth), interceptors (transform), pipes (validate), filters (errors). |
| 3 | Handmatige singleton pattern | Default provider scope is singleton | `@Injectable()` is singleton by default. `@Injectable({ scope: Scope.REQUEST })` voor request-scoped. |
| 4 | Custom Event Bus | `@nestjs/event-emitter` + `@OnEvent()` decorator | Native event-emitter module met decorator-based listeners. |
| 5 | Handmatige CQRS implementatie | `@nestjs/cqrs` module | Officieel NestJS CQRS-module met commands, queries, events, en sagas. |
| 6 | Custom validation logic | `class-validator` + `ValidationPipe` | `@IsString()`, `@IsEmail()`, `@Min()` decorators + globale `ValidationPipe` valideren automatisch. |
| 7 | Factory Method klasse | Custom providers: `useFactory`, `useValue`, `useClass` | `{ provide: 'CONFIG', useFactory: async () => await loadConfig() }` is de native factory. |
| 8 | Handmatige Swagger/OpenAPI docs | `@nestjs/swagger` + decorators | `@ApiProperty()`, `@ApiResponse()`, `@ApiTags()` genereren automatisch OpenAPI specs. |
| 9 | Custom serialization | `ClassSerializerInterceptor` + `class-transformer` | `@Exclude()`, `@Expose()`, `@Transform()` decorators + interceptor serialiseren automatisch. |
| 10 | Handmatige health checks | `@nestjs/terminus` | Health check endpoints met `HealthCheck`, `HttpHealthIndicator`, `TypeOrmHealthIndicator`, etc. |

---

### 4.4 FastAPI

| # | Onnodige Pattern-Implementatie | Framework-Native Oplossing | Toelichting |
|---|-------------------------------|---------------------------|-------------|
| 1 | DI-container (dependency-injector, inject) | `Depends()` systeem | FastAPI's `Depends()` is een function-based DI-systeem. Nested dependencies, caching, en overrides voor testing. |
| 2 | Request validation middleware | Pydantic modellen als parameter types | `def endpoint(body: MyModel)` valideert en parseert automatisch. Pydantic v2 is extreem snel. |
| 3 | Handmatige OpenAPI/Swagger docs | Automatisch gegenereerd | FastAPI genereert OpenAPI 3.1 docs automatisch op `/docs` (Swagger UI) en `/redoc` (ReDoc). |
| 4 | Custom serialization/deserialization | Pydantic `model_dump()` / `model_validate()` | `response_model=MyModel` serialiseert automatisch. `model_config = ConfigDict(from_attributes=True)` voor ORM-objecten. |
| 5 | Handmatige CORS setup | `CORSMiddleware` | `app.add_middleware(CORSMiddleware, allow_origins=[...])` — één regel. |
| 6 | Custom error handling framework | `HTTPException` + `@app.exception_handler()` | `raise HTTPException(status_code=404, detail="Not found")` + custom exception handlers. |
| 7 | Custom background job systeem | `BackgroundTasks` | `async def endpoint(bg: BackgroundTasks): bg.add_task(send_email, ...)` voor fire-and-forget taken. |
| 8 | Custom OAuth2 implementatie | `OAuth2PasswordBearer` + `Depends()` | `oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")` + dependency chain voor auth. |
| 9 | Middleware chain pattern | `@app.middleware("http")` + Starlette middleware | Standaard ASGI middleware stack. Starlette middlewares zijn compatible. |
| 10 | Builder pattern voor configuratie | Pydantic `BaseSettings` | `class Settings(BaseSettings): db_url: str` laadt automatisch uit env vars, .env bestanden, secrets. |

---

### 4.5 Spring Boot

| # | Onnodige Pattern-Implementatie | Framework-Native Oplossing | Toelichting |
|---|-------------------------------|---------------------------|-------------|
| 1 | Handmatige Singleton | Default scope is singleton | `@Service`, `@Component`, `@Repository` zijn singleton by default. Gebruik `@Scope("prototype")` alleen als nodig. |
| 2 | Service Locator pattern | `@Autowired` / constructor injection | DI via constructor injection is de standaard. Service Locator is een anti-pattern in Spring. |
| 3 | Handmatige Repository implementatie | Spring Data JPA `JpaRepository<T, ID>` | `interface UserRepo extends JpaRepository<User, Long>` genereert automatisch findAll, save, delete, findBy*. |
| 4 | Factory klassen voor bean-creatie | `@Bean` methoden in `@Configuration` | `@Bean public MyService myService() { return new MyService(dep); }` is de native factory. |
| 5 | Custom AOP voor logging/security | Spring AOP `@Aspect` + `@Around` | `@Around("execution(* com.app.service.*.*(..))")` voor cross-cutting concerns. Spring Security voor auth. |
| 6 | Handmatige event systeem | `ApplicationEventPublisher` + `@EventListener` | `publisher.publishEvent(new OrderCreated(order))` + `@EventListener public void handle(OrderCreated e)`. |
| 7 | Custom health check endpoints | Spring Actuator `/actuator/health` | `management.endpoints.web.exposure.include=health,info,metrics` activeert health, info, en metrics endpoints. |
| 8 | Handmatige configuration loading | `@ConfigurationProperties` + `application.yml` | Type-safe configuration binding: `@ConfigurationProperties(prefix = "app.db")` bindt automatisch. |
| 9 | Custom retry logic | Spring Retry `@Retryable` | `@Retryable(maxAttempts = 3, backoff = @Backoff(delay = 1000))` voor declaratieve retries. |
| 10 | Handmatige caching | `@Cacheable` / `@CacheEvict` | `@Cacheable("users")` cachet method-resultaten automatisch. Supports Redis, Caffeine, EhCache. |

---

### 4.6 Django

| # | Onnodige Pattern-Implementatie | Framework-Native Oplossing | Toelichting |
|---|-------------------------------|---------------------------|-------------|
| 1 | Repository pattern bovenop Django ORM | `Model.objects` Manager | `User.objects.filter(active=True).order_by('-created')` — de Manager *is* het repository. Custom managers voor herbruikbare queries. |
| 2 | Custom form validation framework | Django Forms + ModelForm | `class UserForm(ModelForm): class Meta: model = User` met validators. `form.is_valid()` valideert alles. |
| 3 | Handmatige CRUD admin interface | `admin.site.register(Model)` + `ModelAdmin` | Django Admin is een volledige CRUD interface. `@admin.register(User)` + `list_display`, `search_fields`, `list_filter`. |
| 4 | Custom auth systeem | `django.contrib.auth` | User model, authentication backends, permissions, groups — alles ingebouwd. `@login_required` decorator. |
| 5 | Custom migration tool | Django migrations | `python manage.py makemigrations` + `migrate` — automatische schema-migraties op basis van model-wijzigingen. |
| 6 | Handmatige serialization | Django REST Framework serializers | `class UserSerializer(ModelSerializer): class Meta: model = User` — automatische serialisatie, validatie, nested relations. |
| 7 | Observer pattern voor model events | Django signals (`post_save`, `pre_delete`, etc.) | `@receiver(post_save, sender=User) def on_user_save(sender, instance, **kwargs)` — native observer. |
| 8 | Custom middleware stack | `MIDDLEWARE` setting + `MiddlewareMixin` | Django's middleware pipeline verwerkt request/response. SecurityMiddleware, SessionMiddleware, CsrfViewMiddleware zijn standaard. |
| 9 | Template Method voor views | Class-Based Views (CBV) | `ListView`, `DetailView`, `CreateView`, `UpdateView`, `DeleteView` — template method pattern ingebouwd. |
| 10 | Custom caching framework | Django cache framework | `@cache_page(60 * 15)` voor view caching. `cache.set('key', value, timeout)` voor low-level. Supports Memcached, Redis. |

---

### 4.7 Rails

| # | Onnodige Pattern-Implementatie | Framework-Native Oplossing | Toelichting |
|---|-------------------------------|---------------------------|-------------|
| 1 | Repository pattern bovenop ActiveRecord | ActiveRecord scopes + associations | `scope :active, -> { where(active: true) }` — model methods *zijn* het repository. Geen extra abstractie nodig. |
| 2 | Service Locator pattern | Rails' autoloading + convention | `app/services/`, `app/models/` — Rails laadt automatisch. Geen registratie nodig. |
| 3 | Custom validation framework | ActiveRecord validations | `validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }` — declaratieve validatie. Custom validators met `validate :custom_check`. |
| 4 | Custom background job systeem | Active Job + adapter (Sidekiq, Resque, etc.) | `class SendEmailJob < ApplicationJob; def perform(user); end; end` + `SendEmailJob.perform_later(user)`. |
| 5 | Observer pattern handmatig | ActiveRecord callbacks + Active Support Notifications | `before_save :normalize_email`, `after_create :send_welcome`. `ActiveSupport::Notifications.subscribe("event")` voor cross-cutting. |
| 6 | Custom WebSocket implementatie | Action Cable | `class ChatChannel < ApplicationCable::Channel; def subscribed; stream_from "chat_#{params[:room]}"; end; end`. |
| 7 | Handmatige mailer setup | Action Mailer | `class UserMailer < ApplicationMailer; def welcome_email(user); end; end` + `UserMailer.welcome_email(@user).deliver_later`. |
| 8 | Custom CSRF protection | Rails CSRF middleware | `protect_from_forgery with: :exception` is standaard. `<%= csrf_meta_tags %>` in layouts. |
| 9 | Handmatige asset pipeline | Importmap of Propshaft/Sprockets | Rails 7+ gebruikt Importmap voor JavaScript (geen bundler nodig) of Propshaft voor assets. |
| 10 | Custom SPA-achtige interactiviteit | Hotwire (Turbo + Stimulus) | Turbo Frames voor partial page updates, Turbo Streams voor real-time updates, Stimulus voor JavaScript sprinkles. Geen React/Vue nodig voor de meeste interactiviteit. |

---

## Deel 5: Synthese en Aanbevelingen voor cpm

### 5.1 Implicaties voor cpm Rule Engine

Op basis van de matrix-analyse moeten cpm-regels platform-aware worden:

| Regel | Zonder context | Met context |
|-------|---------------|-------------|
| "Missing DI pattern" | ⚠️ Warning altijd | ✅ Suppress in Angular/NestJS/Spring (native DI) |
| "Singleton anti-pattern detected" | ⚠️ Warning altijd | ✅ Suppress als `@Injectable()` of `@Service` (DI-managed singleton) |
| "Missing Observer pattern" | ⚠️ Warning altijd | ✅ Suppress in Angular (RxJS), Vue (reactivity), Svelte (runes) |
| "No state management" | ⚠️ Warning altijd | 🔧 Check of framework signals/stores aanwezig zijn |
| "Active Record anti-pattern" | ⚠️ Warning altijd | ✅ Suppress in Rails/Laravel/Django (het *is* het framework) |
| "Missing Repository pattern" | ⚠️ Warning altijd | ✅ Suppress als Spring Data / Prisma / Eloquent aanwezig is |

### 5.2 Platform Detection Priorities

Voor cpm-regelafstelling, detecteer eerst:

1. **Framework** (Angular, NestJS, Spring, Django, Rails, Laravel, FastAPI) — bepaalt welke patterns native zijn
2. **Taal** (TypeScript, Python, Java, Go, Rust, C#) — bepaalt welke taalfeatures patterns vervangen
3. **ORM** (Prisma, Hibernate, Eloquent, ActiveRecord, TypeORM) — bepaalt data-pattern aanbevelingen
4. **State management** (Redux, NgRx, Pinia, Zustand, signals) — bepaalt state-pattern aanbevelingen

### 5.3 De 10 Meest Overschatte Patterns

Patterns die het vaakst onnodig worden geïmplementeerd:

| # | Pattern | Waarom Overschat | In Plaats Daarvan |
|---|---------|-------------------|-------------------|
| 1 | Singleton (handmatig) | Module-systemen en DI-containers lossen dit op | Module-scope of DI-registratie |
| 2 | Observer (handmatig) | Reactive frameworks doen dit native | RxJS, signals, reactivity, channels |
| 3 | Factory (handmatig) | DI-containers zijn de factory | `useFactory`, `@Bean`, `Depends()` |
| 4 | Repository (handmatig) | ORMs genereren het | Spring Data, Prisma Client, Eloquent |
| 5 | Builder (klassiek) | Named args, data classes, spread operator | Taal-native constructie |
| 6 | Iterator (handmatig) | Taal-native in alle moderne talen | Generators, streams, LINQ, ranges |
| 7 | Visitor (klassiek) | Pattern matching vervangt het | `match`, `when`, sealed classes |
| 8 | Template Method (klassiek) | Hooks en lifecycle callbacks vervangen overerving | Framework lifecycle hooks |
| 9 | Service Locator | Anti-pattern in DI-contexten | Constructor injection via DI |
| 10 | Decorator (klassiek wrapper) | Taal-decorators, middleware, interceptors | `@decorator`, middleware pipeline |

### 5.4 De 10 Meest Onderschatte Patterns

Patterns die vaker zouden moeten worden toegepast:

| # | Pattern | Waarom Onderschat | Wanneer Toepassen |
|---|---------|-------------------|-------------------|
| 1 | State Machine | Voorkomt boolean-flag-spaghetti | Elke workflow met > 3 toestanden |
| 2 | Circuit Breaker | Voorkomt cascade failures | Elke externe service-aanroep |
| 3 | Guard Clause | Voorkomt diep geneste conditionals | Begin van elke publieke methode |
| 4 | Result/Either type | Expliciet foutpad, geen hidden exceptions | Elke operatie die kan falen |
| 5 | Value Object | Voorkomt primitive obsession | Elke domein-entiteit met semantiek (Money, Email, PhoneNumber) |
| 6 | Idempotent Receiver | Voorkomt dubbele verwerking | Elke message consumer |
| 7 | Specification | Composable business rules | Complexe filter/zoek-criteria |
| 8 | Anti-Corruption Layer | Houdt extern systeem-rot buiten | Elke third-party integratie |
| 9 | Outbox Pattern | Voorkomt dual-write inconsistentie | Event-driven architecturen |
| 10 | Modular Monolith | Voorkomt premature microservices | Startups en teams < 10 developers |

---

## Bronnen

- Gamma, E. et al. (1994). *Design Patterns: Elements of Reusable Object-Oriented Software* (GoF)
- Fowler, M. (2002). *Patterns of Enterprise Application Architecture* (PoEAA)
- Martin, R.C. (2017). *Clean Architecture*
- Angular Docs: <https://angular.dev>
- React Docs: <https://react.dev>
- NestJS Docs: <https://docs.nestjs.com>
- FastAPI Docs: <https://fastapi.tiangolo.com>
- Spring Boot Docs: <https://docs.spring.io/spring-boot>
- Django Docs: <https://docs.djangoproject.com>
- Rails Guides: <https://guides.rubyonrails.org>

---

## Volgende Stappen (Fase 4-5)

1. **Fase 4 — cpm Rule Tagging**: Elke bestaande cpm-regel taggen met platform-scope (welke frameworks maken de regel irrelevant)
2. **Fase 5 — Detectie-Implementatie**: Pattern-detectie regels schrijven die platform-context meenemen en false positives elimineren
