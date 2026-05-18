# SOLID Pattern Detection

This document describes checkable SOLID principles that can be detected via grep/file analysis in TypeScript/JavaScript codebases.

## Overview

SOLID is an acronym for five design principles:

| Principle | Acronym | Focus |
|-----------|---------|-------|
| Single Responsibility | SRP | One reason to change per class/module |
| Open/Closed | OCP | Open for extension, closed for modification |
| Liskov Substitution | LSP | Subtypes must be substitutable for their base types |
| Interface Segregation | ISP | Many specific interfaces > one general interface |
| Dependency Inversion | DIP | Depend on abstractions, not concretions |

---

## Single Responsibility Principle (SRP)

**Definition**: A class/module should have only one reason to change.

### Checkable Patterns

| # | Pattern | Detection Method | Severity |
|---|---------|------------------|----------|
| 1 | **File size > 400 lines** | Count lines in `.ts`/`.tsx` files | warn |
| 2 | **Multiple exports with unrelated concerns** | Count exports, check naming patterns | warn |
| 3 | **Mixed concerns in single function** | Detect functions with >3 distinct operations (I/O, business logic, formatting) | warn |
| 4 | **God class (high coupling)** | Files with >10 imports from different modules | error |
| 5 | **Utility class with mixed utilities** | Files exporting >5 unrelated helper functions | warn |

### Examples

```typescript
// BAD: Multiple responsibilities (validation, formatting, business logic)
export function processUser(user: User): string {
  validateUser(user);           // validation
  const formatted = formatUser(user);  // formatting
  saveToDatabase(user);         // I/O
  return generateResponse(formatted);  // business logic
}

// GOOD: Single responsibility per function
export function validateUser(user: User): void { /* ... */ }
export function formatUser(user: User): FormattedUser { /* ... */ }
export function saveToDatabase(user: User): Promise<void> { /* ... */ }
```

---

## Open/Closed Principle (OCP)

**Definition**: Software entities should be open for extension but closed for modification.

### Checkable Patterns

| # | Pattern | Detection Method | Severity |
|---|---------|------------------|----------|
| 6 | **Switch/case on type** | Detect `switch(type)` or `instanceof` chains | warn |
| 7 | **Type checking in core logic** | `typeof x === 'string'` patterns in business code | warn |
| 8 | **Hardcoded behavior extensions** | `if (env === 'production')` patterns without strategy pattern | warn |
| 9 | **Feature flags as conditionals** | `if (featureEnabled('x'))` without polymorphism | info |

### Examples

```typescript
// BAD: Open/Closed violation - must modify to add new shape
function calculateArea(shape: Shape): number {
  switch (shape.type) {
    case 'circle': return Math.PI * shape.radius ** 2;
    case 'square': return shape.side ** 2;
    // Must modify to add 'triangle'
  }
}

// GOOD: Open/Closed - extend via new classes
interface Shape {
  area(): number;
}
class Circle implements Shape { /* ... */ }
class Square implements Shape { /* ... */ }
// Add Triangle without modifying existing code
```

---

## Liskov Substitution Principle (LSP)

**Definition**: Objects of a superclass should be replaceable with objects of its subclasses without breaking the application.

### Checkable Patterns

| # | Pattern | Detection Method | Severity |
|---|---------|------------------|----------|
| 10 | **Override without super call** | Methods that call `super.method()` in <50% of overrides | warn |
| 11 | **Return type widening in override** | Override returns `any` or `unknown` when parent returns specific type | warn |
| 12 | **Parameter type narrowing in override** | Override accepts narrower type than parent | error |
| 13 | **New exceptions in override** | `throw` statements in methods that parent doesn't declare | warn |
| 14 | **Property removal in subclass** | Subclass removes properties defined in parent interface | error |

### Examples

```typescript
// BAD: LSP violation - Square cannot substitute Rectangle
class Rectangle {
  constructor(public width: number, public height: number) {}
  setWidth(w: number) { this.width = w; }
  setHeight(h: number) { this.height = h; }
}

class Square extends Rectangle {
  setWidth(w: number) {
    this.width = w;
    this.height = w;  // Breaks Liskov - side effects
  }
}

// GOOD: Separate hierarchies or use composition
interface Shape { area(): number; }
class Rectangle implements Shape { /* ... */ }
class Square implements Shape { /* ... */ }
```

---

## Interface Segregation Principle (ISP)

**Definition**: Clients should not be forced to depend on interfaces they do not use.

### Checkable Patterns

| # | Pattern | Detection Method | Severity |
|---|---------|------------------|----------|
| 15 | **God interface (>5 methods)** | Interfaces with >5 methods | warn |
| 16 | **Fat interface with unused methods** | Interfaces where some methods are rarely implemented | warn |
| 17 | **Empty method implementations** | Classes implementing interfaces with `throw new Error()` or `// TODO` | warn |
| 18 | **Mix of I/O and business methods** | Interface combines network/disk ops with pure logic | warn |

### Examples

```typescript
// BAD: God interface - users forced to implement unused methods
interface Worker {
  work(): void;
  eat(): void;
  sleep(): void;
  commute(): void;
}

class Robot implements Worker {
  work() { /* ... */ }
  eat() { throw new Error("Robots don't eat"); }  // Forced empty impl
  sleep() { throw new Error("Robots don't sleep"); }
  commute() { /* ... */ }
}

// GOOD: Segregated interfaces
interface Workable { work(): void; }
interface Eatable { eat(): void; }
interface Sleepable { sleep(): void; }
```

---

## Dependency Inversion Principle (DIP)

**Definition**: High-level modules should not depend on low-level modules. Both should depend on abstractions.

### Checkable Patterns

| # | Pattern | Detection Method | Severity |
|---|---------|------------------|----------|
| 19 | **Concrete imports in domain** | Domain files importing `fs`, `axios`, `mongoose` | error |
| 20 | **Direct instantiation in business logic** | `new ClassName()` in non-factory files | warn |
| 21 | **Hardcoded service dependencies** | Dependencies not injected via constructor | warn |
| 22 | **Infrastructure in domain layer** | Files in `src/domain` importing from `src/infrastructure` | error |
| 23 | **Circular dependencies** | Import cycles detected via graph analysis | error |

### Examples

```typescript
// BAD: High-level module depends on low-level concrete
import { MySQLDatabase } from './infrastructure/MySQLDatabase';

class UserService {
  private db = new MySQLDatabase();  // Direct dependency on concrete

  async getUser(id: string) {
    return this.db.query('SELECT * FROM users WHERE id = ?', [id]);
  }
}

// GOOD: Depend on abstraction
import { Database } from './Database';
import { inject } from 'tsyringe';

class UserService {
  constructor(@inject('Database') private db: Database) {}

  async getUser(id: string) {
    return this.db.query('SELECT * FROM users WHERE id = ?', [id]);
  }
}

interface Database {
  query(sql: string, params: any[]): Promise<any>;
}
```

---

## Summary Table

| # | Principle | Pattern | Detection | Severity |
|---|-----------|---------|-----------|----------|
| 1 | SRP | File size > 400 lines | Line count | warn |
| 2 | SRP | Multiple unrelated exports | Export analysis | warn |
| 3 | SRP | Mixed concerns in function | Operation count | warn |
| 4 | SRP | God class (high coupling) | Import count | error |
| 5 | SRP | Utility class with mixed utilities | Export count | warn |
| 6 | OCP | Switch/case on type | `switch`/`instanceof` | warn |
| 7 | OCP | Type checking in core logic | `typeof` patterns | warn |
| 8 | OCP | Hardcoded behavior extensions | Conditional patterns | warn |
| 9 | OCP | Feature flags as conditionals | `featureEnabled` | info |
| 10 | LSP | Override without super call | `super.method()` | warn |
| 11 | LSP | Return type widening | Type analysis | warn |
| 12 | LSP | Parameter type narrowing | Type analysis | error |
| 13 | LSP | New exceptions in override | `throw` analysis | warn |
| 14 | LSP | Property removal in subclass | Interface diff | error |
| 15 | ISP | God interface (>5 methods) | Method count | warn |
| 16 | ISP | Fat interface with unused methods | Implementation check | warn |
| 17 | ISP | Empty method implementations | `throw new Error()` | warn |
| 18 | ISP | Mixed I/O and business methods | Operation analysis | warn |
| 19 | DIP | Concrete imports in domain | Import analysis | error |
| 20 | DIP | Direct instantiation | `new ClassName()` | warn |
| 21 | DIP | Hardcoded service dependencies | Constructor analysis | warn |
| 22 | DIP | Infrastructure in domain layer | Path-based | error |
| 23 | DIP | Circular dependencies | Import cycle | error |

---

## References

- Robert C. Martin - SOLID Principles
- Mark Seemann - Encapsulation and SOLID (Pluralsight)
- Martin Fowler - Refactoring
