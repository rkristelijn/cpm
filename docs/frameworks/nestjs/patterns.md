# NestJS — Read The Framework Manual (RTFM) Patterns

Source: learn.nestjs.com training (NestJS Fundamentals)
Version: NestJS 7+ (patterns stable through v10+)
Last reviewed: 2026-05

## Checkable Rules

### 1. Controller delegates to Service (no business logic in controllers)

**What**: Controllers should only handle HTTP concerns (params, body, response). Business logic belongs in services.
**Why**: Separation of concerns, testability, reusability.
**Check**: Controller files should not contain array manipulation, DB queries, or complex logic.

```bash
# Anti-pattern: business logic in controller
grep -l "\.find\|\.filter\|\.map\|\.reduce\|\.splice\|\.push" src/**/*.controller.ts
```

### 2. Use DTOs for input validation (not raw `any`)

**What**: Every `@Body()` parameter should be typed with a DTO class, not `any`.
**Why**: Runtime validation via class-validator, documentation, type safety.
**Check**: No `@Body() body` without a DTO type.

```bash
# Anti-pattern: untyped body
grep -n "@Body() body" src/**/*.controller.ts
```

### 3. DTOs use `readonly` properties

**What**: DTO properties should be `readonly` to prevent mutation.
**Why**: Immutability, clear intent that DTOs are data carriers not mutable objects.
**Check**: DTO class properties without `readonly`.

```bash
# Anti-pattern: mutable DTO
grep -P "^\s+(name|title|id)" src/**/*.dto.ts | grep -v readonly
```

### 4. One module per domain/feature

**What**: Each feature gets its own module (`CoffeesModule`, `UsersModule`).
**Why**: Encapsulation, lazy loading, clear boundaries.
**Check**: Controllers/services not registered in their own feature module.

```bash
# Check: every *.module.ts should exist per feature directory
find src -name "*.controller.ts" -exec dirname {} \; | sort -u | while read d; do
  [ ! -f "$d"/*.module.ts ] && echo "MISSING module in $d"
done
```

### 5. Services use `@Injectable()` decorator

**What**: All services must be decorated with `@Injectable()`.
**Why**: Required for NestJS DI container to manage the service lifecycle.
**Check**: Service files without `@Injectable()`.

### 6. Constructor injection over `new`

**What**: Dependencies are injected via constructor, never instantiated with `new`.
**Why**: Testability, lifecycle management, loose coupling.
**Check**: `new SomeService()` in any non-test file.

```bash
# Anti-pattern
grep -rn "new.*Service\|new.*Repository\|new.*Provider" src/ --include="*.ts" | grep -v spec | grep -v test
```

### 7. Use Guards for authorization (not middleware)

**What**: Route protection uses `@UseGuards()`, not middleware checks.
**Why**: Guards have access to ExecutionContext (know which handler runs next), middleware doesn't.
**Check**: Auth logic in middleware files.

```bash
# Anti-pattern: auth in middleware
grep -l "authorization\|isAuthenticated\|jwt\|token" src/**/*.middleware.ts
```

### 8. Use Pipes for validation/transformation (not manual parsing)

**What**: Use `ValidationPipe`, `ParseIntPipe`, etc. instead of manual `parseInt()` or validation in handlers.
**Why**: Declarative, reusable, consistent error responses.
**Check**: Manual parseInt/parseFloat in controllers.

```bash
# Anti-pattern
grep -n "parseInt\|parseFloat\|Number(" src/**/*.controller.ts
```

### 9. Use Interceptors for cross-cutting concerns

**What**: Logging, timing, response transformation, caching → interceptors.
**Why**: Separation of concerns, DRY, composable.
**Check**: `console.log`/`console.time` directly in controllers or services.

```bash
# Anti-pattern: logging in controllers
grep -n "console\.\(log\|time\|warn\)" src/**/*.controller.ts
```

### 10. Exception Filters for error formatting

**What**: Custom error response shapes use `@Catch()` exception filters, not try/catch in every handler.
**Why**: Consistent error responses, single responsibility.
**Check**: Multiple try/catch blocks in controllers with custom error formatting.

### 11. Entities use decorators (not raw SQL)

**What**: TypeORM entities use `@Entity()`, `@Column()`, `@PrimaryGeneratedColumn()`.
**Why**: Type safety, migration generation, relation management.
**Check**: Raw SQL strings in service files (outside migrations).

```bash
# Anti-pattern
grep -n "CREATE TABLE\|ALTER TABLE\|DROP TABLE" src/**/*.service.ts
```

### 12. Relations use TypeORM decorators

**What**: Use `@ManyToMany()`, `@OneToMany()`, `@ManyToOne()` with `@JoinTable()` on owner side.
**Why**: Automatic join table management, eager/lazy loading, cascade options.
**Check**: Manual join queries where relations should be declared.

### 13. Migrations for schema changes (not `synchronize: true` in production)

**What**: Use `typeorm migration:generate` for schema changes. `synchronize: true` only in dev.
**Why**: Data safety, reproducible deployments, audit trail.
**Check**: `synchronize: true` without environment guard.

```bash
# Anti-pattern
grep -n "synchronize.*true" src/**/*.ts | grep -v "process.env\|NODE_ENV\|development"
```

### 14. ConfigService over process.env

**What**: Use `ConfigService.get()` instead of direct `process.env` access in services.
**Why**: Testability, validation, type coercion, namespace support.
**Check**: Direct `process.env` in service/controller files.

```bash
# Anti-pattern
grep -n "process\.env\." src/**/*.service.ts src/**/*.controller.ts
```

### 15. Async module configuration with `forRootAsync`

**What**: Dynamic modules that need config use `forRootAsync()` with `useFactory`.
**Why**: Ensures ConfigModule is loaded before the module that needs it.
**Check**: `forRoot()` with `process.env` directly (race condition).

```bash
# Anti-pattern
grep -n "forRoot({" src/**/*.module.ts | grep -v "forRootAsync"
```

### 16. Use `@Res()` with caution

**What**: Avoid `@Res()` decorator — it makes code platform-dependent (Express vs Fastify).
**Why**: Portability, testability, NestJS loses control of response lifecycle.
**Check**: `@Res()` usage outside of streaming/file-download scenarios.

```bash
# Warning
grep -n "@Res()" src/**/*.controller.ts
```

### 17. Providers exported = module's public API

**What**: Only export providers that other modules need. Internal services stay private.
**Why**: Encapsulation, clear module boundaries.
**Check**: Module exports everything it provides.

### 18. Use `nest generate` for scaffolding

**What**: Use CLI generators (`nest g controller`, `nest g service`, `nest g module`) for consistency.
**Why**: Correct file structure, auto-registration in modules, spec files included.
**Check**: Files not following naming convention (`*.controller.ts`, `*.service.ts`, `*.module.ts`).

### 19. Validation with class-validator + ValidationPipe

**What**: DTOs use class-validator decorators (`@IsString()`, `@IsOptional()`) + global `ValidationPipe`.
**Why**: Automatic request validation, allowlist stripping, transformation.
**Check**: DTOs without any class-validator decorators.

```bash
# Anti-pattern: DTO without validation decorators
for f in $(find src -name "*.dto.ts"); do
  grep -L "@Is\|@Min\|@Max\|@Length\|@IsOptional" "$f"
done
```

### 20. Middleware for request-level concerns only

**What**: Middleware handles logging, CORS, body parsing — NOT business logic or auth decisions.
**Why**: Middleware lacks ExecutionContext, can't know which handler runs next.
**Check**: Complex logic in middleware files.

## Severity Mapping

| Rule | Severity | Rationale |
|------|----------|-----------|
| 1. Controller delegates to service | error | Architecture violation |
| 2. DTOs for input | error | Security (injection risk) |
| 3. readonly DTOs | warning | Best practice |
| 4. One module per feature | warning | Maintainability |
| 5. @Injectable on services | error | App won't work without it |
| 6. Constructor injection | error | Testability, DI contract |
| 7. Guards for auth | warning | Correctness |
| 8. Pipes for validation | warning | Consistency |
| 9. Interceptors for cross-cutting | info | Best practice |
| 10. Exception filters | info | Consistency |
| 11. Entity decorators | error | Framework contract |
| 12. Relation decorators | warning | Maintainability |
| 13. No synchronize in prod | error | Data safety |
| 14. ConfigService over process.env | warning | Testability |
| 15. forRootAsync | warning | Race condition prevention |
| 16. Avoid @Res() | warning | Portability |
| 17. Export only public API | info | Encapsulation |
| 18. nest generate conventions | info | Consistency |
| 19. class-validator on DTOs | error | Security |
| 20. Middleware scope | info | Architecture |

### Community & Security Patterns (from Medium, Reddit, NestJS docs, security audits)

| Rule | Severity | Rationale |
|------|----------|-----------|
| 21. Rate limiting (@nestjs/throttler) | warning | DoS/brute force prevention |
| 22. No CORS wildcard in production | error | Cross-origin attack surface |
| 23. Helmet security headers | warning | XSS, clickjacking, MIME sniffing |
| 24. Circular deps (forwardRef overuse) | warning | Architecture smell |
| 25. Entity not exposed from controller | warning | Data leakage prevention |
| 26. Global ValidationPipe in main.ts | error | DTOs don't validate without it |
| 27. No raw SQL in services | warning | Injection risk, migration hygiene |
| 28. @Global() module overuse | warning | DI scope pollution |
| 29. Test files exist | warning | Reliability, regression prevention |
| 30. Feature-based folder structure | info | Maintainability at scale |
