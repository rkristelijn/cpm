# Developer Frustrations When Reading & Understanding Code

## Research Sources

- Stack Overflow Developer Survey 2024 (65,000+ developers): Technical debt #1 frustration (62%)
- Atlassian Developer Experience Report 2024: 97% lose significant time to inefficiencies
- Google Research: Code quality directly correlates with developer productivity
- Code Red Study (39 codebases, 30,737 files): Low quality code has 15x more defects, 124% slower issue resolution
- ACM Research: Developers spend 58-70% of time comprehending code, only 5% editing
- Chalmers University: Developers waste 23% of development time due to technical debt
- Martin Fowler's Refactoring (22 code smells, 5 categories)
- Robert C. Martin's Clean Code (40+ heuristics across 6 categories)
- Luzkan Code Smells Catalog (56 cataloged smells)
- SonarSource Cognitive Complexity metric
- Various Reddit, HackerNews, StackOverflow community discussions

---

## 1. NAMING (24 frustrations)

### N01: Single-Letter Variables

- **Pattern**: Variables named `x`, `d`, `t`, `n` outside of trivial loop counters or math
- **Detectability**: EASY — regex `\b[a-z]\b` in declarations (with scope filtering)
- **Example**: `const d = getData(); const t = process(d); return t;`

### N02: Cryptic Abbreviations

- **Pattern**: Shortened names that require domain-specific knowledge: `usr`, `mgr`, `svc`, `dto`, `impl`, `ctx`
- **Detectability**: MEDIUM — dictionary lookup against known abbreviation lists
- **Example**: `const usrMgr = new SvcImpl(ctxPrvdr);`

### N03: Misleading Names

- **Pattern**: Name suggests one thing, code does another. A function `getUser()` that also modifies state
- **Detectability**: HARD — requires semantic understanding of name vs. behavior
- **Example**: `function getUser() { this.loginCount++; return this.user; }`

### N04: Hungarian Notation Remnants

- **Pattern**: Prefixing variables with type info: `strName`, `intCount`, `boolIsActive`, `arrItems`
- **Detectability**: EASY — regex for common prefixes `(str|int|bool|arr|obj|lst|dbl|flt)[A-Z]`
- **Example**: `let strUserName = "John"; let intAge = 25; let boolIsActive = true;`

### N05: Inconsistent Naming Convention

- **Pattern**: Mix of camelCase, snake_case, PascalCase, kebab-case in the same file/module
- **Detectability**: EASY — regex pattern matching for multiple conventions in same scope
- **Example**: `const user_name = x; const firstName = y; const LastName = z;`

### N06: Generic/Meaningless Names

- **Pattern**: Variables named `data`, `info`, `temp`, `result`, `value`, `item`, `stuff`, `thing`
- **Detectability**: EASY — dictionary of generic names
- **Example**: `const data = fetchData(); const result = processData(data); return result;`

### N07: Numbered Variables

- **Pattern**: Sequential numbered names that convey no meaning: `item1`, `item2`, `str1`, `str2`
- **Detectability**: EASY — regex `\w+\d+` in declarations
- **Example**: `const name1 = parts[0]; const name2 = parts[1]; const name3 = parts[2];`

### N08: Noise Words

- **Pattern**: Adding words that add no meaning: `UserData` vs `User`, `AccountInfo` vs `Account`, `theList`
- **Detectability**: MEDIUM — suffix/prefix detection against known noise words
- **Example**: `class ProductData { getProductInfo() { return this.productObject; } }`

### N09: Encoding Type in Name

- **Pattern**: Embedding type info that the type system already provides: `userList`, `nameString`, `countInt`
- **Detectability**: EASY — regex for common type suffixes
- **Example**: `const userArray: User[] = []; const nameString: string = "John";`

### N10: Negative Boolean Names

- **Pattern**: Boolean variables with negative names requiring double-negation to understand
- **Detectability**: MEDIUM — regex for `not`, `no`, `non`, `un`, `dis` prefixed booleans
- **Example**: `if (!isNotDisabled) { ... } // triple negation`

### N11: Abbreviation Inconsistency

- **Pattern**: Same concept abbreviated differently: `usr` in one place, `user` in another, `u` in a third
- **Detectability**: MEDIUM — cross-reference abbreviation usage across codebase
- **Example**: `function getUsr(userId) { return userRepository.findU(userId); }`

### N12: Overly Long Names

- **Pattern**: Names so long they hurt readability: `AbstractSingletonProxyFactoryBean`
- **Detectability**: EASY — length threshold (e.g., >40 chars)
- **Example**: `const userAccountPermissionValidationServiceFactory = new ...`

### N13: Names Differing Only by Case

- **Pattern**: Variables that differ only in capitalization, causing confusion
- **Detectability**: EASY — case-insensitive duplicate detection
- **Example**: `const user = getUser(); const User = new User(); const USER = "admin";`

### N14: Names Differing by Number

- **Pattern**: Copy-pasted variables with sequential numbers
- **Detectability**: EASY — regex pattern `(\w+)(\d+)` with multiple matches
- **Example**: `let result = calc(); let result2 = calc2(); let result3 = calc3();`

### N15: Misleading Type Names

- **Pattern**: Class/type name suggests wrong abstraction level or wrong behavior
- **Detectability**: HARD — requires semantic understanding
- **Example**: `class UserManager { // actually just a DTO with no management logic }`

### N16: Verb/Noun Confusion

- **Pattern**: Functions named as nouns, classes named as verbs
- **Detectability**: HARD — NLP analysis needed
- **Example**: `class Calculate { } function user() { }`

### N17: Domain Term Misuse

- **Pattern**: Using domain terms incorrectly or inconsistently with the ubiquitous language
- **Detectability**: HARD — requires domain knowledge
- **Example**: Using `order` when the domain calls it `requisition`

### N18: Shadowed Variables

- **Pattern**: Inner scope variable with same name as outer scope, hiding the outer value
- **Detectability**: EASY — scope analysis (most linters detect this)
- **Example**: `const name = "outer"; function f() { const name = "inner"; // shadows }`

### N19: Acronym Casing Inconsistency

- **Pattern**: Acronyms treated differently: `XMLParser` vs `XmlParser` vs `xmlParser`
- **Detectability**: EASY — regex for multiple adjacent capitals
- **Example**: `class HTTPSURLConnection { parseJSON(xmlHTTPRequest) {} }`

### N20: Method Names That Lie About Side Effects

- **Pattern**: Pure-sounding names on methods that mutate state
- **Detectability**: HARD — requires dataflow analysis
- **Example**: `function calculateTotal() { this.items = []; return 0; } // clears items!`

### N21: Context-Free Names in Exported APIs

- **Pattern**: Short names that only make sense within the module but are exported
- **Detectability**: MEDIUM — check exported symbol name lengths
- **Example**: `export function process(d) { ... } // process what? d = what?`

### N22: Boolean Function Not Phrased as Question

- **Pattern**: Boolean-returning functions not named as yes/no questions
- **Detectability**: MEDIUM — check return type vs. naming pattern
- **Example**: `function userAuth(user) { return user.token !== null; } // should be isAuthenticated`

### N23: Plural/Singular Confusion

- **Pattern**: Using plural name for single item or singular for collection
- **Detectability**: MEDIUM — cross-reference name with type
- **Example**: `const users = getUser(id); // returns single user`

### N24: Using Reserved/Common Names

- **Pattern**: Naming variables after built-in globals or commonly used library names
- **Detectability**: EASY — dictionary of reserved/common names
- **Example**: `const length = "hello"; const name = 42; const toString = false;`

---

## 2. COMPLEXITY (18 frustrations)

### CX01: Deep Nesting (Arrow/Pyramid Code)

- **Pattern**: Code nested 4+ levels deep with if/for/while/try blocks
- **Detectability**: EASY — indentation/bracket depth counting
- **Example**:

```javascript
if (a) {
  if (b) {
    for (let i of items) {
      if (c) {
        try {
          if (d) { // 5 levels deep
          }
        } catch(e) {}
      }
    }
  }
}
```

### CX02: Long Functions/Methods

- **Pattern**: Functions exceeding 30-50 lines (Robert C. Martin says <20)
- **Detectability**: EASY — line count per function
- **Example**: A 500-line `processOrder()` function

### CX03: God Class

- **Pattern**: Single class with too many responsibilities, fields, and methods (>500 lines, >20 methods)
- **Detectability**: EASY — metric thresholds (lines, methods, fields)
- **Example**: `class Application { // 3000 lines, handles DB, UI, logging, auth, email }`

### CX04: Complex Boolean Expressions

- **Pattern**: Compound conditions with 3+ operands, mixed AND/OR, nested ternaries
- **Detectability**: EASY — count operators in condition expressions
- **Example**: `if ((a && b) || (c && !d) || (e && f && (g || h))) { ... }`

### CX05: High Cyclomatic Complexity

- **Pattern**: Functions with many branching paths (>10 independent paths)
- **Detectability**: EASY — standard metric calculation
- **Example**: Function with 15 if/else branches, 3 loops, and switch statements

### CX06: High Cognitive Complexity (SonarQube)

- **Pattern**: Code that is hard for humans to follow, penalizing nesting and breaks in linear flow
- **Detectability**: EASY — SonarQube's cognitive complexity algorithm
- **Example**: Nested conditionals with breaks, continues, and early returns

### CX07: Switch/Case Explosion

- **Pattern**: Massive switch statements with 10+ cases, often duplicated across multiple functions
- **Detectability**: EASY — count case clauses per switch
- **Example**: `switch(type) { case 'A': ... case 'B': ... /* 25 more cases */ }`

### CX08: Nested Ternary Operators

- **Pattern**: Ternary expressions inside ternary expressions
- **Detectability**: EASY — regex for nested `? :` patterns
- **Example**: `const x = a ? (b ? (c ? 1 : 2) : 3) : (d ? 4 : 5);`

### CX09: Long Method Chains

- **Pattern**: Chains of 5+ method calls that are hard to debug and understand
- **Detectability**: EASY — count chained `.method()` calls
- **Example**: `data.filter(x => x.active).map(x => x.name).sort().slice(0,10).join(', ')`

### CX10: Multiple Return Statements

- **Pattern**: Functions with 5+ return points scattered throughout
- **Detectability**: EASY — count `return` statements per function
- **Example**: A function with returns in every if-branch, making flow hard to trace

### CX11: Large Files

- **Pattern**: Source files exceeding 500-1000 lines
- **Detectability**: EASY — line count per file
- **Example**: A 3000-line `utils.js` file

### CX12: Deep Inheritance Hierarchies

- **Pattern**: Class hierarchies 4+ levels deep
- **Detectability**: MEDIUM — parse class hierarchies
- **Example**: `class A extends B extends C extends D extends E { }`

### CX13: Complex Regular Expressions Without Comments

- **Pattern**: Long regex patterns with no explanation
- **Detectability**: EASY — regex length threshold
- **Example**: `/^(?:(?:(?:0?[13578]|1[02])(\/|-|\.)31)\1|(?:(?:0?[1,3-9]|1[0-2])(\/|-|\.)(?:29|30)\2))(?:(?:1[6-9]|[2-9]\d)?\d{2})$/`

### CX14: Combinatorial Explosion

- **Pattern**: Code doing almost the same thing with slight variations, creating exponential cases
- **Detectability**: HARD — requires similarity analysis
- **Example**: 20 methods that differ by one parameter each

### CX15: God Function

- **Pattern**: A single function that orchestrates everything, knows everything, calls everything
- **Detectability**: MEDIUM — fan-out metric (number of functions called)
- **Example**: `function main() { // calls 50+ other functions in sequence }`

### CX16: Deeply Nested Data Structures

- **Pattern**: Objects nested 5+ levels deep requiring long access chains
- **Detectability**: MEDIUM — property access depth analysis
- **Example**: `config.server.database.connection.pool.settings.maxRetries`

### CX17: Complex Lambda/Closure Bodies

- **Pattern**: Multi-line lambdas that should be named functions
- **Detectability**: EASY — line count inside lambda bodies
- **Example**: `items.map(item => { /* 30 lines of complex logic */ })`

### CX18: Mixed Levels of Abstraction

- **Pattern**: A function that mixes high-level orchestration with low-level detail
- **Detectability**: HARD — requires semantic understanding
- **Example**: `function processOrder() { validateUser(); const bytes = Buffer.from(data, 'utf8'); sendEmail(); }`

---

## 3. STRUCTURE (14 frustrations)

### ST01: Spaghetti Code

- **Pattern**: Tangled control flow with no clear structure, goto-like jumps, intertwined concerns
- **Detectability**: HARD — requires holistic analysis of control flow graphs
- **Example**: Functions calling each other in circular patterns with global state mutations

### ST02: Big Ball of Mud

- **Pattern**: No discernible architecture. Everything depends on everything, no module boundaries
- **Detectability**: MEDIUM — dependency graph analysis showing high coupling
- **Example**: All 200 files in a flat `src/` directory with every file importing from every other

### ST03: Circular Dependencies

- **Pattern**: Module A imports Module B which imports Module A
- **Detectability**: EASY — dependency graph cycle detection
- **Example**: `// a.ts: import { B } from './b'; // b.ts: import { A } from './a';`

### ST04: God Object

- **Pattern**: One object that knows about or controls too many things
- **Detectability**: MEDIUM — count dependencies and responsibilities
- **Example**: `class AppContext { db; cache; auth; logger; config; email; queue; /* 30 more */ }`

### ST05: Lasagna Code (Too Many Layers)

- **Pattern**: Excessive layering where every operation passes through 10+ layers of abstraction
- **Detectability**: MEDIUM — call depth analysis
- **Example**: Controller → Service → Manager → Repository → DAO → DataMapper → Connection → ...

### ST06: Ravioli Code (Too Many Tiny Pieces)

- **Pattern**: Hundreds of tiny classes/functions that individually make sense but are impossible to follow
- **Detectability**: MEDIUM — high file count with low lines-per-file ratio
- **Example**: 500 files averaging 15 lines each for a simple CRUD app

### ST07: Feature Scattered Across Files

- **Pattern**: Understanding one feature requires reading 15+ files across many directories
- **Detectability**: HARD — requires feature-to-file mapping
- **Example**: User login touches auth/, middleware/, routes/, services/, models/, utils/, config/, validators/

### ST08: Inappropriate Intimacy

- **Pattern**: Classes that excessively access each other's internal/private details
- **Detectability**: MEDIUM — analyze cross-class field/method access patterns
- **Example**: `class Order { getTotal() { return this.customer._internalBalance * this.product._rawCost; } }`

### ST09: Blob/Monolith Module

- **Pattern**: A single module/file that contains everything for a concern: types, logic, UI, data
- **Detectability**: EASY — file size and mixed concern indicators
- **Example**: A single 5000-line `app.js` containing routes, DB queries, templates, and utilities

### ST10: Divergent Change

- **Pattern**: One class that changes for many different reasons (violates SRP)
- **Detectability**: HARD — requires git history analysis of change reasons
- **Example**: A `User` class that changes when auth changes, when billing changes, when reporting changes

### ST11: Refused Bequest

- **Pattern**: Subclass inherits but doesn't use most parent methods, or overrides them with no-ops
- **Detectability**: MEDIUM — check override count vs. parent method count
- **Example**: `class Square extends Rectangle { setWidth(w) { /* ignore */ } setHeight(h) { /* ignore */ } }`

### ST12: Data Class (Anemic Domain Model)

- **Pattern**: Classes with only getters/setters, no behavior. Logic lives elsewhere
- **Detectability**: MEDIUM — ratio of data methods to behavior methods
- **Example**: `class User { name; email; getName() {} setName() {} getEmail() {} setEmail() {} }`

### ST13: Temporary Field

- **Pattern**: Object fields that are only set/used in certain situations
- **Detectability**: HARD — requires usage analysis across methods
- **Example**: `class Report { tempCalcResult; // only used by one method in specific conditions }`

### ST14: Parallel Inheritance Hierarchies

- **Pattern**: Every time you add a subclass to one hierarchy, you must add one to another
- **Detectability**: MEDIUM — detect hierarchies with matching subclass names
- **Example**: For every `XProcessor` there must be a matching `XValidator` and `XSerializer`

---

## 4. READABILITY (16 frustrations)

### RD01: Magic Numbers

- **Pattern**: Unexplained numeric literals in code
- **Detectability**: EASY — regex for numeric literals not assigned to named constants
- **Example**: `if (status === 3) { setTimeout(retry, 86400000); }`

### RD02: Magic Strings

- **Pattern**: Unexplained string literals used as identifiers or config
- **Detectability**: EASY — repeated string literals not in constants
- **Example**: `if (role === "admin_super_v2") { grantAccess("level_7"); }`

### RD03: Inconsistent Formatting

- **Pattern**: Mixed indentation (tabs/spaces), inconsistent bracing, varying line lengths
- **Detectability**: EASY — formatter/linter comparison
- **Example**: Mix of 2-space and 4-space indentation in same file

### RD04: Wall of Code (No Visual Breaks)

- **Pattern**: 50+ lines with no blank lines separating logical sections
- **Detectability**: EASY — detect long stretches without blank lines
- **Example**: A function that runs 80 lines with zero blank lines or section comments

### RD05: Obscured Intent

- **Pattern**: Clever/terse code that requires significant mental effort to understand
- **Detectability**: HARD — requires readability scoring
- **Example**: `return !!~arr.indexOf(x) ? arr.reduce((a,b) => a^b, 0) : void 0;`

### RD06: Clever/Tricky Code

- **Pattern**: Using language tricks, bitwise hacks, or obscure idioms when simpler alternatives exist
- **Detectability**: MEDIUM — detect known tricky patterns
- **Example**: `const isOdd = n => !!(n & 1); // instead of n % 2 !== 0`

### RD07: Inconsistent Error Return Patterns

- **Pattern**: Some functions throw, some return null, some return error objects, some return -1
- **Detectability**: MEDIUM — analyze return types across similar functions
- **Example**: `getUser()` returns null, `getOrder()` throws, `getProduct()` returns `{error: ...}`

### RD08: Vertical Separation

- **Pattern**: Variable declared far from where it's used
- **Detectability**: MEDIUM — measure distance between declaration and usage
- **Example**: Variable declared on line 5, first used on line 85

### RD09: Horizontal Density (Too Many Things Per Line)

- **Pattern**: Cramming multiple operations into one line
- **Detectability**: EASY — line length and statement count per line
- **Example**: `const [a, b] = [fn1(x), fn2(y)].map(r => r.data?.items?.filter(Boolean) ?? []);`

### RD10: Inconsistent Null Handling

- **Pattern**: Mixing null, undefined, empty string, 0, false as "no value" indicators
- **Detectability**: MEDIUM — detect mixed null/undefined/falsy checks
- **Example**: `if (x === null)` in one place, `if (!x)` in another, `if (x === undefined)` in a third

### RD11: Boolean Expression Not Encapsulated

- **Pattern**: Complex conditions inline instead of extracted to descriptively-named variables
- **Detectability**: MEDIUM — detect complex conditions not assigned to variables
- **Example**: `if (user.age > 18 && user.country === 'US' && !user.banned && user.verified) { ... }`

### RD12: Mixed Abstraction Levels

- **Pattern**: High-level business logic mixed with low-level implementation details in same function
- **Detectability**: HARD — requires semantic understanding
- **Example**: `function checkout() { validateCart(); socket.write(Buffer.from(JSON.stringify(order))); sendReceipt(); }`

### RD13: Implicit Type Coercion Reliance

- **Pattern**: Relying on language-specific type coercion rules
- **Detectability**: EASY — detect `==` instead of `===` (JS), or implicit conversions
- **Example**: `if (value == null)` or `if (arr.length)` or `'' + number`

### RD14: Dense Object/Array Literals

- **Pattern**: Huge inline object/array literals that span 50+ lines
- **Detectability**: EASY — measure literal expression size
- **Example**: A 200-line config object defined inline in a function call

### RD15: Inverted/Unintuitive Logic

- **Pattern**: Using double negation, inverted conditions, or counterintuitive flow
- **Detectability**: MEDIUM — detect `!!`, `!(!x)`, negated conditions with else
- **Example**: `if (!items.length === 0)` or `if (!(user !== null && user !== undefined))`

### RD16: Hardcoded File Paths / URLs

- **Pattern**: Absolute paths or URLs embedded directly in source code
- **Detectability**: EASY — regex for file paths and URLs
- **Example**: `const data = readFile('/Users/john/projects/app/data.json');`

---

## 5. FUNCTIONS (14 frustrations)

### FN01: Too Many Parameters

- **Pattern**: Functions with more than 3 parameters (Robert C. Martin says max 3)
- **Detectability**: EASY — count parameters per function
- **Example**: `function createUser(name, email, age, role, dept, manager, startDate, salary) { ... }`

### FN02: Flag Arguments

- **Pattern**: Boolean parameters that change function behavior
- **Detectability**: EASY — detect boolean parameters in function signatures
- **Example**: `function render(data, isAdmin, showHeader, includeFooter, useCache) { ... }`

### FN03: Side Effects

- **Pattern**: Function does more than its name suggests — modifies global state, writes files, etc.
- **Detectability**: HARD — requires dataflow analysis
- **Example**: `function validateEmail(email) { this.lastValidated = Date.now(); logToFile(email); return isValid(email); }`

### FN04: Output Parameters

- **Pattern**: Using parameters to return results instead of return values
- **Detectability**: MEDIUM — detect parameter mutation
- **Example**: `function getUsers(results) { results.push(...fetchedUsers); }`

### FN05: Mixed Return Types

- **Pattern**: Function returns different types depending on conditions
- **Detectability**: MEDIUM — analyze return statement types
- **Example**: `function getUser(id) { if (!id) return false; if (cached) return cachedUser; return fetchUser(id); }`

### FN06: Function Does Multiple Things

- **Pattern**: Function name suggests one action but performs several unrelated operations
- **Detectability**: HARD — requires semantic analysis
- **Example**: `function saveUser(user) { validate(user); user.updatedAt = now(); db.save(user); sendEmail(user); clearCache(); }`

### FN07: Long Parameter Lists of Same Type

- **Pattern**: Multiple parameters of the same type that can easily be swapped
- **Detectability**: MEDIUM — detect consecutive same-type parameters
- **Example**: `function setDimensions(width: number, height: number, depth: number, weight: number) {}`

### FN08: Data Clumps as Parameters

- **Pattern**: Same group of parameters passed together to many functions
- **Detectability**: MEDIUM — detect recurring parameter groups
- **Example**: `f(street, city, state, zip)` repeated across 10 functions

### FN09: Selector/Dispatch Functions

- **Pattern**: Functions that just dispatch to other functions based on a type parameter
- **Detectability**: MEDIUM — detect function with switch/if on first parameter
- **Example**: `function handle(type, data) { if (type === 'A') handleA(data); else if (type === 'B') handleB(data); ... }`

### FN10: Command-Query Violation

- **Pattern**: Functions that both modify state AND return a value
- **Detectability**: HARD — requires semantic analysis
- **Example**: `function pop() { this.count--; return this.items.shift(); }`

### FN11: Dead Parameters

- **Pattern**: Function parameters that are never used in the function body
- **Detectability**: EASY — parameter unused detection
- **Example**: `function process(data, options, callback) { return transform(data); /* options, callback unused */ }`

### FN12: Functions That Return Null

- **Pattern**: Returning null forces callers to check for null, propagating complexity
- **Detectability**: EASY — detect `return null` statements
- **Example**: `function findUser(id) { if (!exists) return null; } // every caller must check`

### FN13: Inconsistent Parameter Ordering

- **Pattern**: Similar functions with parameters in different orders
- **Detectability**: MEDIUM — compare parameter ordering across similar functions
- **Example**: `drawRect(x, y, width, height)` vs `fillRect(width, height, x, y)`

### FN14: Function Returning Error Code

- **Pattern**: Using return values (0, -1, error codes) instead of exceptions
- **Detectability**: EASY — detect numeric returns used as error indicators
- **Example**: `function save() { if (failed) return -1; if (partial) return 1; return 0; }`

---

## 6. ERROR HANDLING (12 frustrations)

### EH01: Swallowed/Empty Catch

- **Pattern**: Catching exceptions and doing nothing — silently hiding errors
- **Detectability**: EASY — detect empty catch blocks
- **Example**: `try { riskyOp(); } catch(e) { }`

### EH02: Generic Exception Catching

- **Pattern**: Catching `Exception` or `Error` base class instead of specific types
- **Detectability**: EASY — detect `catch(Exception)` or `catch(Error)`
- **Example**: `try { ... } catch(Exception e) { log(e); } // catches everything`

### EH03: Exception as Flow Control

- **Pattern**: Using try/catch for normal program flow instead of conditional checks
- **Detectability**: MEDIUM — detect try/catch around non-error-prone code
- **Example**: `try { return array[index]; } catch { return defaultValue; }`

### EH04: No Error Handling at All

- **Pattern**: Functions that can fail but have zero error handling
- **Detectability**: MEDIUM — detect calls to failable operations without try/catch
- **Example**: `const data = JSON.parse(userInput); const file = fs.readFileSync(path);`

### EH05: Rethrowing Without Context

- **Pattern**: Catching and rethrowing without adding information
- **Detectability**: EASY — detect `catch(e) { throw e; }` pattern
- **Example**: `try { ... } catch(e) { throw e; } // pointless catch`

### EH06: Logging and Rethrowing (Double Handling)

- **Pattern**: Logging an error AND rethrowing it, causing duplicate log entries
- **Detectability**: EASY — detect `log` + `throw` in same catch block
- **Example**: `catch(e) { logger.error(e); throw e; } // logged twice when caller also logs`

### EH07: String-Only Error Messages

- **Pattern**: Throwing plain strings instead of Error objects with stack traces
- **Detectability**: EASY — detect `throw "message"` or `throw 'message'`
- **Example**: `throw "Something went wrong"; // no stack trace, no type`

### EH08: Error Information Leak

- **Pattern**: Exposing stack traces, internal paths, or SQL errors to end users
- **Detectability**: MEDIUM — detect error details in response payloads
- **Example**: `res.send(500, { error: err.stack }); // exposes internals`

### EH09: Checked Exception Abuse

- **Pattern**: Declaring too many checked exceptions forcing callers into catch-all patterns
- **Detectability**: EASY — count throws declarations per method (Java)
- **Example**: `void process() throws IOException, SQLException, ParseException, AuthException { ... }`

### EH10: Null Return Instead of Exception

- **Pattern**: Returning null when an exception would be more appropriate
- **Detectability**: MEDIUM — detect null returns in error paths
- **Example**: `function divide(a, b) { if (b === 0) return null; } // hides the error`

### EH11: Catch-Log-Ignore Pattern

- **Pattern**: Catching, logging, and then continuing as if nothing happened
- **Detectability**: EASY — detect catch block with only a log statement
- **Example**: `catch(e) { console.log(e.message); } // continues with corrupt state`

### EH12: Inconsistent Error Handling Strategy

- **Pattern**: Some functions use exceptions, some use error codes, some use Result types
- **Detectability**: MEDIUM — cross-module error handling pattern analysis
- **Example**: Module A throws, Module B returns `{ok, error}`, Module C returns -1

---

## 7. DUPLICATION (10 frustrations)

### DU01: Copy-Paste Code (Exact Clones)

- **Pattern**: Identical or near-identical code blocks in multiple locations
- **Detectability**: EASY — clone detection tools (token-based or AST-based)
- **Example**: Same 20-line validation function copy-pasted into 5 controllers

### DU02: Structural Duplication

- **Pattern**: Same algorithm structure with different data types or slight variations
- **Detectability**: MEDIUM — structural similarity analysis
- **Example**: `processUserOrder()` and `processGuestOrder()` with 90% identical logic

### DU03: Shotgun Surgery

- **Pattern**: One logical change requires modifications in many unrelated files
- **Detectability**: HARD — requires git history analysis of co-changed files
- **Example**: Adding a new field requires changes in 15 files across 8 directories

### DU04: Oddball Solution

- **Pattern**: Same problem solved in different ways in different parts of the codebase
- **Detectability**: MEDIUM — detect similar code with different implementations
- **Example**: Date formatting done with 3 different libraries in 3 modules

### DU05: Duplicated Conditional Logic

- **Pattern**: Same conditional checks repeated in multiple functions
- **Detectability**: MEDIUM — detect repeated condition patterns
- **Example**: `if (user && user.isActive && user.role === 'admin')` in 20 places

### DU06: Duplicated Error Handling

- **Pattern**: Same try/catch pattern repeated around every operation
- **Detectability**: EASY — detect identical catch block patterns
- **Example**: Every route handler wrapping with the same try/catch/log/respond pattern

### DU07: Parallel Class Hierarchies

- **Pattern**: Mirrored hierarchies where adding to one requires adding to the other
- **Detectability**: MEDIUM — detect parallel class name patterns
- **Example**: `OrderProcessor/OrderValidator/OrderSerializer` + `PaymentProcessor/PaymentValidator/PaymentSerializer`

### DU08: Configuration Duplication

- **Pattern**: Same configuration values repeated in multiple config files or locations
- **Detectability**: EASY — detect identical values across config files
- **Example**: Database connection string in 4 different .env files

### DU09: Test Code Duplication

- **Pattern**: Test setup, assertions, or test data repeated across test files
- **Detectability**: EASY — clone detection in test directories
- **Example**: Same 30-line mock setup in every test file

### DU10: Cross-Module Copy-Paste

- **Pattern**: Utility functions reimplemented in multiple modules instead of shared
- **Detectability**: MEDIUM — cross-module similarity analysis
- **Example**: `formatDate()` implemented 4 different ways in 4 different services

---

## 8. COUPLING (12 frustrations)

### CO01: Feature Envy

- **Pattern**: Method uses more data/methods from another class than its own
- **Detectability**: MEDIUM — analyze cross-class access patterns
- **Example**: `class Order { getDiscount() { return this.customer.loyalty * this.customer.years * this.customer.tier; } }`

### CO02: Inappropriate Intimacy

- **Pattern**: Classes accessing each other's private/internal details
- **Detectability**: MEDIUM — detect direct field access across classes
- **Example**: `class A { doStuff() { this.b._privateField = 42; this.b._internalMethod(); } }`

### CO03: Message Chains (Train Wreck)

- **Pattern**: Long chains of method calls: `a.getB().getC().getD().doThing()`
- **Detectability**: EASY — count chained method calls
- **Example**: `order.getCustomer().getAddress().getCity().getZipCode().format()`

### CO04: Middle Man

- **Pattern**: Class that delegates almost all work to another class
- **Detectability**: MEDIUM — detect classes where >50% of methods just delegate
- **Example**: `class UserService { getUser(id) { return this.repo.getUser(id); } save(u) { return this.repo.save(u); } }`

### CO05: Tight Coupling to Implementation

- **Pattern**: Depending on concrete classes instead of interfaces/abstractions
- **Detectability**: MEDIUM — detect concrete class imports vs interface imports
- **Example**: `constructor(private db: PostgresDatabase)` instead of `constructor(private db: Database)`

### CO06: Connascence of Timing

- **Pattern**: Methods must be called in a specific order that isn't enforced by the API
- **Detectability**: HARD — requires temporal analysis
- **Example**: Must call `init()` before `connect()` before `authenticate()` before `query()`

### CO07: Law of Demeter Violation

- **Pattern**: Object talks to strangers — accesses objects obtained through other objects
- **Detectability**: MEDIUM — detect nested property access chains
- **Example**: `this.department.manager.assistant.scheduleFor(meeting)`

### CO08: Global Coupling

- **Pattern**: Multiple modules depend on shared global state
- **Detectability**: EASY — detect global variable access from multiple modules
- **Example**: `window.appState.user.permissions` accessed from 30 different files

### CO09: Stamp Coupling

- **Pattern**: Passing large objects when only a few fields are needed
- **Detectability**: MEDIUM — detect parameter field access ratio
- **Example**: `function greet(user) { return "Hi " + user.name; } // only needs name, gets entire user`

### CO10: Framework Coupling

- **Pattern**: Business logic directly depending on framework-specific types/decorators
- **Detectability**: MEDIUM — detect framework imports in domain/business logic files
- **Example**: Domain model classes with `@Entity`, `@Column` decorators mixed with business rules

### CO11: Afferent/Efferent Coupling Imbalance

- **Pattern**: A module that imports from 20+ other modules (high efferent) or is imported by 20+ (high afferent)
- **Detectability**: EASY — count import/imported-by per module
- **Example**: `utils.js` imported by 95% of the codebase

### CO12: Hidden Coupling Through Data

- **Pattern**: Modules coupled through shared data formats, magic strings, or conventions
- **Detectability**: HARD — requires semantic analysis
- **Example**: Two services communicating through a shared JSON format that isn't formally defined

---

## 9. COMMENTS (12 frustrations)

### CM01: Commented-Out Code

- **Pattern**: Old code left as comments instead of being deleted (that's what git is for)
- **Detectability**: EASY — detect code-like patterns inside comments
- **Example**: `// const oldValue = calculateLegacy(x); // if (useOldMethod) { return oldValue; }`

### CM02: Obvious/Redundant Comments

- **Pattern**: Comments that say exactly what the code says
- **Detectability**: MEDIUM — NLP comparison of comment vs. code
- **Example**: `i++; // increment i` or `return result; // return the result`

### CM03: Misleading/Stale Comments

- **Pattern**: Comments that describe what the code used to do, not what it currently does
- **Detectability**: HARD — requires comparing comment semantics to code behavior
- **Example**: `// returns null if not found` above a function that now throws an exception

### CM04: TODO/FIXME/HACK Rot

- **Pattern**: TODO comments that have been in the codebase for months or years
- **Detectability**: EASY — detect TODO/FIXME/HACK/XXX comments, cross-ref with git blame dates
- **Example**: `// TODO: fix this properly (added 3 years ago)`

### CM05: Journal Comments

- **Pattern**: Comments tracking change history that should be in git commits
- **Detectability**: EASY — detect date/author patterns in comments
- **Example**: `// 2021-03-15 John: Added validation // 2021-04-02 Jane: Fixed edge case`

### CM06: Closing Brace Comments

- **Pattern**: Comments marking what a closing brace belongs to (sign of too-deep nesting)
- **Detectability**: EASY — regex `} // end (if|for|while|function|class)`
- **Example**: `} // end if (user is admin) } // end for each order } // end processOrders`

### CM07: Attribution/Byline Comments

- **Pattern**: Comments noting who wrote what (use git blame instead)
- **Detectability**: EASY — detect `@author`, `Added by`, `Written by` patterns
- **Example**: `// Created by John Smith on 2021-03-15`

### CM08: Commented Imports

- **Pattern**: Imports that are commented out "just in case"
- **Detectability**: EASY — detect import/require statements in comments
- **Example**: `// import { unusedUtil } from './utils';`

### CM09: Excessive JSDoc on Internal Code

- **Pattern**: Verbose JSDoc with @param, @returns for obvious private methods
- **Detectability**: MEDIUM — detect JSDoc on private/internal methods with self-documenting names
- **Example**: `/** @param {string} name - The name @returns {string} The greeting */ function greet(name) { return "Hi " + name; }`

### CM10: Comment Instead of Better Naming

- **Pattern**: Adding a comment to explain what a variable/function does instead of renaming it
- **Detectability**: HARD — requires NLP analysis
- **Example**: `const d = 86400; // seconds in a day` instead of `const SECONDS_PER_DAY = 86400;`

### CM11: Separator/Banner Comments

- **Pattern**: `//////////` or `// ===== SECTION =====` style dividers indicating the file should be split
- **Detectability**: EASY — regex for repeated separator characters in comments
- **Example**: `// ==================== VALIDATION =====================`

### CM12: Legal Boilerplate Overwhelming Code

- **Pattern**: License/legal comments that are longer than the actual code
- **Detectability**: EASY — ratio of comment lines to code lines at top of file
- **Example**: 40-line copyright header on a 10-line utility file

---

## 10. TESTS (14 frustrations)

### TS01: No Tests

- **Pattern**: Code with zero test coverage
- **Detectability**: EASY — check for test files, coverage reports
- **Example**: A project with zero test files

### TS02: Testing Implementation Not Behavior

- **Pattern**: Tests that break when internal implementation changes even if behavior is unchanged
- **Detectability**: HARD — requires semantic analysis of what's being asserted
- **Example**: Testing that a specific private method was called rather than the output

### TS03: Test Names That Don't Describe

- **Pattern**: Test names like `test1`, `testFunction`, `itWorks`
- **Detectability**: EASY — regex for generic test names
- **Example**: `test('test1', () => { ... })` or `it('works', () => { ... })`

### TS04: Assertion Roulette

- **Pattern**: Multiple assertions in one test without clear messages
- **Detectability**: EASY — count assertions per test
- **Example**: `expect(a).toBe(1); expect(b).toBe(2); expect(c).toBe(3); // which one failed?`

### TS05: Mystery Guest

- **Pattern**: Test depends on external data (files, DB state) not visible in the test
- **Detectability**: MEDIUM — detect file/DB access in tests without setup
- **Example**: `test('parses data', () => { const result = parse('fixtures/data.json'); ... })`

### TS06: Excessive Mocking

- **Pattern**: Tests that mock everything, testing nothing real
- **Detectability**: MEDIUM — count mocks per test
- **Example**: A test mocking 8 dependencies to test a single function

### TS07: Flaky Tests

- **Pattern**: Tests that sometimes pass and sometimes fail (often timing-dependent)
- **Detectability**: IMPOSSIBLE — only detectable by running tests multiple times
- **Example**: Tests relying on `setTimeout`, network calls, or random data

### TS08: Slow Tests

- **Pattern**: Unit tests taking seconds (should be milliseconds)
- **Detectability**: EASY — measure test execution time
- **Example**: A "unit" test that starts a database and HTTP server

### TS09: Test-to-Code Ratio Imbalance

- **Pattern**: 10x more test code than production code, or zero tests
- **Detectability**: EASY — line count ratio
- **Example**: 500 lines of test setup for a 20-line function

### TS10: God Test

- **Pattern**: Single test that tests everything — setup, execution, 15 assertions
- **Detectability**: EASY — test size and assertion count
- **Example**: A 200-line test function with 30 assertions

### TS11: Conditional Logic in Tests

- **Pattern**: If/else statements inside test code
- **Detectability**: EASY — detect conditionals inside test functions
- **Example**: `test('x', () => { if (env === 'ci') { expect(...) } else { expect(...) } })`

### TS12: Commented-Out Tests

- **Pattern**: Tests that were disabled by commenting rather than proper skip/pending
- **Detectability**: EASY — detect test patterns inside comments
- **Example**: `// it('should validate email', () => { ... })`

### TS13: Test Without Assertions

- **Pattern**: A test that runs code but never asserts anything
- **Detectability**: EASY — detect test functions with no assert/expect calls
- **Example**: `test('creates user', () => { createUser('test'); }); // no assertion`

### TS14: Fragile Test Fixtures

- **Pattern**: Tests sharing mutable fixtures that make tests order-dependent
- **Detectability**: MEDIUM — detect shared state in test files
- **Example**: `let sharedUser; beforeAll(() => { sharedUser = createUser(); }); // mutated by tests`

---

## 11. TYPES (12 frustrations)

### TY01: Any Type Abuse

- **Pattern**: Excessive use of `any` in TypeScript defeating the type system
- **Detectability**: EASY — count `any` type annotations
- **Example**: `function process(data: any): any { return data.map((x: any) => x.value as any); }`

### TY02: Stringly-Typed Code

- **Pattern**: Using strings where enums, types, or constants should be used
- **Detectability**: MEDIUM — detect string comparisons for known categorical values
- **Example**: `if (status === "pending_review_v2") { ... } if (type === "premium_gold") { ... }`

### TY03: Primitive Obsession

- **Pattern**: Using primitives (string, number) when a value object would be safer
- **Detectability**: MEDIUM — detect common value types represented as primitives
- **Example**: `function transfer(fromAccount: string, toAccount: string, amount: number, currency: string) {}`

### TY04: Type Assertion Abuse (as/cast)

- **Pattern**: Excessive use of `as Type` to override the type checker
- **Detectability**: EASY — count type assertions
- **Example**: `const user = response.data as any as User; const el = document.getElementById('x') as HTMLInputElement;`

### TY05: Using `object` or `{}` as Type

- **Pattern**: Using the most generic object type instead of defining proper interfaces
- **Detectability**: EASY — detect `object` or `{}` type annotations
- **Example**: `function process(config: object) { ... } // no idea what shape`

### TY06: Union Type Explosion

- **Pattern**: Union types so large they're meaningless: `string | number | boolean | null | undefined | object`
- **Detectability**: EASY — count members in union types
- **Example**: `type Response = Success | Failure | Pending | Cancelled | Timeout | Unknown | Retry | ...`

### TY07: Optional Everything

- **Pattern**: Making every field optional instead of defining proper types for each state
- **Detectability**: EASY — ratio of optional to required fields
- **Example**: `interface User { name?: string; email?: string; id?: number; role?: string; }`

### TY08: Type-Unsafe Collections

- **Pattern**: Using untyped arrays or maps for structured data
- **Detectability**: EASY — detect `any[]`, `Map<string, any>`, `Record<string, any>`
- **Example**: `const users: any[] = []; const config: Record<string, any> = {};`

### TY09: Discriminated Union Without Exhaustive Check

- **Pattern**: Switch on a union type without handling all cases
- **Detectability**: MEDIUM — detect switch on union type without default/exhaustive
- **Example**: `switch (action.type) { case 'ADD': ... case 'REMOVE': ... /* missing UPDATE, CLEAR */ }`

### TY10: Implicit Any (noImplicitAny: false)

- **Pattern**: TypeScript configured to allow implicit `any`, defeating type safety
- **Detectability**: EASY — check tsconfig.json
- **Example**: `function process(data) { ... } // data is implicitly any`

### TY11: Type Guards Missing

- **Pattern**: Accessing properties on union types without narrowing
- **Detectability**: MEDIUM — detect property access on union types
- **Example**: `function handle(input: string | number) { return input.toFixed(2); } // string doesn't have toFixed`

### TY12: Overloaded Return Types

- **Pattern**: Function return type changes based on input type in confusing ways
- **Detectability**: MEDIUM — detect functions with multiple return type annotations
- **Example**: `function parse(input: string): number; function parse(input: number): string;`

---

## 12. ASYNC (12 frustrations)

### AS01: Callback Hell (Pyramid of Doom)

- **Pattern**: Deeply nested callbacks creating rightward-drifting code
- **Detectability**: EASY — indentation depth in callback patterns
- **Example**:

```javascript
getData(function(a) {
  getMoreData(a, function(b) {
    getEvenMore(b, function(c) {
      getYetMore(c, function(d) {
        // 4 levels deep
      });
    });
  });
});
```

### AS02: Unhandled Promise Rejection

- **Pattern**: Promises without `.catch()` or missing await in try/catch
- **Detectability**: EASY — detect promise chains without `.catch()`, or unhandled async
- **Example**: `fetchData().then(process); // no .catch()`

### AS03: Mixing Async Patterns

- **Pattern**: Mixing callbacks, promises, and async/await in the same module
- **Detectability**: MEDIUM — detect multiple async patterns in same file
- **Example**: File uses `callback(err, data)`, `.then()`, and `async/await` interchangeably

### AS04: Async/Await in Loop

- **Pattern**: Sequential await inside a loop when parallel execution would work
- **Detectability**: MEDIUM — detect await inside for/while loops
- **Example**: `for (const id of ids) { const data = await fetch(id); } // serial, should be Promise.all`

### AS05: Fire and Forget Async

- **Pattern**: Calling async function without awaiting — no error handling, no ordering guarantee
- **Detectability**: EASY — detect async function calls without `await`
- **Example**: `saveToDatabase(data); // forgot await, errors swallowed`

### AS06: Promise Constructor Anti-Pattern

- **Pattern**: Wrapping an already-promise-returning function in `new Promise()`
- **Detectability**: MEDIUM — detect `new Promise` wrapping another promise
- **Example**: `new Promise((resolve) => { fetch(url).then(data => resolve(data)); })`

### AS07: Race Conditions

- **Pattern**: Multiple async operations modifying shared state without synchronization
- **Detectability**: HARD — requires concurrency analysis
- **Example**: Two event handlers both reading and writing to the same variable

### AS08: Dangling Promises in Express/HTTP Handlers

- **Pattern**: Express route handler returns before async operations complete
- **Detectability**: MEDIUM — detect non-awaited async calls in route handlers
- **Example**: `app.get('/data', (req, res) => { fetchData().then(d => res.send(d)); }); // no error handling`

### AS09: Callback Error Not Checked

- **Pattern**: Node.js callback without checking the error parameter
- **Detectability**: EASY — detect callback functions that ignore first parameter
- **Example**: `fs.readFile(path, (err, data) => { process(data); }); // err ignored`

### AS10: Unnecessary Async

- **Pattern**: Functions marked async that never await anything
- **Detectability**: EASY — detect async functions without await
- **Example**: `async function add(a, b) { return a + b; } // why async?`

### AS11: Blocking the Event Loop

- **Pattern**: Synchronous CPU-intensive operations in Node.js event loop
- **Detectability**: MEDIUM — detect sync I/O or heavy computation in async contexts
- **Example**: `app.get('/report', (req, res) => { const result = heavyComputation(); }); // blocks all requests`

### AS12: Thenable Confusion

- **Pattern**: Mixing `.then()` chains with async/await in the same function
- **Detectability**: EASY — detect both `await` and `.then()` in same function
- **Example**: `async function load() { const a = await getA(); getB().then(b => { ... }); }`

---

## 13. STATE (10 frustrations)

### SA01: Global Mutable State

- **Pattern**: Variables in global/module scope that are mutated by multiple functions
- **Detectability**: EASY — detect global `let`/`var` declarations that are reassigned
- **Example**: `let currentUser = null; function login(u) { currentUser = u; } function logout() { currentUser = null; }`

### SA02: Hidden State Changes

- **Pattern**: Functions that modify state not visible from the call site
- **Detectability**: HARD — requires dataflow analysis
- **Example**: `function calculateTax(order) { order.items.forEach(i => i.price *= 1.1); } // mutates items!`

### SA03: Temporal Coupling

- **Pattern**: Functions that must be called in a specific order but nothing enforces it
- **Detectability**: HARD — requires usage pattern analysis
- **Example**: `obj.init(); obj.configure(); obj.start(); // calling out of order silently fails`

### SA04: Shared Mutable State Between Threads/Modules

- **Pattern**: State accessed by multiple concurrent actors without synchronization
- **Detectability**: HARD — requires concurrency analysis
- **Example**: Multiple request handlers reading/writing to a shared in-memory cache

### SA05: Singleton Abuse

- **Pattern**: Singletons used as global state containers, making testing impossible
- **Detectability**: MEDIUM — detect singleton patterns
- **Example**: `Database.getInstance().query(...)` used directly in business logic

### SA06: State Machine Without Explicit States

- **Pattern**: Object state managed through multiple booleans instead of explicit state machine
- **Detectability**: MEDIUM — detect multiple related boolean flags
- **Example**: `isLoading: false, isError: false, isSuccess: false, isIdle: true // what if isLoading && isError?`

### SA07: Mutable Default Parameters

- **Pattern**: Using mutable objects as default parameter values (Python classic)
- **Detectability**: EASY — detect mutable defaults in function signatures
- **Example**: `def append_to(element, to=[]): to.append(element); return to`

### SA08: Variable Reassignment in Long Functions

- **Pattern**: Variable reassigned multiple times in a long function, hard to track current value
- **Detectability**: MEDIUM — count reassignments per variable in scope
- **Example**: `let result = 0; /* 50 lines later */ result = calc(); /* 30 more lines */ result = result + adj;`

### SA09: Implicit State via Closure

- **Pattern**: Functions capturing and modifying outer scope variables, hiding state
- **Detectability**: MEDIUM — detect closures that modify captured variables
- **Example**: `let count = 0; function increment() { count++; } // hidden dependency`

### SA10: Stateful Utility Classes

- **Pattern**: Utility/helper classes that hold state instead of being pure functions
- **Detectability**: MEDIUM — detect state (fields) in utility/helper classes
- **Example**: `class StringUtils { lastConverted = ""; capitalize(s) { this.lastConverted = s; ... } }`

---

## 14. DEPENDENCIES (10 frustrations)

### DP01: Too Many Imports

- **Pattern**: File importing from 15+ different modules
- **Detectability**: EASY — count import statements per file
- **Example**: A file with 25 import statements at the top

### DP02: Circular Imports

- **Pattern**: Modules that import each other creating cycles
- **Detectability**: EASY — dependency graph cycle detection
- **Example**: `user.ts` imports from `order.ts` which imports from `user.ts`

### DP03: Deep Dependency Chains

- **Pattern**: Module depends on module that depends on module... 10+ levels deep
- **Detectability**: MEDIUM — dependency tree depth analysis
- **Example**: Installing one npm package adds 500 transitive dependencies

### DP04: Unused Dependencies

- **Pattern**: Packages in package.json/pom.xml that are never imported or used
- **Detectability**: EASY — cross-reference imports with dependency list
- **Example**: `"lodash": "^4.17.21"` in package.json but never imported

### DP05: Unpinned/Loose Dependency Versions

- **Pattern**: Using `^`, `~`, `*` in dependency versions allowing unexpected updates
- **Detectability**: EASY — regex for version range operators
- **Example**: `"react": "^18.0.0"` instead of `"react": "18.2.0"`

### DP06: Dependency on Implementation Details

- **Pattern**: Using internal/undocumented APIs of a dependency
- **Detectability**: MEDIUM — detect imports from internal paths
- **Example**: `import { _internal } from 'library/dist/internal/utils';`

### DP07: Multiple Libraries for Same Purpose

- **Pattern**: Using Moment.js AND date-fns AND dayjs in the same project
- **Detectability**: MEDIUM — detect overlapping library functionality
- **Example**: Both `lodash` and `underscore` in dependencies

### DP08: Vendor Lock-in Through Deep Integration

- **Pattern**: Business logic tightly integrated with cloud-specific SDK calls
- **Detectability**: MEDIUM — detect cloud SDK imports in business logic
- **Example**: `import { DynamoDB } from 'aws-sdk'` directly in domain services

### DP09: Barrel File Explosion

- **Pattern**: `index.ts` re-exporting everything causing circular imports and slow builds
- **Detectability**: EASY — detect large barrel files with many re-exports
- **Example**: `export * from './a'; export * from './b'; /* 50 more */`

### DP10: Importing Entire Library for One Function

- **Pattern**: Importing a large library to use a single utility function
- **Detectability**: MEDIUM — detect library imports vs. actual usage
- **Example**: `import _ from 'lodash'; const x = _.get(obj, 'a.b.c');`

---

## 15. PATTERNS (12 frustrations)

### PT01: Over-Engineering

- **Pattern**: Using complex patterns (factory of factories, strategy, observer) for simple problems
- **Detectability**: MEDIUM — detect design patterns applied to simple code
- **Example**: An `AbstractUserFactoryBuilderStrategy` for a 2-table CRUD app

### PT02: Premature Abstraction

- **Pattern**: Creating abstractions before understanding the domain, leading to wrong abstractions
- **Detectability**: HARD — requires semantic analysis
- **Example**: Interface with single implementation, created "for future extensibility"

### PT03: Cargo Cult Coding

- **Pattern**: Including patterns/code because "that's how it's done" without understanding why
- **Detectability**: HARD — requires intent analysis
- **Example**: Adding dependency injection, repositories, and services for a 50-line script

### PT04: Gold Plating

- **Pattern**: Adding features, flexibility, or "nice-to-haves" that nobody asked for
- **Detectability**: HARD — requires requirements comparison
- **Example**: Building a plugin system for an internal tool with 3 users

### PT05: Speculative Generality

- **Pattern**: Creating abstract classes, interfaces, or hooks "just in case"
- **Detectability**: MEDIUM — detect interfaces with single implementation
- **Example**: `interface IUserRepository` with only `class UserRepository implements IUserRepository`

### PT06: Wrong Pattern for Problem

- **Pattern**: Applying Singleton when Dependency Injection is needed, or Observer when Callback suffices
- **Detectability**: HARD — requires architectural analysis
- **Example**: Using the Strategy pattern for a simple if/else with 2 branches

### PT07: Pattern Mania (Everything is a Pattern)

- **Pattern**: Naming and structuring everything as a formal design pattern
- **Detectability**: MEDIUM — detect excessive pattern-named classes
- **Example**: `UserFactory`, `UserBuilder`, `UserStrategy`, `UserObserver`, `UserMediator` for a User CRUD

### PT08: Architecture Astronaut

- **Pattern**: Building infrastructure and frameworks instead of solving the actual problem
- **Detectability**: HARD — ratio of infrastructure code to business code
- **Example**: 3 months building a "flexible event system" for a TODO app

### PT09: Reinventing the Wheel

- **Pattern**: Building custom implementations when standard library or well-tested packages exist
- **Detectability**: MEDIUM — detect custom implementations of common algorithms
- **Example**: Custom date parsing, custom HTTP client, custom UUID generator

### PT10: Interface Bloat

- **Pattern**: Interfaces with too many methods, violating Interface Segregation
- **Detectability**: EASY — count methods per interface
- **Example**: `interface Repository { find; findAll; save; delete; count; aggregate; batch; export; import; migrate; }`

### PT11: Inheritance Over Composition

- **Pattern**: Using class inheritance to share code when composition would be simpler
- **Detectability**: MEDIUM — detect deep inheritance + limited override
- **Example**: `class AdminButton extends Button extends Component extends BaseElement`

### PT12: Premature Optimization

- **Pattern**: Optimizing code before profiling shows it's actually a bottleneck
- **Detectability**: HARD — requires performance context
- **Example**: Hand-optimized loop with bitwise operations for a function called once per request

---

## 16. DOCUMENTATION (10 frustrations)

### DC01: No README

- **Pattern**: Project with no README.md or an empty/default one
- **Detectability**: EASY — check for README file existence and content
- **Example**: A repository with no README.md

### DC02: Outdated Documentation

- **Pattern**: Docs describing old API, old architecture, or removed features
- **Detectability**: MEDIUM — compare doc references to actual code
- **Example**: README says "run `make build`" but project now uses `npm run build`

### DC03: No Setup/Install Instructions

- **Pattern**: New developer can't get the project running without tribal knowledge
- **Detectability**: EASY — check README for setup sections
- **Example**: README has no "Getting Started", "Installation", or "Setup" section

### DC04: No API Documentation

- **Pattern**: Public APIs with no docs on endpoints, parameters, or responses
- **Detectability**: EASY — check for API doc files or doc comments on public methods
- **Example**: REST API with 50 endpoints and no Swagger/OpenAPI spec

### DC05: Documentation in Wrong Place

- **Pattern**: Critical info buried in comments, Slack messages, or wiki pages nobody reads
- **Detectability**: HARD — requires organizational analysis
- **Example**: Deployment process only documented in a year-old Slack thread

### DC06: No Code Examples

- **Pattern**: Library/API documentation without usage examples
- **Detectability**: EASY — scan docs for code block presence
- **Example**: A README that lists available functions but shows no example code

### DC07: Wrong/Broken Examples

- **Pattern**: Documentation examples that don't actually work with the current version
- **Detectability**: MEDIUM — attempt to compile/run doc examples
- **Example**: `npm install old-package-name` in docs when package was renamed

### DC08: Missing Architecture Documentation

- **Pattern**: No high-level overview of system components and their relationships
- **Detectability**: EASY — check for architecture docs (diagrams, ADRs)
- **Example**: A microservices system with no diagram showing service interactions

### DC09: Missing Changelog

- **Pattern**: No record of what changed between versions
- **Detectability**: EASY — check for CHANGELOG.md
- **Example**: Version bumps from 1.0 to 5.0 with no changelog

### DC10: Self-Referential Documentation

- **Pattern**: Docs that reference other docs that reference other docs without answering the question
- **Detectability**: HARD — requires content analysis
- **Example**: "For details, see [link]" → "For details, see [other link]" → "For details, see [original link]"

---

## 17. GIT (10 frustrations)

### GI01: Huge/Mega Commits

- **Pattern**: Single commit with 50+ files changed, mixing multiple concerns
- **Detectability**: EASY — count files changed per commit
- **Example**: "Updated everything" commit touching 200 files

### GI02: Meaningless Commit Messages

- **Pattern**: `fix`, `update`, `stuff`, `wip`, `asdf`, `changes`
- **Detectability**: EASY — regex for known bad messages, length check
- **Example**: `git commit -m "fix"` or `git commit -m "stuff"`

### GI03: Long-Lived Feature Branches

- **Pattern**: Branches diverged from main for weeks/months, causing merge hell
- **Detectability**: EASY — check branch age and divergence
- **Example**: A feature branch 3 months old with 500 commits behind main

### GI04: Direct Commits to Main

- **Pattern**: Pushing directly to main/master without review
- **Detectability**: EASY — check branch protection and commit history
- **Example**: 50 direct pushes to main in a week

### GI05: Committed Secrets

- **Pattern**: API keys, passwords, tokens committed to repository
- **Detectability**: EASY — secret scanning regex patterns
- **Example**: `.env` file with `AWS_SECRET_KEY=AKIA...` committed

### GI06: Giant Binary Files in Git

- **Pattern**: Large binaries (images, builds, datasets) committed to git
- **Detectability**: EASY — file size check in git
- **Example**: 500MB database dump committed alongside source code

### GI07: Merge Commit Pollution

- **Pattern**: History cluttered with merge commits instead of rebasing
- **Detectability**: EASY — count merge commits vs. regular commits
- **Example**: `Merge branch 'main' into feature` appearing every 3 commits

### GI08: No .gitignore

- **Pattern**: Missing or incomplete .gitignore causing build artifacts, IDE files, etc. to be tracked
- **Detectability**: EASY — check .gitignore existence and coverage
- **Example**: `node_modules/`, `.DS_Store`, `*.class` files committed

### GI09: Squash-Merge Losing Context

- **Pattern**: Squash merging a 50-commit PR into one commit, losing all intermediate context
- **Detectability**: MEDIUM — detect large squash merges
- **Example**: 3 weeks of work compressed into "feat: add user management"

### GI10: Mixed Concerns in One Commit

- **Pattern**: One commit that includes a feature, a bug fix, a refactor, and a config change
- **Detectability**: MEDIUM — analyze file types and paths in a commit
- **Example**: A commit touching route handlers, database migrations, CSS files, and package.json

---

## 18. CONFIG (10 frustrations)

### CF01: Hardcoded Configuration Values

- **Pattern**: Port numbers, URLs, timeouts embedded directly in code
- **Detectability**: EASY — detect common config patterns as literals
- **Example**: `const API_URL = "https://api.production.com"; const PORT = 3000;`

### CF02: Scattered Configuration

- **Pattern**: Config values spread across many files instead of centralized
- **Detectability**: MEDIUM — detect config-like values in non-config files
- **Example**: Timeouts defined in 5 different service files instead of one config

### CF03: Environment-Specific Code

- **Pattern**: `if (process.env.NODE_ENV === 'production')` scattered through business logic
- **Detectability**: EASY — detect environment checks in non-config code
- **Example**: `if (env === 'dev') { skipAuth(); } else { validateToken(); }`

### CF04: Magic Strings for Configuration

- **Pattern**: Configuration keys as string literals throughout the codebase
- **Detectability**: EASY — detect string literal config key access
- **Example**: `process.env['DATABASE_URL']` used in 15 different files

### CF05: Configuration That Changes Behavior Silently

- **Pattern**: Feature flags or config that dramatically changes behavior without clear documentation
- **Detectability**: HARD — requires behavioral analysis
- **Example**: Setting `LEGACY_MODE=true` silently disables authentication

### CF06: No Default Values

- **Pattern**: Configuration required but no sensible defaults provided
- **Detectability**: MEDIUM — detect config reads without fallback values
- **Example**: `const port = process.env.PORT; // undefined if not set, crashes later`

### CF07: Configuration Duplication Across Environments

- **Pattern**: Same config values copy-pasted across dev, staging, prod configs
- **Detectability**: EASY — compare config files for duplicated values
- **Example**: Database connection params identical in dev.env and test.env

### CF08: Secrets in Configuration Files

- **Pattern**: Passwords and tokens in checked-in config files
- **Detectability**: EASY — secret patterns in config files
- **Example**: `database_password: "supersecret123"` in config.yml committed to git

### CF09: No Configuration Validation

- **Pattern**: App starts with invalid/missing config and fails at runtime with obscure errors
- **Detectability**: MEDIUM — detect config access without validation at startup
- **Example**: Missing `DB_HOST` causes cryptic "ECONNREFUSED" 10 minutes after startup

### CF10: Boolean Config Traps

- **Pattern**: Config values where `"false"` (string) is truthy, causing bugs
- **Detectability**: EASY — detect boolean config comparisons
- **Example**: `if (process.env.FEATURE_ENABLED) { ... } // "false" is truthy!`

---

## 19. PERFORMANCE (12 frustrations)

### PF01: N+1 Query Problem

- **Pattern**: Loading a list then querying for each item individually
- **Detectability**: MEDIUM — detect query-in-loop patterns
- **Example**: `const users = await getUsers(); for (const u of users) { u.orders = await getOrders(u.id); }`

### PF02: Blocking the Main Thread

- **Pattern**: Synchronous I/O or heavy computation on the main/event loop thread
- **Detectability**: MEDIUM — detect sync I/O calls in async contexts
- **Example**: `const data = fs.readFileSync(largeFile); // blocks all other requests`

### PF03: Memory Leaks (Event Listeners)

- **Pattern**: Adding event listeners without removing them, causing memory growth
- **Detectability**: MEDIUM — detect addEventListener without removeEventListener
- **Example**: `useEffect(() => { window.addEventListener('resize', handler); }); // no cleanup`

### PF04: Unnecessary Computation in Loops

- **Pattern**: Performing expensive operations inside loops that could be done outside
- **Detectability**: MEDIUM — detect loop-invariant computations
- **Example**: `for (const item of items) { const config = JSON.parse(fs.readFileSync('config.json')); }`

### PF05: Unbounded Data Fetching

- **Pattern**: Querying all records from a table without pagination
- **Detectability**: EASY — detect `SELECT *` without LIMIT, or `.find({})` without limit
- **Example**: `SELECT * FROM orders;` — works fine with 100 rows, crashes with 10M

### PF06: Premature Optimization Obscuring Readability

- **Pattern**: Micro-optimizations (bitwise ops, manual loops) that sacrifice clarity for negligible gains
- **Detectability**: MEDIUM — detect bitwise arithmetic used for non-bitwise purposes
- **Example**: `const half = value >> 1; // instead of value / 2`

### PF07: String Concatenation in Loops

- **Pattern**: Building strings with `+` in a loop instead of using StringBuilder/join
- **Detectability**: EASY — detect string `+=` inside loops
- **Example**: `let html = ""; for (const item of items) { html += "<li>" + item + "</li>"; }`

### PF08: Unnecessary Re-renders (React)

- **Pattern**: Components re-rendering on every state change due to missing memoization
- **Detectability**: MEDIUM — detect missing React.memo, useMemo, useCallback
- **Example**: `<ExpensiveList data={items.filter(i => i.active)} /> // new array every render`

### PF09: Loading Unnecessary Data

- **Pattern**: Fetching 50 fields when only 3 are needed
- **Detectability**: MEDIUM — compare fetched fields vs. used fields
- **Example**: `SELECT * FROM users` when only `id` and `name` are displayed

### PF10: Synchronous File I/O in Web Servers

- **Pattern**: Using `readFileSync`, `writeFileSync` in request handlers
- **Detectability**: EASY — detect `*Sync` function calls in server code
- **Example**: `app.get('/data', (req, res) => { const file = fs.readFileSync('data.json'); })`

### PF11: Cartesian Join (Accidental Cross Join)

- **Pattern**: SQL joins that produce cartesian products due to missing join conditions
- **Detectability**: MEDIUM — detect JOINs without ON clauses
- **Example**: `SELECT * FROM orders, products;` — produces orders × products rows

### PF12: Infinite Loops / Unbounded Recursion

- **Pattern**: Loops or recursive calls without proper termination conditions
- **Detectability**: MEDIUM — detect loops without break conditions, recursion without base case
- **Example**: `while (true) { process(); } // no break condition`

---

## 20. SECURITY (14 frustrations)

### SE01: Hardcoded Secrets

- **Pattern**: API keys, passwords, tokens as string literals in source code
- **Detectability**: EASY — regex for common secret patterns (API keys, tokens)
- **Example**: `const API_KEY = "sk-1234567890abcdef"; const DB_PASS = "admin123";`

### SE02: SQL Injection

- **Pattern**: String concatenation in SQL queries with user input
- **Detectability**: EASY — detect string interpolation in SQL query strings
- **Example**: `db.query("SELECT * FROM users WHERE name = '" + userInput + "'");`

### SE03: Cross-Site Scripting (XSS)

- **Pattern**: Rendering user input as HTML without sanitization
- **Detectability**: EASY — detect `innerHTML`, `dangerouslySetInnerHTML`, `v-html` with user data
- **Example**: `element.innerHTML = userComment;`

### SE04: Cross-Site Request Forgery (CSRF)

- **Pattern**: State-changing endpoints without CSRF token validation
- **Detectability**: MEDIUM — detect POST/PUT/DELETE routes without CSRF middleware
- **Example**: `app.post('/transfer', (req, res) => { transfer(req.body); }); // no CSRF check`

### SE05: Insecure Direct Object Reference (IDOR)

- **Pattern**: Using user-supplied IDs to access resources without authorization checks
- **Detectability**: MEDIUM — detect resource access without auth check
- **Example**: `app.get('/user/:id', (req, res) => { return db.getUser(req.params.id); }); // no auth`

### SE06: Missing Input Validation

- **Pattern**: Accepting user input without type/length/format validation
- **Detectability**: MEDIUM — detect user input used without validation
- **Example**: `const age = req.body.age; db.save({ age }); // could be anything`

### SE07: Logging Sensitive Data

- **Pattern**: Passwords, tokens, PII in log output
- **Detectability**: MEDIUM — detect sensitive field names in log statements
- **Example**: `logger.info('User login', { email, password, token });`

### SE08: Weak Cryptography

- **Pattern**: Using MD5, SHA1, DES, or other broken algorithms for security
- **Detectability**: EASY — detect known weak algorithm names
- **Example**: `const hash = md5(password); // MD5 is broken for passwords`

### SE09: Missing HTTPS

- **Pattern**: HTTP URLs for API endpoints or resource loading
- **Detectability**: EASY — detect `http://` URLs in code
- **Example**: `fetch('http://api.example.com/users');`

### SE10: Exposed Stack Traces

- **Pattern**: Detailed error information sent to clients in production
- **Detectability**: MEDIUM — detect error.stack in HTTP responses
- **Example**: `res.status(500).json({ error: err.message, stack: err.stack });`

### SE11: Insufficient Rate Limiting

- **Pattern**: Authentication endpoints without rate limiting, allowing brute force
- **Detectability**: MEDIUM — detect auth routes without rate limit middleware
- **Example**: `app.post('/login', authenticate); // no rate limiting`

### SE12: Unsafe Deserialization

- **Pattern**: Deserializing untrusted data without validation
- **Detectability**: MEDIUM — detect deserialization of user-supplied data
- **Example**: `const obj = JSON.parse(userInput); eval(obj.code);`

### SE13: Missing Security Headers

- **Pattern**: HTTP responses without security headers (CSP, HSTS, X-Frame-Options)
- **Detectability**: EASY — detect missing helmet/security middleware
- **Example**: Express app without `app.use(helmet())` or equivalent

### SE14: Insecure Default Configuration

- **Pattern**: Running with debug mode, default passwords, or permissive CORS in production
- **Detectability**: EASY — detect debug flags, default credentials, `cors({ origin: '*' })`
- **Example**: `app.use(cors({ origin: '*' })); DEBUG=true;`

---

## Summary Statistics

| Category       | Count | Easy | Medium | Hard | Impossible |
|---------------|-------|------|--------|------|------------|
| NAMING        | 24    | 12   | 7      | 5    | 0          |
| COMPLEXITY    | 18    | 12   | 3      | 3    | 0          |
| STRUCTURE     | 14    | 3    | 7      | 4    | 0          |
| READABILITY   | 16    | 8    | 5      | 3    | 0          |
| FUNCTIONS     | 14    | 5    | 5      | 4    | 0          |
| ERROR HANDLING| 12    | 7    | 3      | 2    | 0          |
| DUPLICATION   | 10    | 5    | 5      | 0    | 0          |
| COUPLING      | 12    | 3    | 6      | 3    | 0          |
| COMMENTS      | 12    | 8    | 2      | 2    | 0          |
| TESTS         | 14    | 8    | 3      | 2    | 1          |
| TYPES         | 12    | 7    | 5      | 0    | 0          |
| ASYNC         | 12    | 6    | 4      | 1    | 1          |
| STATE         | 10    | 2    | 5      | 3    | 0          |
| DEPENDENCIES  | 10    | 5    | 5      | 0    | 0          |
| PATTERNS      | 12    | 1    | 5      | 6    | 0          |
| DOCUMENTATION | 10    | 6    | 2      | 2    | 0          |
| GIT           | 10    | 8    | 2      | 0    | 0          |
| CONFIG        | 10    | 6    | 3      | 1    | 0          |
| PERFORMANCE   | 12    | 4    | 7      | 0    | 1          |
| SECURITY      | 14    | 7    | 7      | 0    | 0          |
| **TOTAL**     | **246** | **123** | **89** | **41** | **3** |

### Detectability Distribution

- **EASY (50%)**: 123 frustrations — detectable via regex, line counting, or simple AST patterns
- **MEDIUM (36%)**: 89 frustrations — require context, cross-file analysis, or basic semantic understanding
- **HARD (17%)**: 41 frustrations — need deep semantic understanding, domain knowledge, or behavioral analysis
- **IMPOSSIBLE (1%)**: 3 frustrations — only detectable at runtime (flaky tests, race conditions, certain memory leaks)

### Key Research Findings

1. **Technical debt is the #1 developer frustration** (62% in Stack Overflow 2024 survey)
2. **Developers spend 58-70% of time reading code**, only 5% editing (ACM Research)
3. **23% of development time is wasted** on technical debt (Chalmers University study)
4. **Low quality code has 15x more defects** and takes 124% longer to resolve (Code Red study)
5. **97% of developers lose significant time** to inefficiencies (Atlassian 2024)
6. **Code quality directly predicts developer productivity** (Google Research)
7. **69% of developers lose 8+ hours weekly** to inefficiencies (Harness 2024)
8. **Naming, complexity, and formatting** are the most consistently cited readability barriers across all surveys
9. **50% of cataloged frustrations are EASY to detect** via static analysis — major opportunity for tooling
10. **The biggest gap is in HARD/semantic frustrations** — naming quality, wrong abstractions, architectural issues
