# Clean Code Patterns (Robert C. Martin)

20 checkable rules from *Clean Code* organized by chapter.

## Chapter 3: Functions

| # | Rule | Description | Check |
|---|------|-------------|-------|
| 3.1 | **Small** | Functions should be small (< 20 lines between braces) | `check-clean-code:func-length` |
| 3.2 | **Do One Thing** | Functions should do one thing, do it well, do it only | `check-clean-code:single-responsibility` |
| 3.3 | **Max 3 Args** | Functions should have at most 3 parameters | `check-clean-code:too-many-params` |
| 3.4 | **No Flag Args** | Boolean parameters indicate the function does two things | `check-clean-code:flag-argument` |
| 3.5 | **No Side Effects** | Functions should not have hidden side effects | `check-clean-code:side-effect` |
| 3.6 | **Command-Query Separation** | Functions should either do something or answer something, not both | `check-clean-code:command-query` |
| 3.7 | **DRY** | Don't Repeat Yourself — extract common logic | `check-clean-code:duplication` |

## Chapter 4: Comments

| # | Rule | Description | Check |
|---|------|-------------|-------|
| 4.1 | **No Commented-Out Code** | Remove dead code; use version control | `check-clean-code:commented-code` |
| 4.2 | **No Journal Comments** | No "changed on date by" history in code | `check-clean-code:journal-comment` |
| 4.3 | **No Noise Comments** | No "this is a function" or obvious comments | `check-clean-code:noise-comment` |
| 4.4 | **No Closing Brace Comments** | No `// end for`, `// end if` comments | `check-clean-code:closing-brace-comment` |
| 4.5 | **No Attribution Comments** | No `// written by X` comments | `check-clean-code:attribution-comment` |

## Chapter 5: Formatting

| # | Rule | Description | Check |
|---|------|-------------|-------|
| 5.1 | **Vertical Openness** | Related concepts grouped vertically with blank lines | `check-clean-code:vertical-formatting` |
| 5.2 | **Consistent Indentation** | No mixed tabs/spaces; consistent across files | `check-clean-code:indentation` |
| 5.3 | **Team Rules** | Follow project's `.editorconfig` or formatting conventions | `check-clean-code:team-rules` |

## Chapter 7: Error Handling

| # | Rule | Description | Check |
|---|------|-------------|-------|
| 7.1 | **No Return Null** | Don't return null; throw exception or return Optional | `check-clean-code:return-null` |
| 7.2 | **No Pass Null** | Don't pass null to functions; use Optional/overloads | `check-clean-code:pass-null` |
| 7.3 | **Use Exceptions** | Use exceptions instead of error codes | `check-clean-code:error-codes` |
| 7.4 | **Provide Context** | Exceptions include context (meaningful messages) | `check-clean-code:exception-context` |

## Chapter 9: Tests

| # | Rule | Description | Check |
|---|------|-------------|-------|
| 9.1 | **One Assert** | One assertion per test (or one logical assertion) | `check-clean-code:one-assert` |
| 9.2 | **FIRST** | Tests: Fast, Independent, Repeatable, Self-validating, Timely | `check-clean-code:first-principles` |
| 9.3 | **Test Naming** | Tests named: `should_when` or `given_when_then` convention | `check-clean-code:test-naming` |

## Chapter 10: Classes

| # | Rule | Description | Check |
|---|------|-------------|-------|
| 10.1 | **Small** | Classes should be small (single responsibility) | `check-clean-code:class-size` |
| 10.2 | **Single Responsibility** | One reason to change; high cohesion | `check-clean-code:srp` |
| 10.3 | **Cohesion** | Variables and functions should belong together | `check-clean-code:cohesion` |

## References

- Martin, R. C. (2008). *Clean Code: A Handbook of Agile Software Craftsmanship*. Prentice Hall.