#!/usr/bin/env bash
# check-sql-antipatterns.sh — Detect SQL anti-patterns across any codebase.
# @see ADR-131 (SQL anti-pattern detection)
source "$(dirname "$0")/../../../lib/shell/check.sh"

# All tier-1 grepable patterns in one pass
# cpm:ignore sql-drop — detection pattern
COMBINED='SELECT \*|ORDER BY RAND|NOT IN \(SELECT|NOT IN \( SELECT|LIKE .%|WHERE\s*(UPPER|LOWER|YEAR|MONTH|DATE|CAST)\(|SELECT.*SELECT.*SELECT.*SELECT|GRANT ALL|DROP (TABLE|DATABASE)|TRUNCATE TABLE|DELETE FROM \w+ *;|UPDATE \w+ SET.*; *$|FLOAT.*(money|price|amount|cost|balance)|DOUBLE.*(money|price|amount|cost|balance)|VARCHAR\(255\)|ENUM\(|_20[0-9][0-9]\b|query\(.*\+|\.query\(`[^`]*\$\{|"SELECT.*" *\+|"INSERT.*" *\+|"UPDATE.*" *\+|"DELETE.*" *\+|f".*SELECT|f".*INSERT|f".*UPDATE|f".*DELETE|\.execute\(.*%|\.format\(.*SELECT|sprintf.*SELECT|\$".*SELECT.*\{|password\s+VARCHAR|password\s+TEXT|GRANT.*\*\.\*|ON DELETE CASCADE|REPLACE INTO|SQL_CALC_FOUND_ROWS|FORCE INDEX|LOCK TABLES|@@IDENTITY|\(NOLOCK\)|DECLARE.*CURSOR|KEYS \*|FLUSHALL|FLUSHDB|\$where|ENGINE.*MyISAM|utf8[^m].*CHARSET|WHEN OTHERS THEN NULL|EXECUTE IMMEDIATE.*\|\||NOLOGGING|ROWNUM|NVARCHAR\(MAX\)|sp_executesql'

hits=$(grep -rnE "$COMBINED" \
  --include='*.sql' --include='*.ts' --include='*.js' --include='*.py' \
  --include='*.php' --include='*.java' --include='*.rb' --include='*.cpp' \
  --include='*.go' --include='*.cs' --include='*.prisma' --include='*.graphql' \
  --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules \
  --exclude-dir=.tmp --exclude-dir=build --exclude-dir=dist \
  --exclude='check-sql-antipatterns.sh' \
  . 2>/dev/null | grep -v "cpm:ignore\|^\s*[#/\*-]" | head -500 || true)

[[ -z "$hits" ]] && exit 0

while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  file="${hit%%:*}"; rest="${hit#*:}"
  linenum="${rest%%:*}"; line="${rest#*:}"
  file="${file#./}"
  [[ "$line" =~ ^[[:space:]]*(#|//|\*|--|/\*) ]] && continue

  case "$line" in
    # Security (error)
    *'query('*'+'*|*'.format('*SELECT*|*'.format('*INSERT*|*'f"'*SELECT*|*'f"'*INSERT*|*'f"'*UPDATE*|*'f"'*DELETE*|*'.execute('*'%'*|*'"SELECT'*'" +'*|*'"INSERT'*'" +'*|*'"UPDATE'*'" +'*|*'"DELETE'*'" +'*|*'sprintf'*'SELECT'*|*'$"'*'SELECT'*'{'*)
      findings_add "error" "$file:$linenum" "sql-injection" "SQL string concatenation (injection risk)" "Use parameterized queries" "" ;;
    *'GRANT ALL'*'*.*'*|*'GRANT ALL'*)
      findings_add "warning" "$file:$linenum" "grant-all" "GRANT ALL violates least privilege" "Grant specific permissions only" "" ;;
    *'DROP TABLE'*|*'DROP DATABASE'*)
      findings_add "error" "$file:$linenum" "drop-statement" "DROP destroys data permanently" "Use migrations, add IF EXISTS" "" ;;
    *password*VARCHAR*|*password*TEXT*)
      findings_add "error" "$file:$linenum" "plaintext-password" "Password stored as readable text" "Store bcrypt/argon2 hash instead" "" ;;
    *'@@IDENTITY'*)
      findings_add "error" "$file:$linenum" "mssql-identity-global" "@@IDENTITY returns wrong value with triggers" "Use SCOPE_IDENTITY()" "" ;;
    *'EXECUTE IMMEDIATE'*'||'*)
      findings_add "error" "$file:$linenum" "ora-execute-immediate" "Dynamic SQL without bind variables" "Use bind parameters" "" ;;
    *'$where'*)
      findings_add "error" "$file:$linenum" "mongo-dollar-where" "\$where executes JavaScript (injection + slow)" "Use query operators" "" ;;
    *'FLUSHALL'*|*'FLUSHDB'*)
      findings_add "error" "$file:$linenum" "redis-flushall" "FLUSHALL/FLUSHDB destroys all data" "Target specific keys" "" ;;
    # Performance (warning)
    *'ORDER BY RAND'*)
      findings_add "warning" "$file:$linenum" "order-by-rand" "ORDER BY RAND() full table scan, O(n log n)" "Use offset-based random" "" ;;
    *'NOT IN (SELECT'*|*'NOT IN ( SELECT'*)
      findings_add "warning" "$file:$linenum" "not-in-subquery" "NOT IN fails on NULL values" "Use NOT EXISTS or LEFT JOIN IS NULL" "" ;;
    *SELECT*SELECT*SELECT*SELECT*)
      findings_add "warning" "$file:$linenum" "nested-subqueries" "Deeply nested subqueries" "Use CTEs (WITH clause)" "" ;;
    *FLOAT*money*|*FLOAT*price*|*FLOAT*amount*|*FLOAT*cost*|*DOUBLE*money*|*DOUBLE*price*|*DOUBLE*amount*)
      findings_add "warning" "$file:$linenum" "float-for-money" "FLOAT for money causes rounding errors" "Use DECIMAL/NUMERIC" "" ;;
    *'TRUNCATE TABLE'*)
      findings_add "warning" "$file:$linenum" "truncate-table" "TRUNCATE not rollback-safe in some DBs" "Use DELETE with WHERE or soft-delete" "" ;;
    *'ON DELETE CASCADE'*)
      findings_add "info" "$file:$linenum" "cascade-delete" "CASCADE delete — verify intentional" "Consider soft-delete or RESTRICT" "" ;;
    *'REPLACE INTO'*)
      findings_add "warning" "$file:$linenum" "my-replace-into" "REPLACE = DELETE + INSERT (triggers fire twice)" "Use INSERT ON DUPLICATE KEY UPDATE" "" ;;
    *'SQL_CALC_FOUND_ROWS'*)
      findings_add "warning" "$file:$linenum" "my-calc-found-rows" "SQL_CALC_FOUND_ROWS is deprecated" "Use separate COUNT(*) query" "" ;;
    *'FORCE INDEX'*)
      findings_add "warning" "$file:$linenum" "my-force-index" "FORCE INDEX breaks on schema change" "Let optimizer choose or fix query" "" ;;
    *'LOCK TABLES'*)
      findings_add "warning" "$file:$linenum" "my-lock-tables" "LOCK TABLES in InnoDB — use row locks" "Use SELECT FOR UPDATE" "" ;;
    *'(NOLOCK)'*)
      findings_add "warning" "$file:$linenum" "mssql-nolock" "NOLOCK causes dirty reads" "Use snapshot isolation" "" ;;
    *'DECLARE'*'CURSOR'*)
      findings_add "warning" "$file:$linenum" "mssql-cursor" "CURSOR for set-based work is slow" "Rewrite as set-based SQL" "" ;;
    *'WHEN OTHERS THEN NULL'*)
      findings_add "warning" "$file:$linenum" "ora-when-others-null" "Swallows all exceptions silently" "Handle specific exceptions" "" ;;
    *'NOLOGGING'*)
      findings_add "warning" "$file:$linenum" "ora-nologging" "NOLOGGING causes data loss on recovery" "Revert after bulk load" "" ;;
    *'ENGINE'*'MyISAM'*)
      findings_add "warning" "$file:$linenum" "my-myisam" "MyISAM has no transactions or FK support" "Use InnoDB" "" ;;
    *'KEYS *'*|*'KEYS "*"'*)
      findings_add "warning" "$file:$linenum" "redis-keys-star" "KEYS * blocks Redis (single-threaded)" "Use SCAN instead" "" ;;
    # Info
    *'SELECT *'*|*'select *'*)
      findings_add "info" "$file:$linenum" "select-star" "SELECT * fetches unnecessary columns" "Name columns explicitly" "" ;;
    *"LIKE '%"*|*"like '%"*)
      findings_add "info" "$file:$linenum" "like-wildcard-prefix" "Leading wildcard can't use index" "Use full-text search" "" ;;
    *'VARCHAR(255)'*)
      findings_add "info" "$file:$linenum" "varchar-255" "VARCHAR(255) as lazy default" "Size appropriately for the data" "" ;;
    *'ENUM('*)
      findings_add "info" "$file:$linenum" "mutable-enum" "ENUM requires schema change to add values" "Use lookup table" "" ;;
    *'ROWNUM'*)
      findings_add "info" "$file:$linenum" "ora-rownum" "ROWNUM pagination is legacy" "Use FETCH FIRST N ROWS (12c+)" "" ;;
    *'NVARCHAR(MAX)'*)
      findings_add "info" "$file:$linenum" "mssql-nvarchar-max" "NVARCHAR(MAX) can't be indexed" "Size appropriately" "" ;;
  esac
done <<< "$hits"
