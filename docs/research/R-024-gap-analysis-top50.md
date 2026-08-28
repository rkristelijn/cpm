# Gap Analysis: Top 50 Detectable Frustrations Missing from cpm

## Methodology

- Cross-referenced 246 developer frustrations against 180+ existing cpm rules
- Classified each as COVERED, PARTIAL, or GAP
- Filtered to EASY and MEDIUM detectability GAPs only
- Ranked by impact (HIGH > MEDIUM > LOW)
- Priority = Detectability × Impact

## Coverage Summary

| Status   | Count | Percentage |
|----------|-------|------------|
| COVERED  | 68    | 27.6%      |
| PARTIAL  | 31    | 12.6%      |
| GAP      | 147   | 59.8%      |

Of the 147 GAPs:

- EASY detectability: 58
- MEDIUM detectability: 52
- HARD/IMPOSSIBLE: 37 (excluded from ranking)

**110 actionable gaps remain. Top 50 below.**

---

## #1 — Empty Catch Blocks (EH01)

- **Category**: Error Handling
- **What to detect**: `catch` block with empty body or only a comment
- **Regex/Heuristic**: `catch\s*\([^)]*\)\s*\{\s*(//[^\n]*)?\s*\}` (single-line or whitespace-only catch body)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.php`
- **Why devs hate it**: Silently swallowing errors is how you spend 3 hours debugging a "this should be impossible" bug.
- **Bad**: `try { await saveUser(data); } catch(e) { }`
- **Good**: `try { await saveUser(data); } catch(e) { logger.error('Failed to save user', { userId: data.id, error: e }); throw new UserSaveError(e); }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-050`

---

## #2 — Long Functions (CX02)

- **Category**: Complexity
- **What to detect**: Function/method body exceeding 50 lines (configurable threshold)
- **Regex/Heuristic**: Parse function boundaries (`function`, `=>`, method declarations), count lines between `{` and `}`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rb, *.php, *.rs`
- **Why devs hate it**: A 300-line function is not a function, it's a hostage situation — you can never safely change one part without breaking another.
- **Bad**: `function processOrder() { /* 287 lines of mixed validation, DB calls, email, logging */ }`
- **Good**: `function processOrder() { validateOrder(order); const total = calculateTotal(order); await persistOrder(order, total); await notifyCustomer(order); }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-051`

---

## #3 — Too Many Parameters (FN01)

- **Category**: Functions
- **What to detect**: Function/method with more than 4 parameters
- **Regex/Heuristic**: Count commas in function parameter list: `(function|def|fn|func)\s+\w+\s*\(([^)]*,){4,}` or count params in arrow functions
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rb, *.php, *.rs`
- **Why devs hate it**: `createUser(name, email, age, role, dept, manager, startDate, salary)` — which argument was the manager again?
- **Bad**: `function createUser(name, email, age, role, department, manager, startDate, salary) { ... }`
- **Good**: `function createUser(options: CreateUserOptions) { ... }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-052`

---

## #4 — Nested Ternary Operators (CX08)

- **Category**: Complexity
- **What to detect**: Ternary `?` inside another ternary expression
- **Regex/Heuristic**: `\?[^?:]*\?` on a single logical expression (match `?` ... `?` with no `;` between)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.php`
- **Why devs hate it**: `a ? b ? c : d : e ? f : g` — congratulations, you've written unreadable line noise.
- **Bad**: `const label = isAdmin ? (isSuperAdmin ? 'Super' : 'Admin') : (isGuest ? 'Guest' : 'User');`
- **Good**: `function getUserLabel(user) { if (user.isSuperAdmin) return 'Super'; if (user.isAdmin) return 'Admin'; if (user.isGuest) return 'Guest'; return 'User'; }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-053`

---

## #5 — Commented-Out Code (CM01)

- **Category**: Comments
- **What to detect**: Lines in comments that look like executable code (assignments, function calls, control flow)
- **Regex/Heuristic**: `^\s*(\/\/|#)\s*(const |let |var |if |for |while |return |import |function |class |export |await |try |switch )` — code keywords after comment markers
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rb, *.php, *.rs`
- **Why devs hate it**: Git exists. Commented-out code is dead code that screams "I was too scared to delete this."
- **Bad**: `// const oldPrice = calculateLegacyPrice(item);\n// if (useOldPricing) { return oldPrice; }`
- **Good**: *(Just delete it. It's in git history if you ever need it.)*
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-054`

---

## #6 — `any` Type Abuse (TY01)

- **Category**: Types
- **What to detect**: More than 3 explicit `any` type annotations per file in TypeScript
- **Regex/Heuristic**: Count occurrences of `: any`, `as any`, `<any>`, `any[]`, `any>` in non-declaration files
- **Target files**: `*.ts, *.tsx`
- **Why devs hate it**: You chose TypeScript for type safety, then typed everything as `any`. You have the worst of both worlds.
- **Bad**: `function process(data: any): any { return (data as any).map((x: any) => x.value as any); }`
- **Good**: `function process(data: UserInput[]): ProcessedResult[] { return data.map(x => ({ value: x.value })); }`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-030`

---

## #7 — Swallowed Exceptions (Catch-Log-Ignore) (EH11)

- **Category**: Error Handling
- **What to detect**: Catch block that only contains a `console.log`/`logger` call and continues execution
- **Regex/Heuristic**: Catch block where body contains only `console\.(log|warn|error)` or `log(ger)?\.(info|warn|error|debug)` with no throw/return/rethrow
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go`
- **Why devs hate it**: Catching, logging, and pretending nothing happened is how you get corrupt data at 3 AM.
- **Bad**: `catch(e) { console.error(e.message); } // continues with potentially invalid state`
- **Good**: `catch(e) { logger.error('Payment failed', { orderId, error: e }); throw new PaymentError('Payment processing failed', { cause: e }); }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-055`

---

## #8 — Inconsistent Naming Convention (N05)

- **Category**: Naming
- **What to detect**: Mixed camelCase/snake_case/PascalCase variable names in the same file
- **Regex/Heuristic**: Collect all variable/function declarations, classify each as camelCase (`[a-z][a-zA-Z]+`), snake_case (`[a-z]+_[a-z]+`), or PascalCase (`[A-Z][a-z]+[A-Z]`). Flag if >1 convention present for same symbol type.
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.py, *.rb, *.go, *.rs, *.java, *.cs`
- **Why devs hate it**: `user_name`, `firstName`, `LastName` in the same file — pick ONE convention and stick with it.
- **Bad**: `const user_name = x; const firstName = y; const LastName = z; function get_data() {} function processResult() {}`
- **Good**: `const userName = x; const firstName = y; const lastName = z; function getData() {} function processResult() {}`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-031`

---

## #9 — Flag Arguments / Boolean Parameters (FN02)

- **Category**: Functions
- **What to detect**: Functions with boolean parameters that control branching behavior
- **Regex/Heuristic**: Detect `(param: boolean|param: bool|boolean \w+|bool \w+)` in function signatures, especially multiple booleans
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp`
- **Why devs hate it**: `render(data, true, false, true)` — what do those booleans mean? Nobody knows without reading the function.
- **Bad**: `function createUser(name: string, isAdmin: boolean, sendEmail: boolean, isActive: boolean) { ... }`
- **Good**: `function createUser(name: string, options: { role: UserRole; notify: boolean; status: UserStatus }) { ... }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-056`

---

## #10 — Throwing String Errors (EH07)

- **Category**: Error Handling
- **What to detect**: `throw "string"` or `throw 'string'` instead of `throw new Error()`
- **Regex/Heuristic**: `throw\s+["'\`]` or `raise\s+["']` (Python)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.py, *.rb, *.php`
- **Why devs hate it**: No stack trace, no error type, no structured information. Debugging in the dark.
- **Bad**: `throw "Something went wrong";`
- **Good**: `throw new Error('User validation failed: email is required');`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-057`

---

## #11 — Generic Exception Catching (EH02)

- **Category**: Error Handling
- **What to detect**: Catching the base `Exception`/`Error`/`BaseException` class instead of specific types
- **Regex/Heuristic**: `catch\s*\(\s*(Exception|Error|Throwable|BaseException)\s` (Java/C#), `except\s+(Exception|BaseException)` (Python), bare `except:` (Python)
- **Target files**: `*.java, *.cs, *.py, *.rb, *.php, *.kt`
- **Why devs hate it**: `catch(Exception e)` catches everything including OOM and null pointers — you're hiding catastrophic failures.
- **Bad**: `try { parseConfig(); } catch(Exception e) { log.warn("config issue"); }`
- **Good**: `try { parseConfig(); } catch(ConfigParseException e) { log.warn("Invalid config format", e); } catch(FileNotFoundException e) { log.error("Config file missing", e); throw; }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-058`

---

## #12 — Complex Boolean Expressions (CX04)

- **Category**: Complexity
- **What to detect**: Conditional expressions with 4+ boolean operands (&&, ||, !)
- **Regex/Heuristic**: Count `&&` and `||` in `if(...)` or ternary conditions. Flag at 4+ operators.
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs`
- **Why devs hate it**: `if ((a && b) || (c && !d) || (e && f && (g || h)))` — extract this into a named function before I lose my mind.
- **Bad**: `if (user.age >= 18 && user.country === 'US' && !user.isBanned && user.emailVerified && (user.role === 'admin' || user.role === 'mod')) {`
- **Good**: `const canAccess = isEligibleUser(user) && hasRequiredRole(user);`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-059`

---

## #13 — Unhandled Promise Rejection (AS02)

- **Category**: Async
- **What to detect**: Promise chains without `.catch()` handler, or floating promises
- **Regex/Heuristic**: `.then(` not followed by `.catch(` within the same chain; async function calls without `await` and not assigned
- **Target files**: `*.ts, *.js, *.tsx, *.jsx`
- **Why devs hate it**: An unhandled rejection crashes Node.js in production. Enjoy your 3 AM pager alert.
- **Bad**: `fetchUserData(userId).then(data => updateUI(data));`
- **Good**: `fetchUserData(userId).then(data => updateUI(data)).catch(err => showError(err));` or `try { const data = await fetchUserData(userId); } catch(err) { ... }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-060`

---

## #14 — Hungarian Notation Remnants (N04)

- **Category**: Naming
- **What to detect**: Variables prefixed with type abbreviations: `strName`, `intCount`, `boolIsActive`, `arrItems`, `objConfig`
- **Regex/Heuristic**: `\b(str|int|bool|arr|obj|lst|dbl|flt|num|chr)[A-Z]\w+` in declarations
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.cpp, *.php`
- **Why devs hate it**: We have type systems now. `strUserName` is a relic from 1995 Visual Basic.
- **Bad**: `let strUserName = "John"; let intAge = 25; let boolIsActive = true; let arrItems = [];`
- **Good**: `let userName = "John"; let age = 25; let isActive = true; let items = [];`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-032`

---

## #15 — Single-Letter Variables Outside Loops (N01)

- **Category**: Naming
- **What to detect**: Single-letter variable names in declarations outside of `for(let i`, math formulas, or tiny lambdas
- **Regex/Heuristic**: `(const|let|var|int|string|auto)\s+[a-z]\s*[=;,]` excluding loop iterators (`for\s*\(.*[ijk]\s*=`)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs`
- **Why devs hate it**: `const d = getData(); const t = process(d); return t;` — what is `d`? What is `t`? I have to read the whole function to find out.
- **Bad**: `const d = getDocument(); const r = validate(d); if (r) { const s = transform(d); return s; }`
- **Good**: `const document = getDocument(); const isValid = validate(document); if (isValid) { const summary = transform(document); return summary; }`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-033`

---

## #16 — Generic/Meaningless Names (N06)

- **Category**: Naming
- **What to detect**: Variables named `data`, `result`, `info`, `temp`, `tmp`, `value`, `item`, `stuff`, `thing`, `val`, `obj`, `ret`, `res` (non-Express)
- **Regex/Heuristic**: `(const|let|var)\s+(data|result|info|temp|tmp|value|item|stuff|thing|val|obj|ret)\s*=`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs, *.rb`
- **Why devs hate it**: `const data = fetchData(); const result = processData(data);` — this tells me absolutely nothing about what's happening.
- **Bad**: `const data = await fetchData(); const result = processData(data); const info = formatResult(result);`
- **Good**: `const userProfile = await fetchUserProfile(); const enrichedProfile = enrichWithPermissions(userProfile); const displayData = formatForDashboard(enrichedProfile);`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-034`

---

## #17 — Unnecessary Async Functions (AS10)

- **Category**: Async
- **What to detect**: Functions marked `async` that never use `await` inside their body
- **Regex/Heuristic**: Multi-line: match `async function` or `async (` or `async =>`, scan body for `await`. Flag if absent.
- **Target files**: `*.ts, *.js, *.tsx, *.jsx`
- **Why devs hate it**: Wrapping everything in `async` "just in case" adds unnecessary promise wrapping and confuses readers about what's actually asynchronous.
- **Bad**: `async function add(a: number, b: number) { return a + b; }`
- **Good**: `function add(a: number, b: number) { return a + b; }`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-035`

---

## #18 — Rethrowing Without Context (EH05)

- **Category**: Error Handling
- **What to detect**: `catch(e) { throw e; }` — catching and rethrowing the same exception with no added context
- **Regex/Heuristic**: Catch block where body is only `throw\s+\w+;` matching the caught variable name
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.cpp`
- **Why devs hate it**: A pointless catch-and-rethrow adds a stack frame and zero value. It's dead code pretending to be error handling.
- **Bad**: `try { await processPayment(); } catch(e) { throw e; }`
- **Good**: `try { await processPayment(); } catch(e) { throw new PaymentError(\`Payment failed for order \${orderId}\`, { cause: e }); }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-061`

---

## #19 — Logging and Rethrowing (Double Handling) (EH06)

- **Category**: Error Handling
- **What to detect**: Catch block that both logs AND rethrows — causes duplicate log entries up the call stack
- **Regex/Heuristic**: Catch block containing both `(console|log(ger)?)\.\w+` AND `throw` statements
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go`
- **Why devs hate it**: Every layer logs and rethrows — one error produces 5 log entries. Good luck finding the real one.
- **Bad**: `catch(e) { logger.error('Failed', e); throw e; } // caller also logs it`
- **Good**: `catch(e) { throw new ServiceError('Order processing failed', { cause: e }); } // let the top-level handler log once`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-062`

---

## #20 — Wall of Code / No Visual Breaks (RD04)

- **Category**: Readability
- **What to detect**: 30+ consecutive non-blank lines inside a function/block
- **Regex/Heuristic**: Count consecutive non-empty, non-comment lines. Flag at 30+.
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs, *.rb`
- **Why devs hate it**: 80 lines of code with zero blank lines is a wall of text. Your eyes literally cannot find section boundaries.
- **Bad**: 80 lines of validation, transformation, and DB operations without a single blank line
- **Good**: Logical paragraphs separated by blank lines with optional section comments
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-063`

---

## #21 — Test Names That Don't Describe (TS03)

- **Category**: Tests
- **What to detect**: Test names like `test1`, `testIt`, `works`, `should work`, `test_function`, or single-word names
- **Regex/Heuristic**: `(it|test|describe)\s*\(\s*['"\`][test\d*|works?|should work|it works|testIt|stuff|thing|foo|bar]('"\`)`
- **Target files**: `*.test.ts, *.test.js, *.spec.ts, *.spec.js, *_test.go, *_test.py, *Test.java`
- **Why devs hate it**: `test('test1', ...)` — when it fails in CI, you have zero idea what broke without opening the file.
- **Bad**: `test('test1', () => { ... }); it('works', () => { ... });`
- **Good**: `test('returns 404 when user ID does not exist', () => { ... }); it('should reject passwords shorter than 8 characters', () => { ... });`
- **Detectability**: EASY
- **Suggested rule ID**: `TEST-020`

---

## #22 — Conditional Logic in Tests (TS11)

- **Category**: Tests
- **What to detect**: `if`/`else`/`switch` statements inside test function bodies
- **Regex/Heuristic**: Detect `if\s*\(` or `switch\s*\(` inside `it(`, `test(`, `describe(` blocks
- **Target files**: `*.test.ts, *.test.js, *.spec.ts, *.spec.js, *_test.go, *_test.py`
- **Why devs hate it**: Tests with `if/else` are testing different things depending on conditions — you have no idea what actually ran.
- **Bad**: `test('validates input', () => { if (process.env.CI) { expect(validate('')).toBe(false); } else { expect(validate('')).toThrow(); } });`
- **Good**: `test('rejects empty input', () => { expect(validate('')).toBe(false); });`
- **Detectability**: EASY
- **Suggested rule ID**: `TEST-021`

---

## #23 — Closing Brace Comments (CM06)

- **Category**: Comments
- **What to detect**: Comments after closing braces that describe what block they close
- **Regex/Heuristic**: `\}\s*//\s*(end|endif|endfor|endwhile|end of|close)\b`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.cpp, *.go, *.php`
- **Why devs hate it**: `} // end if user is admin } // end for each order } // end processOrders` — this means your nesting is so deep you can't tell what `}` belongs to. Fix the nesting.
- **Bad**: `} // end if (user.isAdmin) } // end for (order in orders) } // end function processOrders`
- **Good**: Extract to smaller functions where the closing brace is always visible with its opening statement.
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-036`

---

## #24 — Journal Comments (CM05)

- **Category**: Comments
- **What to detect**: Comments containing date stamps and author names as change logs
- **Regex/Heuristic**: `//\s*\d{4}[-/]\d{2}[-/]\d{2}` or `//\s*(Added|Changed|Fixed|Modified|Updated)\s+by\s+` or `@(author|since|date|modified)`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.cpp, *.go, *.py, *.rb, *.php`
- **Why devs hate it**: `// 2019-03-15 John: Added validation` — this is what `git blame` is for. Journal comments rot instantly.
- **Bad**: `// 2021-03-15 John Smith: Added input validation\n// 2021-04-02 Jane Doe: Fixed edge case for empty strings\n// 2021-06-10 Bob: Reverted Jane's fix, broke prod`
- **Good**: Use meaningful git commit messages. Delete journal comments.
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-037`

---

## #25 — Commented Imports (CM08)

- **Category**: Comments
- **What to detect**: Import or require statements that are commented out
- **Regex/Heuristic**: `^\s*(\/\/|#)\s*(import |from |require\(|using |include )`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rb, *.php, *.rs`
- **Why devs hate it**: `// import { unusedUtil } from './utils';` — you're hoarding dead imports "just in case." Delete it.
- **Bad**: `// import { formatDate } from './utils';\n// import { validateEmail } from './validators';`
- **Good**: Delete commented imports. Your IDE can auto-import when you need them again.
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-038`

---

## #26 — Type Assertion Abuse (TY04)

- **Category**: Types
- **What to detect**: More than 3 `as Type` assertions per file (excluding test files)
- **Regex/Heuristic**: Count `as [A-Z]\w+` or `<[A-Z]\w+>` type assertions. Threshold: >3 per file.
- **Target files**: `*.ts, *.tsx`
- **Why devs hate it**: `as any as User` — you're not using TypeScript, you're arguing with it and winning. The type system is trying to help you.
- **Bad**: `const user = (response as any).data as User; const el = event.target as HTMLInputElement as any;`
- **Good**: `const user: User = await fetchUser(id); // proper typing eliminates need for assertions`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-039`

---

## #27 — Optional Everything (TY07)

- **Category**: Types
- **What to detect**: TypeScript interfaces where >70% of fields are optional (`?:`)
- **Regex/Heuristic**: In `interface` or `type` blocks, count `?:` vs `:` fields. Flag if ratio > 0.7 and >4 fields.
- **Target files**: `*.ts, *.tsx`
- **Why devs hate it**: `interface User { name?: string; email?: string; id?: number; }` — if everything is optional, the type tells you nothing.
- **Bad**: `interface UserProfile { name?: string; email?: string; avatar?: string; bio?: string; role?: string; createdAt?: Date; }`
- **Good**: `interface UserProfile { name: string; email: string; role: UserRole; createdAt: Date; avatar?: string; bio?: string; }`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-040`

---

## #28 — Numbered Variables (N07)

- **Category**: Naming
- **What to detect**: Sequential numbered variable names: `item1`, `item2`, `str1`, `str2`, `result1`
- **Regex/Heuristic**: Two or more declarations matching `(const|let|var)\s+(\w+?)(\d+)\b` where the base name repeats with incrementing numbers
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs, *.rb`
- **Why devs hate it**: `name1, name2, name3` — these aren't names, they're admissions that you couldn't think of real names.
- **Bad**: `const name1 = parts[0]; const name2 = parts[1]; const name3 = parts[2];`
- **Good**: `const [firstName, middleName, lastName] = parts;`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-041`

---

## #29 — Separator/Banner Comments (CM11)

- **Category**: Comments
- **What to detect**: Lines of repeated characters used as visual dividers (===, ---, ///, ***)
- **Regex/Heuristic**: `(\/\/\s*[-=*#]{10,}|#+\s*[-=*]{10,}|\/\*\s*[-=*]{10,})` — 10+ repeated separator chars in comments
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rb, *.php`
- **Why devs hate it**: `// ==================== SECTION ====================` — if you need banners to navigate, your file is too big. Split it.
- **Bad**: `// ==================== VALIDATION =====================\n// ... 200 lines ...\n// ==================== PERSISTENCE ====================`
- **Good**: `validation.ts` and `persistence.ts` — separate files for separate concerns.
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-042`

---

## #30 — Meaningless Commit Messages (GI02)

- **Category**: Git
- **What to detect**: Git commit messages that are too short or generic: `fix`, `update`, `stuff`, `wip`, `changes`, `asdf`
- **Regex/Heuristic**: `git log` + regex: `^(fix|update|stuff|wip|changes|asdf|test|temp|misc|cleanup|tweaks?|minor|oops|commit|\.+)$` or message length <10 chars
- **Target files**: Git hooks / git log analysis
- **Why devs hate it**: `git log: fix, fix, update, stuff, wip, fix` — this git history is useless for debugging regressions.
- **Bad**: `git commit -m "fix"` or `git commit -m "update"` or `git commit -m "stuff"`
- **Good**: `git commit -m "fix: prevent double-charge on retry when payment gateway times out"`
- **Detectability**: EASY
- **Suggested rule ID**: `GIT-010`

---

## #31 — Overly Long Names (N12)

- **Category**: Naming
- **What to detect**: Identifiers exceeding 40 characters
- **Regex/Heuristic**: `\b[a-zA-Z_][a-zA-Z0-9_]{40,}\b` in declarations
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs`
- **Why devs hate it**: `userAccountPermissionValidationServiceFactoryProvider` — your identifier is longer than most tweets.
- **Bad**: `const AbstractSingletonProxyFactoryBeanValidator = new ...`
- **Good**: `const permissionValidator = new ...`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-043`

---

## #32 — Implicit Type Coercion / Loose Equality (RD13)

- **Category**: Readability
- **What to detect**: `==` and `!=` instead of `===` and `!==` in JavaScript/TypeScript
- **Regex/Heuristic**: `[^!=<>]==[^=]` and `[^!]!=[^=]` (excluding `===` and `!==`)
- **Target files**: `*.js, *.jsx, *.ts, *.tsx`
- **Why devs hate it**: `0 == ""` is true, `null == undefined` is true, `"" == false` is true. JS loose equality is a minefield.
- **Bad**: `if (value == null)` or `if (count != 0)` or `if (name == '')`
- **Good**: `if (value === null || value === undefined)` or `if (count !== 0)` or `if (name === '')`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-044`

---

## #33 — Dead Parameters (FN11)

- **Category**: Functions
- **What to detect**: Function parameters that are never referenced in the function body
- **Regex/Heuristic**: Parse function parameters, scan body for each parameter name. Flag unreferenced ones (excluding `_` prefixed, or framework callbacks like `req, res, next`).
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.py, *.go, *.java, *.cs, *.cpp, *.rs`
- **Why devs hate it**: `function process(data, options, callback) { return transform(data); }` — why do `options` and `callback` exist if nothing uses them?
- **Bad**: `function sendEmail(to, subject, body, priority, cc, bcc) { mailer.send(to, subject, body); }`
- **Good**: `function sendEmail(to, subject, body) { mailer.send(to, subject, body); }`
- **Detectability**: MEDIUM
- **Suggested rule ID**: `QUAL-064`

---

## #34 — Hardcoded URLs and File Paths (RD16)

- **Category**: Readability / Config
- **What to detect**: Absolute file paths (`/home/`, `/Users/`, `C:\`) and hardcoded API URLs in source code
- **Regex/Heuristic**: `["'](/home/|/Users/|/var/|/tmp/|/opt/|C:\\|D:\\)\w+` and `["'](https?://[a-z0-9]+\.[a-z]{2,}[^"']*?)["']` in non-config, non-test files
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rb, *.php`
- **Why devs hate it**: `readFile('/Users/john/projects/app/data.json')` — works on John's machine, breaks on everyone else's.
- **Bad**: `const config = readFile('/Users/john/dev/myapp/config.json');`
- **Good**: `const config = readFile(path.join(__dirname, 'config.json'));`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-065`

---

## #35 — Cyclomatic Complexity Per Function (CX05)

- **Category**: Complexity
- **What to detect**: Functions with cyclomatic complexity >10 (counting if, else, for, while, case, &&, ||, catch, ternary)
- **Regex/Heuristic**: Count branching keywords per function body. Each `if`, `else if`, `for`, `while`, `case`, `catch`, `&&`, `||`, `?` adds 1.
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs, *.rb`
- **Why devs hate it**: A function with cyclomatic complexity 25 has 25 paths through it. Good luck writing tests.
- **Bad**: A function with 8 if-else branches, 2 loops, and 3 switch cases
- **Good**: Extract each decision path into named helper functions
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-066`

---

## #36 — Cognitive Complexity (CX06)

- **Category**: Complexity
- **What to detect**: SonarQube-style cognitive complexity per function (penalizes nesting + breaks in linear flow)
- **Regex/Heuristic**: Increment for each branching statement; add nesting penalty (nesting level at each branch); penalize `break`, `continue`, `goto`, recursion.
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs`
- **Why devs hate it**: A function may have low cyclomatic complexity but high cognitive complexity from deep nesting — it's what makes your brain hurt reading code.
- **Bad**: 4 levels of nested if/for with early breaks and continues
- **Good**: Guard clauses, early returns, extracted sub-functions
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-067`

---

## #37 — Fire-and-Forget Async (AS05)

- **Category**: Async
- **What to detect**: Calling an async function without `await`, assigning, or `.then()`
- **Regex/Heuristic**: Statement-level call to known async function (function declared with `async` or returns `Promise`) without `await` keyword before it and no assignment
- **Target files**: `*.ts, *.js, *.tsx, *.jsx`
- **Why devs hate it**: `saveToDatabase(data);` without `await` — errors silently vanish and execution order is non-deterministic.
- **Bad**: `saveToDatabase(data); // forgot await\nsendNotification(user); // errors silently swallowed`
- **Good**: `await saveToDatabase(data);\nawait sendNotification(user);`
- **Detectability**: MEDIUM
- **Suggested rule ID**: `QUAL-068`

---

## #38 — Mixed Async Patterns in Same File (AS03/AS12)

- **Category**: Async
- **What to detect**: File using both `.then()` chains and `async/await` syntax
- **Regex/Heuristic**: Detect presence of both `await` AND `.then(` in the same file (excluding comments/strings)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx`
- **Why devs hate it**: Half the file uses `await`, half uses `.then()` — pick one style and commit to it.
- **Bad**: `async function load() { const a = await getA(); getB().then(b => { process(b); }); }`
- **Good**: `async function load() { const a = await getA(); const b = await getB(); process(b); }`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-045`

---

## #39 — Environment-Specific Code in Business Logic (CF03)

- **Category**: Config
- **What to detect**: `process.env.NODE_ENV`, `ENV`, `__DEV__` checks in non-config source files
- **Regex/Heuristic**: `(process\.env\.NODE_ENV|process\.env\.ENV|__DEV__|Rails\.env|FLASK_ENV|ASPNETCORE_ENVIRONMENT)` in files outside config/ or env/ directories
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.py, *.rb, *.java, *.cs`
- **Why devs hate it**: `if (process.env.NODE_ENV === 'production')` sprinkled through business logic makes every function behave differently in each environment.
- **Bad**: `function validateUser(user) { if (process.env.NODE_ENV === 'dev') return true; /* skip in dev */ ... }`
- **Good**: `function validateUser(user, options: { skipValidation?: boolean }) { if (options.skipValidation) return true; ... }`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-069`

---

## #40 — Callback Error Not Checked (AS09)

- **Category**: Async
- **What to detect**: Node.js callback functions where the first `err` parameter is never checked
- **Regex/Heuristic**: `(function\s*\(\s*err\b[^)]*\)|(\(\s*err\b[^)]*\))\s*=>)\s*\{` where body doesn't contain `if\s*\(\s*err` or `err &&`
- **Target files**: `*.js, *.ts`
- **Why devs hate it**: `fs.readFile(path, (err, data) => { process(data); })` — `data` could be undefined and you'd never know why.
- **Bad**: `fs.readFile(path, (err, data) => { processData(data); });`
- **Good**: `fs.readFile(path, (err, data) => { if (err) { logger.error('Read failed', err); return; } processData(data); });`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-070`

---

## #41 — Encoding Type in Variable Name (N09)

- **Category**: Naming
- **What to detect**: Variables with type suffixes when the type system already provides this: `userList`, `nameString`, `countInt`, `configObj`
- **Regex/Heuristic**: `\b\w+(List|Array|String|Int|Integer|Bool|Boolean|Obj|Object|Map|Set|Dict|Queue|Stack|Number|Float|Double)\b` in declarations (exclude actual class names)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go`
- **Why devs hate it**: `const userArray: User[] = [];` — the `: User[]` already tells me it's an array. The name just adds noise.
- **Bad**: `const userArray: User[] = []; const nameString: string = "John"; const configObject: Config = {};`
- **Good**: `const users: User[] = []; const name: string = "John"; const config: Config = {};`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-046`

---

## #42 — Magic Strings (RD02)

- **Category**: Readability
- **What to detect**: String literals used in comparisons or as identifiers that appear 3+ times in a file
- **Regex/Heuristic**: Find string literals in `===`, `==`, `switch case`, or function arguments that repeat 3+ times in same file
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.rb, *.php`
- **Why devs hate it**: `if (status === "pending_review_v2")` — one typo and your condition silently never matches.
- **Bad**: `if (role === "admin_super") { ... } if (role === "admin_super") { ... } if (status === "pending_review") { ... }`
- **Good**: `const ROLE_SUPER_ADMIN = 'admin_super' as const; if (role === ROLE_SUPER_ADMIN) { ... }` or use an enum.
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-071`

---

## #43 — Long Method Chains (CX09)

- **Category**: Complexity
- **What to detect**: 6+ chained method calls on a single logical expression
- **Regex/Heuristic**: Count consecutive `.methodName(` patterns. Flag at 6+.
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.rb, *.py`
- **Why devs hate it**: `data.filter(x => x.active).map(x => x.name).sort().reverse().slice(0,10).join(', ').trim()` — good luck debugging which step is wrong.
- **Bad**: `users.filter(u => u.active).map(u => u.name).sort().reverse().slice(0, 10).join(', ').trim().toUpperCase()`
- **Good**: `const activeUsers = users.filter(u => u.active); const topNames = activeUsers.map(u => u.name).sort().reverse().slice(0, 10); const display = topNames.join(', ').toUpperCase();`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-072`

---

## #44 — Attribution/Byline Comments (CM07)

- **Category**: Comments
- **What to detect**: `@author`, `Created by`, `Written by`, `Maintained by` comments in source files
- **Regex/Heuristic**: `(@author|Created by|Written by|Maintained by|Author:|Modified by)\s*\w+`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rb, *.php`
- **Why devs hate it**: `// Created by John Smith on 2019-03-15` — git blame tells you this automatically and never goes stale.
- **Bad**: `/** @author John Smith\n * @since 2019-03-15\n * @modified 2020-01-10 by Jane Doe */`
- **Good**: `git blame` + meaningful commit messages.
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-047`

---

## #45 — Negative Boolean Names (N10)

- **Category**: Naming
- **What to detect**: Boolean variables/parameters with negative prefixes causing double-negation
- **Regex/Heuristic**: `(const|let|var|boolean|bool)\s+(not[A-Z]|no[A-Z]|non[A-Z]|un[a-z]+ed|dis[a-z]+ed|isNot|isNo|isNon|isUn|isDis)\w*` and `!\s*(not|isNot|isNo|isNon|isUn|isDis)\w*`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp`
- **Why devs hate it**: `if (!isNotDisabled && !isInactive)` — triple negation is a brain teaser, not code.
- **Bad**: `const isNotReady = false; if (!isNotReady) { ... } // what does this mean?!`
- **Good**: `const isReady = true; if (isReady) { ... }`
- **Detectability**: MEDIUM
- **Suggested rule ID**: `STYLE-048`

---

## #46 — Multiple Return Statements (CX10)

- **Category**: Complexity
- **What to detect**: Functions with 5+ `return` statements scattered throughout
- **Regex/Heuristic**: Count `return\b` per function body. Threshold: >5. (Exclude guard clauses at function top)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp, *.rs, *.rb`
- **Why devs hate it**: 8 return statements means 8 places you need to check to understand what a function gives you.
- **Bad**: A function with return in every if-branch, every loop iteration, every edge case
- **Good**: Use guard clauses at the top, single happy-path return at the bottom
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-073`

---

## #47 — Complex Lambda/Closure Bodies (CX17)

- **Category**: Complexity
- **What to detect**: Arrow function / lambda bodies exceeding 15 lines
- **Regex/Heuristic**: Detect `=>` or `lambda` followed by `{` with >15 lines before closing `}`
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.py, *.java, *.cs, *.rb, *.rs`
- **Why devs hate it**: `items.map(item => { /* 40 lines of business logic */ })` — extract this into a named function so I know what it does.
- **Bad**: `items.map(item => {\n  // 35 lines of validation, transformation, and error handling\n})`
- **Good**: `items.map(enrichItemWithPricing)`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-074`

---

## #48 — Acronym Casing Inconsistency (N19)

- **Category**: Naming
- **What to detect**: Acronyms handled inconsistently: `XMLParser` vs `XmlParser`, `HTTPSUrl` vs `httpsUrl`
- **Regex/Heuristic**: Detect 3+ consecutive uppercase letters in camelCase identifiers: `[a-z][A-Z]{3,}[a-z]` or `[A-Z]{3,}[a-z]` (excludes constants)
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.go`
- **Why devs hate it**: Is it `XMLHTTPRequest`, `XmlHttpRequest`, or `xmlHttpRequest`? Inconsistency kills searchability.
- **Bad**: `class HTTPSURLConnection { parseJSON(xmlHTTPRequest) { } }`
- **Good**: `class HttpsUrlConnection { parseJson(xmlHttpRequest) { } }`
- **Detectability**: EASY
- **Suggested rule ID**: `STYLE-049`

---

## #49 — Interface Bloat (PT10)

- **Category**: Patterns
- **What to detect**: Interfaces with >10 methods (violates Interface Segregation Principle)
- **Regex/Heuristic**: Count method signatures inside `interface` blocks. Threshold: >10.
- **Target files**: `*.ts, *.tsx, *.java, *.cs, *.go`
- **Why devs hate it**: An interface with 25 methods means every implementation must implement 25 methods, even if they only need 3.
- **Bad**: `interface Repository { find; findAll; findBy; save; saveAll; delete; deleteAll; count; aggregate; batch; export; import; migrate; }`
- **Good**: `interface Readable { find; findAll; } interface Writable { save; delete; } interface Repository extends Readable, Writable {}`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-075`

---

## #50 — String Concatenation in Loops (PF07)

- **Category**: Performance / Readability
- **What to detect**: String `+=` inside `for`, `while`, `forEach` loops
- **Regex/Heuristic**: Detect `\w+\s*\+=\s*["'\`]` or `\w+\s*\+=\s*\w+` inside loop bodies where the variable is declared as string
- **Target files**: `*.ts, *.js, *.tsx, *.jsx, *.java, *.cs, *.py, *.go, *.cpp`
- **Why devs hate it**: `html += "<li>" + item + "</li>"` in a loop creates O(n²) string copies. Use an array and join.
- **Bad**: `let html = ""; for (const item of items) { html += "<li>" + item.name + "</li>"; }`
- **Good**: `const html = items.map(item => \`<li>\${item.name}</li>\`).join('');`
- **Detectability**: EASY
- **Suggested rule ID**: `QUAL-076`

---

## Suggested Rule ID Range Summary

| Range | Category |
|-------|----------|
| QUAL-050 – QUAL-076 | Quality / Code Smells |
| STYLE-030 – STYLE-049 | Style / Naming / Convention |
| TEST-020 – TEST-021 | Test Quality |
| GIT-010 | Git Hygiene |

## Impact Distribution of Top 50

| Impact | Count | Examples |
|--------|-------|---------|
| HIGH   | 28    | Empty catch, long functions, too many params, `any` abuse, generic catches |
| MEDIUM | 19    | Banner comments, journal comments, acronym casing, interface bloat |
| LOW    | 3     | Attribution comments, Hungarian notation in modern code |

## Detectability Distribution of Top 50

| Detectability | Count |
|---------------|-------|
| EASY          | 44    |
| MEDIUM        | 6     |

## Implementation Priority Recommendation

### Wave 1 — Quick wins (regex only, HIGH impact, 1-2 days each)

1. `QUAL-050` Empty catch blocks
2. `QUAL-051` Long functions
3. `QUAL-052` Too many parameters
4. `QUAL-053` Nested ternaries
5. `QUAL-054` Commented-out code
6. `STYLE-030` `any` type abuse
7. `QUAL-057` Throwing string errors
8. `QUAL-059` Complex boolean expressions
9. `QUAL-066` Cyclomatic complexity per function
10. `STYLE-031` Inconsistent naming convention

### Wave 2 — Medium effort (context-aware, HIGH impact)

11. `QUAL-055` Catch-log-ignore
12. `QUAL-058` Generic exception catching
13. `QUAL-060` Unhandled promise rejection
14. `QUAL-067` Cognitive complexity
15. `QUAL-061` Rethrowing without context
16. `QUAL-062` Logging and rethrowing

### Wave 3 — Style & naming (regex, MEDIUM impact, low effort)

17-30: All STYLE-032 through STYLE-049

### Wave 4 — Test & git quality

31-35: TEST-020, TEST-021, GIT-010 + additional test checks

### Wave 5 — Remaining items

36-50: Performance patterns, lambda complexity, interface bloat
