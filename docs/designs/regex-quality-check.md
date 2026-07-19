# Design: `check-regex` — Regex Quality & Safety Check

## Problem Statement

cpm's own CORS check crashed with a false positive because a single quote inside
a single-quoted shell string produced an invalid bash command. This is one of
many classes of regex bugs that are **statically detectable** but currently
go unchecked.

Regex patterns appear in three contexts inside a codebase:

1. **Shell commands** (grep, sed, awk) — subject to shell quoting + BRE/ERE/PCRE dialect differences
2. **Source code** (std::regex, JavaScript `/re/`, Python `re.compile()`) — subject to language escaping + engine differences
3. **Configuration** (nginx, .htaccess, CI/CD pipelines) — subject to tool-specific regex flavors

## Scope

### What This Check Does

A native cpm check (`src/checks/quality/regex_quality.cpp`) that:

1. Detects **regex anti-patterns** in source code and shell scripts
2. Validates **shell command quoting** around regex (the CORS bug class)
3. Warns about **portability issues** (BRE vs ERE vs PCRE)
4. Flags **security-relevant** regex problems (ReDoS, missing anchors)

### What This Check Does NOT Do

- Full regex parsing/compilation (would need a regex engine per dialect)
- Runtime testing of regexes against inputs
- Replacing eslint-plugin-regexp (which does AST-level analysis for JS)

## Top 25 Regex Rules (by severity)

### Security (error)

| # | Rule | Detects | Source |
|---|------|---------|--------|
| 1 | `redos-nested-quantifiers` | `(a+)+`, `(a*)*`, `(a+)*` — catastrophic backtracking | OWASP, SonarQube S5842 |
| 2 | `redos-overlapping-alternation` | `(a|a)+`,`(\w+\s+)+` — exponential paths | rexegg.com |
| 3 | `missing-anchor-validation` | Validation regex without `^`/`$` in security context | CodeQL, CWE-777 |
| 4 | `injection-via-regex` | User input passed directly to regex constructor without escaping | OWASP |

### Correctness (warning)

| # | Rule | Detects | Source |
|---|------|---------|--------|
| 5 | `shell-quoting-mismatch` | Single quotes inside single-quoted regex (our CORS bug) | cpm experience |
| 6 | `unescaped-dot` | `.` used where literal dot intended (e.g. `1.2.3` matching `1X2X3`) | SonarQube S5869 |
| 7 | `empty-alternative` | `|` at start/end or `||` — matches empty string unintentionally | eslint-plugin-regexp, S6323 |
| 8 | `empty-character-class` | `[]` or `[^]` — platform-dependent behavior | eslint-plugin-regexp |
| 9 | `unescaped-special-in-class` | `[a-z.]` where `.` is literal (fine) vs `[a-\d]` (broken range) | S5869 |
| 10 | `duplicate-alternation` | `cat\|cat` or `[aa]` — redundant branch | S5855 |
| 11 | `backslash-in-class-range` | `[\-z]` or `[a-\w]` — range endpoint is escape sequence | eslint-plugin-regexp |
| 12 | `missing-g-flag` | `str.replace(/x/, y)` without `/g` — only replaces first | eslint-plugin-regexp |

### Portability (warning)

| # | Rule | Detects | Source |
|---|------|---------|--------|
| 13 | `bre-ere-mismatch` | Using `+`, `?`, `\|`, `(` without escape in grep (BRE) or using `\+` in grep -E (ERE) | POSIX |
| 14 | `grep-p-not-portable` | `grep -P` used (not available on macOS/BSD) | BSD grep |
| 15 | `sed-r-vs-E` | `sed -r` (GNU-only) vs `sed -E` (POSIX/BSD) | POSIX |
| 16 | `pcre-in-ere-context` | `\d`, `\w`, `\s` in grep -E (ERE doesn't support these) | POSIX |
| 17 | `non-posix-class` | `[:alpha:]` outside brackets or `\p{L}` in non-PCRE context | POSIX |

### Performance (info)

| # | Rule | Detects | Source |
|---|------|---------|--------|
| 18 | `greedy-in-repetition` | `.*` followed by specific char — should be `[^x]*x` | SonarQube S5857 |
| 19 | `trivially-nested-quantifier` | `(a{2}){3}` → `a{6}` | eslint-plugin-regexp |
| 20 | `single-char-alternation` | `a\|b\|c` → `[abc]` | S6035 |

### Style (info)

| # | Rule | Detects | Source |
|---|------|---------|--------|
| 21 | `redundant-escape` | `\:` in ERE where `:` has no special meaning | eslint-plugin-regexp |
| 22 | `prefer-character-class` | `[0-9]` → `\d` (in PCRE) or vice versa for clarity | eslint-plugin-regexp |
| 23 | `redundant-flag` | `/abc/i` where pattern has no letters, or `/g` on `.test()` | eslint-plugin-regexp |
| 24 | `regex-too-complex` | Pattern exceeds N groups/quantifiers (configurable threshold) | S5843 |
| 25 | `prefer-posix-class` | `[A-Za-z0-9_]` → `[[:alnum:]_]` in shell context for clarity | Best practice |

## OS/Tool-Specific Considerations

### Escaping Matrix

| Context | `(` group | `+` one-or-more | `\|` alternation | `\d` digit | `\s` space |
|---------|-----------|-----------------|-------------------|-----------|-----------|
| grep (BRE) | `\(` | `\+` (GNU ext) | `\|` (GNU ext) | ❌ | ❌ |
| grep -E (ERE) | `(` | `+` | `\|` | ❌ | ❌ |
| grep -P (PCRE) | `(` | `+` | `\|` | ✅ | ✅ |
| sed (BRE) | `\(` | `\+` (GNU ext) | `\|` (GNU ext) | ❌ | ❌ |
| sed -E (ERE) | `(` | `+` | `\|` | ❌ | ❌ |
| sed -r (GNU only) | `(` | `+` | `\|` | ❌ | ❌ |
| std::regex (ECMAScript) | `(` | `+` | `\|` | ✅ | ✅ |
| JavaScript | `(` | `+` | `\|` | ✅ | ✅ |
| Python re | `(` | `+` | `\|` | ✅ | ✅ |

### Shell Quoting Rules (the class of bug we hit)

```text
# SAFE: double-quoted regex (shell expands $vars and \escapes, but regex metachar are fine)
grep -E "pattern"

# SAFE: single-quoted regex (NO expansion, but cannot contain single quote)
grep -E 'pattern'

# DANGEROUS: single quote inside single-quoted string
grep -E 'origin:\s*["']*'     ← BREAKS: quote terminates early

# FIX OPTION 1: use double quotes
grep -E "origin:\\s*[\"']*"

# FIX OPTION 2: concatenate
grep -E 'origin:\s*["'"'"']*'

# FIX OPTION 3: $'...' quoting (bash-specific, not POSIX)
grep -E $'origin:\\s*["\\']*'
```

## Implementation Design

### Architecture

```text
src/checks/quality/regex_quality.cpp
├── RegexQualityCheck : Check
│   ├── run() → orchestrates all sub-checks
│   ├── check_shell_commands() → validates shell regex quoting + dialect
│   ├── check_source_regex() → validates regex patterns in source code
│   └── check_portability() → flags non-portable constructs
│
├── ShellRegexExtractor
│   ├── extract_from_grep() → parses grep command, returns regex + mode (BRE/ERE/PCRE)
│   ├── extract_from_sed() → parses sed command, returns regex + mode
│   └── validate_quoting() → checks shell string integrity
│
└── RegexValidator
    ├── check_redos() → nested quantifiers, overlapping alternation
    ├── check_correctness() → empty alternatives, unescaped dots, etc.
    ├── check_portability() → dialect-specific issues
    └── check_style() → complexity, redundancy
```

### File Detection Strategy

| File type | How to find regex |
|-----------|-------------------|
| `*.sh` | Lines with `grep`, `sed`, `awk`, `[[ =~ ]]` |
| `*.cpp`, `*.h` | `std::regex`, `regex_search`, `regex_match`, string args to grep in system() |
| `*.ts`, `*.js` | `/regex/flags`, `new RegExp(...)`, `.match()`, `.replace()` |
| `*.py` | `re.compile(...)`, `re.search(...)`, `re.match(...)` |
| `*.java` | `Pattern.compile(...)` |
| `Makefile` | Shell commands in recipes |
| CI configs | `run:` blocks in `.github/workflows/*.yml` |

### Self-Check Mode

When running on cpm itself:

- Parse `CHECK_DEFS[]` C-string templates → extract shell commands → validate
- Run `bash -n` equivalent on each template (verify it's valid shell syntax)
- Cross-check: if a template uses `grep -E`, verify the regex is valid ERE

### Configuration (cpm.toml)

```toml
[checks.regex-quality]
enabled = true
# Severity override: "error" | "warning" | "info"
redos = "error"
shell-quoting = "error"
portability = "warning"
style = "info"
# Max regex complexity score before warning
max-complexity = 20
# Dialect to assume for .sh files
shell-dialect = "ere"  # "bre" | "ere" | auto-detect from flags
```

### Test Strategy

1. **Unit tests** in `checks_test.cpp`:
   - Each of the 25 rules has at least one positive and one negative test case
   - cpm's own CHECK_DEFS strings are used as test fixtures (dogfooding)
2. **Self-scan**: `cpm check` on cpm's own repo should pass
3. **Regression**: The fixed CORS pattern is a test case for `shell-quoting-mismatch`

## Implementation Priority

### Phase 1 (MVP — prevents our bug class)

- `shell-quoting-mismatch` (rule 5)
- `bre-ere-mismatch` (rule 13)
- `pcre-in-ere-context` (rule 16)
- Self-check on CHECK_DEFS strings

### Phase 2 (Security)

- `redos-nested-quantifiers` (rule 1)
- `redos-overlapping-alternation` (rule 2)
- `missing-anchor-validation` (rule 3)

### Phase 3 (Correctness + Portability)

- Rules 6-12, 14-15, 17

### Phase 4 (Style + Performance)

- Rules 18-25

## References

- [eslint-plugin-regexp](https://github.com/ota-meshi/eslint-plugin-regexp) — 80+ rules, gold standard
- [SonarQube regex rules](https://community.sonarsource.com/t/write-efficient-error-free-and-safe-regular-expressions-in-javascript-and-typescript/47720) — S5842-S6331
- [CodeQL missing-anchor](https://codeql.github.com/codeql-query-help/javascript/js-regex-missing-regexp-anchor/)
- [OWASP ReDoS](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS)
- [rexegg.com backtracking](https://rexegg.com/regex-explosive-quantifiers.html)
- [SonarSource blog: regex boundaries](https://www.sonarsource.com/blog/setting-the-right-regex-boundaries-is-important/)
- POSIX.1-2017 §9 Regular Expressions
