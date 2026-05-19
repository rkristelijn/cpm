---
summary: Detect SQL anti-patterns across ANSI SQL and database-specific code via static analysis.
status: proposed
---

# ADR-131: SQL Anti-Pattern Detection

*Date*: 2026-05-19
*Related*: [ADR-129](adr-129-unified-findings-contract.md), [ADR-020](adr-020-product-vision.md)

## Context

SQL anti-patterns cause performance degradation, security vulnerabilities, data integrity issues, and maintenance nightmares. Bill Karwin's "SQL Antipatterns" documents 25 categories. Combined with database-specific pitfalls, there are 200+ detectable patterns across the ecosystem.

cpm already detects `SELECT *` and SQL injection via string concatenation. This ADR expands coverage to the full spectrum of SQL anti-patterns, organized by database type.

## Decision

### Detection tiers

| Tier | Method | Patterns | Speed |
|------|--------|----------|-------|
| 1 | Regex grep (static) | ~40 patterns | <2s |
| 2 | AST-aware (semgrep rules) | ~30 patterns | <30s |
| 3 | Schema analysis (DDL parse) | ~20 patterns | <60s |

Tier 1 is implemented first — grep-based, fast, zero dependencies.

### ANSI SQL Anti-Patterns (50 — universal, any database)

#### Query Anti-Patterns

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 1 | `select-star` | `SELECT *` | `SELECT \*` | info |
| 2 | `distinct-bandaid` | DISTINCT to fix bad joins | `DISTINCT.*JOIN` | warning |
| 3 | `order-by-rand` | `ORDER BY RAND()` | `ORDER BY RAND` | warning |
| 4 | `not-in-subquery` | `NOT IN (SELECT...)` — NULL-unsafe | `NOT IN \(SELECT` | warning |
| 5 | `like-wildcard-prefix` | `LIKE '%...'` — can't use index | `LIKE '%` | info |
| 6 | `function-on-indexed-col` | `WHERE UPPER(col)` / `WHERE YEAR(col)` | `WHERE.*(UPPER|LOWER|YEAR|MONTH|DATE)\(` | warning |
| 7 | `nested-subqueries` | 4+ nested SELECTs | `SELECT.*SELECT.*SELECT.*SELECT` | warning |
| 8 | `having-without-group` | HAVING without GROUP BY | `HAVING.*(?<!GROUP BY)` | info |
| 9 | `count-for-exists` | `COUNT(*)` for existence check | `IF.*COUNT\(\*\).*> 0` | info |
| 10 | `union-without-all` | UNION where UNION ALL suffices | `\bUNION\b(?!\s+ALL)` | info |

#### Type & Value Anti-Patterns

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 11 | `float-for-money` | FLOAT/DOUBLE for monetary values | `(FLOAT|DOUBLE).*(money|price|amount|cost|balance|currency)` | warning |
| 12 | `string-for-date` | VARCHAR for dates | `VARCHAR.*(date|time|created|updated)` | info |
| 13 | `string-for-boolean` | VARCHAR for true/false | `VARCHAR.*(is_|has_|can_|flag)` | info |
| 14 | `varchar-255-everywhere` | VARCHAR(255) as default | `VARCHAR\(255\)` | info |
| 15 | `nullable-everything` | No NOT NULL constraints | Schema analysis (tier 3) | info |

#### Schema Design Anti-Patterns

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 16 | `jaywalking` | Comma-separated values in column | Schema analysis | warning |
| 17 | `eav-pattern` | Entity-Attribute-Value tables | `attr_name.*attr_value\|attribute_name.*attribute_value` | warning |
| 18 | `polymorphic-fk` | Type + ID polymorphic FK | `_type.*_id\|entity_type.*entity_id` | warning |
| 19 | `generic-id-name` | `id` as PK name everywhere | Schema analysis | info |
| 20 | `one-true-lookup` | Single lookup table for all types | Schema analysis | warning |
| 21 | `mutable-enum` | ENUM for changing values | `ENUM\(` | info |
| 22 | `metadata-tribbles` | Year/month in table/column names | `_20[0-9]{2}\b\|_jan\|_feb\|_q[1-4]` | warning |

#### Security Anti-Patterns

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 23 | `sql-injection` | String concatenation in queries | `query\(.*\+\|\.format\(.*SELECT\|f".*SELECT` | error |
| 24 | `plaintext-password` | Storing readable passwords | `password\s+VARCHAR\|password\s+TEXT` | error |
| 25 | `grant-all` | `GRANT ALL` | `GRANT ALL` | warning |
| 26 | `hardcoded-credentials` | Credentials in SQL files | `password\s*=\s*'[^']+'` | error |
| 27 | `dynamic-identifiers` | User input as table/column name | `\+.*table_name\|format.*table` | error |

#### Performance Anti-Patterns

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 28 | `n-plus-one` | SELECT in a loop | Code analysis (tier 2) | warning |
| 29 | `unbounded-query` | SELECT without LIMIT | Code analysis (tier 2) | info |
| 30 | `large-offset` | OFFSET > 10000 | `OFFSET\s+[0-9]{5,}` | warning |
| 31 | `implicit-cast` | Type mismatch in WHERE | Code analysis (tier 2) | warning |
| 32 | `large-in-list` | IN() with 100+ values | `IN\s*\(([^)]*,){99,}` | warning |
| 33 | `correlated-subquery` | Correlated subquery where JOIN works | Code analysis (tier 2) | info |
| 34 | `index-shotgun` | Index on every column | Schema analysis | info |
| 35 | `missing-index-on-fk` | FK column without index | Schema analysis | warning |

#### Data Integrity Anti-Patterns

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 36 | `delete-without-where` | `DELETE FROM` without WHERE | `DELETE\s+FROM\s+\w+\s*$\|DELETE\s+FROM\s+\w+\s*;` | error |
| 37 | `update-without-where` | `UPDATE` without WHERE | `UPDATE\s+\w+\s+SET.*(?!WHERE);\s*$` | error |
| 38 | `truncate-table` | TRUNCATE TABLE | `TRUNCATE\s+TABLE` | warning |
| 39 | `drop-statement` | DROP TABLE/DATABASE | `DROP\s+(TABLE|DATABASE)` | error |
| 40 | `cascade-delete-blind` | ON DELETE CASCADE without thought | `ON\s+DELETE\s+CASCADE` | info |

#### Maintainability Anti-Patterns

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 41 | `magic-numbers` | Hardcoded numbers in queries | `WHERE.*=\s+[0-9]{4,}\b` | info |
| 42 | `logic-in-triggers` | Complex business logic in triggers | `CREATE\s+TRIGGER.*BEGIN` (length check) | info |
| 43 | `uncommented-complex-sql` | Long SQL without comments | Line count without `--` | info |
| 44 | `implicit-join` | Comma-join syntax (old style) | `FROM\s+\w+\s*,\s*\w+.*WHERE` | info |
| 45 | `select-in-check` | SELECT in CHECK constraint | `CHECK.*SELECT` | warning |

#### Miscellaneous

| # | Rule ID | Pattern | Detection | Severity |
|---|---------|---------|-----------|----------|
| 46 | `dual-write` | Same data written to 2 tables | Code analysis | warning |
| 47 | `god-table` | Table with 30+ columns | Schema analysis | warning |
| 48 | `no-primary-key` | Table without PK | Schema analysis | error |
| 49 | `reserved-word-column` | Column named with SQL keyword | `(select|table|order|group|index|key)\s` in DDL | info |
| 50 | `wildcard-grant` | GRANT on `*.*` or `%` host | `GRANT.*\*\.\*\|'%'` | warning |

### Database-Specific Anti-Patterns

#### PostgreSQL (25)

| # | Rule ID | Pattern | Detection |
|---|---------|---------|-----------|
| 1 | `pg-serial-deprecated` | `SERIAL` instead of `GENERATED ALWAYS` | `\bSERIAL\b` |
| 2 | `pg-varchar-over-text` | `VARCHAR(n)` where `TEXT` suffices | `VARCHAR\([0-9]+\)` in PG context |
| 3 | `pg-timestamp-no-tz` | `TIMESTAMP` without timezone | `TIMESTAMP\b(?!\s*WITH)` |
| 4 | `pg-json-not-jsonb` | `json` instead of `jsonb` | `\bjson\b(?!b)` in DDL |
| 5 | `pg-no-partial-index` | Missing partial indexes | Schema analysis |
| 6 | `pg-count-star-large` | `COUNT(*)` on large tables | Code analysis |
| 7 | `pg-no-connection-pool` | Direct connections without pooler | Config analysis |
| 8 | `pg-index-not-concurrent` | `CREATE INDEX` without `CONCURRENTLY` | `CREATE\s+INDEX\b(?!.*CONCURRENTLY)` |
| 9 | `pg-rule-usage` | `CREATE RULE` (deprecated pattern) | `CREATE\s+RULE` |
| 10 | `pg-no-returning` | INSERT/UPDATE without RETURNING | Code analysis |
| 11 | `pg-recursive-no-limit` | Recursive CTE without LIMIT | `WITH RECURSIVE.*(?!LIMIT)` |
| 12 | `pg-security-definer-path` | SECURITY DEFINER without search_path | `SECURITY DEFINER(?!.*search_path)` |
| 13 | `pg-no-explain` | No EXPLAIN usage in codebase | File analysis |
| 14 | `pg-plpgsql-over-sql` | PL/pgSQL where SQL function works | Code analysis |
| 15 | `pg-no-citext` | `LOWER()` everywhere instead of citext | `LOWER\(.*\)\s*=` |

#### MySQL / MariaDB (25)

| # | Rule ID | Pattern | Detection |
|---|---------|---------|-----------|
| 1 | `my-myisam` | MyISAM engine | `ENGINE\s*=\s*MyISAM` |
| 2 | `my-utf8-not-utf8mb4` | `utf8` instead of `utf8mb4` | `CHARSET\s*=\s*utf8[^m]` |
| 3 | `my-enum-mutable` | ENUM for changing values | `ENUM\(` |
| 4 | `my-no-strict-mode` | No strict SQL mode | Config analysis |
| 5 | `my-timestamp-2038` | TIMESTAMP (Y2038 problem) | `\bTIMESTAMP\b` |
| 6 | `my-calc-found-rows` | `SQL_CALC_FOUND_ROWS` (deprecated) | `SQL_CALC_FOUND_ROWS` |
| 7 | `my-replace-into` | `REPLACE INTO` (delete+insert) | `REPLACE\s+INTO` |
| 8 | `my-force-index` | `FORCE INDEX` hardcoded | `FORCE\s+INDEX` |
| 9 | `my-lock-tables` | `LOCK TABLES` in InnoDB | `LOCK\s+TABLES` |
| 10 | `my-no-fk` | No FOREIGN KEY declarations | Schema analysis |
| 11 | `my-group-by-implicit-sort` | GROUP BY without ORDER BY NULL | Code analysis |
| 12 | `my-grant-all` | `GRANT ALL ON *.*` | `GRANT\s+ALL.*\*\.\*` |

#### Oracle (25)

| # | Rule ID | Pattern | Detection |
|---|---------|---------|-----------|
| 1 | `ora-rownum-pagination` | ROWNUM for pagination | `ROWNUM` |
| 2 | `ora-no-bind-vars` | Literals instead of bind variables | Code analysis |
| 3 | `ora-when-others-null` | `WHEN OTHERS THEN NULL` | `WHEN\s+OTHERS\s+THEN\s+NULL` |
| 4 | `ora-long-datatype` | `LONG` data type | `\bLONG\b` in DDL |
| 5 | `ora-cursor-loop` | Cursor FOR loop (row-by-row) | `FOR\s+\w+\s+IN\s*\(.*SELECT` |
| 6 | `ora-autonomous-tx` | AUTONOMOUS_TRANSACTION misuse | `AUTONOMOUS_TRANSACTION` |
| 7 | `ora-execute-immediate` | EXECUTE IMMEDIATE without bind | `EXECUTE\s+IMMEDIATE.*\|\|` |
| 8 | `ora-sys-as-app` | SYS/SYSTEM as application user | `CONNECT\s+(SYS|SYSTEM)` |
| 9 | `ora-nologging-left` | NOLOGGING without reverting | `NOLOGGING` |
| 10 | `ora-connect-by-no-nocycle` | CONNECT BY without NOCYCLE | `CONNECT\s+BY(?!.*NOCYCLE)` |

#### Microsoft SQL Server (25)

| # | Rule ID | Pattern | Detection |
|---|---------|---------|-----------|
| 1 | `mssql-nolock` | `NOLOCK` hint everywhere | `\(NOLOCK\)\|WITH\s*\(NOLOCK\)` |
| 2 | `mssql-sp-prefix` | `sp_` prefix on procedures | `CREATE\s+PROC.*\bsp_` |
| 3 | `mssql-cursor` | CURSOR for set-based work | `DECLARE.*CURSOR` |
| 4 | `mssql-identity-global` | `@@IDENTITY` instead of SCOPE_IDENTITY | `@@IDENTITY` |
| 5 | `mssql-exec-string` | `EXEC(@sql)` instead of sp_executesql | `EXEC\s*\(@` |
| 6 | `mssql-no-try-catch` | Procedures without TRY...CATCH | Code analysis |
| 7 | `mssql-sa-account` | `sa` as application account | `'sa'` in connection strings |
| 8 | `mssql-merge-statement` | MERGE (bug-prone) | `\bMERGE\b.*\bINTO\b` |
| 9 | `mssql-nvarchar-max` | `NVARCHAR(MAX)` everywhere | `NVARCHAR\(MAX\)` |
| 10 | `mssql-top-no-order` | `SELECT TOP` without ORDER BY | `SELECT\s+TOP.*(?!ORDER\s+BY)` |

#### MongoDB (25)

| # | Rule ID | Pattern | Detection |
|---|---------|---------|-----------|
| 1 | `mongo-no-schema` | No schema validation | Config analysis |
| 2 | `mongo-unbounded-array` | Unbounded arrays in documents | `\$push(?!.*\$slice)` |
| 3 | `mongo-dollar-where` | `$where` with JavaScript | `\$where` |
| 4 | `mongo-no-projection` | `find()` without projection | `\.find\(\{[^}]*\}\s*\)` |
| 5 | `mongo-regex-unanchored` | `$regex` without anchor | `\$regex.*[^/^]` |
| 6 | `mongo-write-concern-0` | Write concern w:0 | `w:\s*0` |
| 7 | `mongo-no-index` | Collection without indexes | Config analysis |
| 8 | `mongo-keys-star` | Equivalent of `KEYS *` | `\.find\(\{\}\)` |

#### Redis (10)

| # | Rule ID | Pattern | Detection |
|---|---------|---------|-----------|
| 1 | `redis-keys-star` | `KEYS *` in production | `\.keys\(\s*['"]?\*` |
| 2 | `redis-no-expire` | SET without EXPIRE | Code analysis |
| 3 | `redis-flushall` | FLUSHALL/FLUSHDB | `FLUSHALL\|FLUSHDB` |
| 4 | `redis-large-value` | Values > 1MB | Code analysis |
| 5 | `redis-del-blocking` | DEL on large keys (blocking) | Code analysis |

#### Vector DBs (10)

| # | Rule ID | Pattern | Detection |
|---|---------|---------|-----------|
| 1 | `vec-wrong-metric` | Mismatched distance metric | Config analysis |
| 2 | `vec-no-metadata-filter` | Query without metadata filter | Code analysis |
| 3 | `vec-stale-embeddings` | No re-embed on update | Code analysis |
| 4 | `vec-high-dimensions` | Dimensions > 2048 | Config analysis |
| 5 | `vec-no-hybrid-search` | Vector-only without keyword | Code analysis |

## Enforcement

| What | How | Automation |
|------|-----|-----------|
| Tier 1 patterns (grepbaar) | `check-sql-antipatterns.sh` | Runs in `cpm check` |
| DB-specific patterns | Language-detect + targeted grep | Auto-detect from deps |
| Schema patterns (tier 3) | DDL file analysis | Future: `cpm check --full` |

## Acceptance Criteria

- [ ] `check-sql-antipatterns.sh` detects all tier 1 patterns (40+)
- [ ] DB-specific detection auto-activates based on detected database type
- [ ] `cpm scan` reports SQL anti-patterns per repo
- [ ] Each finding has: rule, severity, file, line, message, fix
- [ ] False positive rate < 10% on real codebases

## Consequences

### Positive

- Catches SQL issues before they reach production
- Educates developers (every finding has a fix suggestion)
- Works across all database types
- Zero dependencies (grep-based tier 1)

### Negative

- Some patterns need schema context (tier 3, future)
- False positives on patterns in comments/strings
- DB-specific detection requires language/framework detection

## References

- Bill Karwin, "SQL Antipatterns" (Pragmatic Bookshelf, 2010)
- @see checks/universal/quality/check-sql-antipatterns.sh
- @see src/checks/owasp.cpp (existing OWASP detection)
- @see src/checks/antipatterns.cpp (existing SELECT * detection)
