#!/usr/bin/env bash
set -o nounset -o pipefail

# findings_add() { printf "  %-8s %-30s %s\n" "$1" "$3" "$4"; }
REPO="${1:-.}"

findings_add() {
    local severity="$1"
    local check="$2"
    local message="$3"
    printf "  %-8s %-30s %s\n" "$severity" "$check" "$message"
}

# Find all source files (common extensions)
all_files=$(find "$REPO" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.php" -o -name "*.sql" \) 2>/dev/null | head -200)
[[ -z "$all_files" ]] && exit 0

# N+1 queries: loop with query inside
for f in $all_files; do
    # Skip test files
    [[ "$f" == *test* ]] && continue

    # Pattern: for/while with .find/.get/.query/.execute inside
    if grep -qE "for\s+\w+\s+in\s+" "$f" 2>/dev/null; then
        if grep -qE "\.(find|get|query|execute)\s*\(" "$f" 2>/dev/null; then
            findings_add "warning" "n-plus-one" "$f: possible N+1 query pattern (loop with query inside)"
        fi
    fi
done

# Raw SQL with string interpolation
for f in $all_files; do
    [[ "$f" == *test* ]] && continue

    # f-string interpolation
    if grep -qE "f[\"'].*execute\s*\(" "$f" 2>/dev/null; then
        findings_add "error" "raw-sql-fstring" "$f: raw SQL with f-string interpolation, use parameterized queries"
    fi
    # .format() with SQL
    if grep -qE "\.format\s*\(\s*['\"].*execute" "$f" 2>/dev/null; then
        findings_add "error" "raw-sql-format" "$f: raw SQL with .format(), use parameterized queries"
    fi
    # % formatting
    if grep -qE "['\"].*%\s*[sd].*execute" "$f" 2>/dev/null; then
        findings_add "error" "raw-sql-percent" "$f: raw SQL with % formatting, use parameterized queries"
    fi
    # String concatenation
    if grep -qE "\+\s*['\"].*SELECT" "$f" 2>/dev/null; then
        findings_add "error" "raw-sql-concat" "$f: raw SQL with string concatenation, use parameterized queries"
    fi
done

# SELECT * usage
for f in $all_files; do
    [[ "$f" == *test* ]] && continue

    if grep -qE "SELECT\s+\*" "$f" 2>/dev/null; then
        findings_add "warning" "select-star" "$f: SELECT * usage, specify columns instead"
    fi
done

# Hardcoded connection strings
for f in $all_files; do
    [[ "$f" == *test* ]] && continue

    if grep -qE "(jdbc|mysql|postgresql|mongodb)://[^\"']+" "$f" 2>/dev/null; then
        findings_add "error" "hardcoded-connection" "$f: hardcoded database connection string"
    fi
    if grep -qE "ConnectionStrings?\s*[:=]\s*[\"'][^\"']+[\"']" "$f" 2>/dev/null; then
        findings_add "warning" "hardcoded-connection" "$f: possible hardcoded connection string"
    fi
done

# No migration files
migrations_dir=$(find "$REPO" -type d -name "*migration*" 2>/dev/null | head -1)
if [[ -z "$migrations_dir" ]]; then
    # Check for common migration patterns
    has_migrations=false
    for f in $all_files; do
        if [[ "$f" == *migrations* ]] || [[ "$f" == *schema* ]]; then
            has_migrations=true
            break
        fi
    done
    if ! $has_migrations; then
        findings_add "warning" "no-migrations" "No migration directory found, schema changes should be versioned"
    fi
fi

# Missing transactions (heuristic)
for f in $all_files; do
    [[ "$f" == *test* ]] && continue

    # Multiple writes without transaction context
    if grep -qE "\.(save|insert|update|delete)\s*\(" "$f" 2>/dev/null; then
        if ! grep -qE "transaction|@transaction|begin.*transaction|BEGIN.*COMMIT" "$f" 2>/dev/null; then
            findings_add "warning" "no-transaction" "$f: database writes without explicit transaction"
        fi
    fi
done

# No query timeout/limit
for f in $all_files; do
    [[ "$f" == *test* ]] && continue

    if grep -qE "SELECT\s+.*FROM" "$f" 2>/dev/null; then
        if ! grep -qE "(LIMIT|TOP\s+\d+|timeout|TIMEOUT)" "$f" 2>/dev/null; then
            findings_add "info" "no-limit-timeout" "$f: SELECT without LIMIT or timeout"
        fi
    fi
done

# Missing ON DELETE CASCADE
for f in $all_files; do
    [[ "$f" == *test* ]] && continue

    if grep -qE "FOREIGN\s+KEY|REFERENCES" "$f" 2>/dev/null; then
        if ! grep -qE "ON\s+DELETE\s+(CASCADE|SET\s+NULL)" "$f" 2>/dev/null; then
            findings_add "warning" "no-cascade-delete" "$f: foreign key without ON DELETE CASCADE, possible orphan data"
        fi
    fi
done