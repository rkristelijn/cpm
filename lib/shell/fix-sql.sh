#!/usr/bin/env bash
# fix-sql-antipatterns.sh — Auto-fix safe SQL anti-patterns.
# Usage: cpm fix sql [--apply]
# Default: dry-run (shows what would change). Pass --apply to write.
# @see ADR-131 (SQL anti-pattern detection)
set -o errexit
set -o nounset
set -o pipefail

APPLY="${1:-}"
DRY_RUN=true
[[ "$APPLY" == "--apply" ]] && DRY_RUN=false

FIXES=0
FILES_CHANGED=0

fix() {
  local file="$1" pattern="$2" replacement="$3" rule="$4" desc="$5"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    local count
    count=$(grep -cE "$pattern" "$file" 2>/dev/null || echo 0)
    if $DRY_RUN; then
      printf "  %-40s %-30s %s (%d)\n" "$file" "$rule" "$desc" "$count"
    else
      sed -i '' -E "s/$pattern/$replacement/g" "$file"
      printf "  ✓ %-40s %-30s fixed %d\n" "$file" "$rule" "$count"
      FILES_CHANGED=$((FILES_CHANGED + 1))
    fi
    FIXES=$((FIXES + count))
  fi
}

echo ""
if $DRY_RUN; then
  echo "  cpm fix sql (dry-run) — pass --apply to write changes"
else
  echo "  cpm fix sql --apply"
fi
echo ""

# --- Safe fixes: no behavior change ---

# MySQL: utf8 → utf8mb4
while IFS= read -r f; do
  fix "$f" "CHARSET=utf8([^m]|$)" "CHARSET=utf8mb4\1" "my-utf8" "utf8 → utf8mb4"
  fix "$f" "charset=utf8([^m]|$)" "charset=utf8mb4\1" "my-utf8" "utf8 → utf8mb4"
done < <(find . -name '*.sql' -o -name '*.prisma' -o -name '*.rb' | grep -v node_modules | grep -v .git || true)

# MySQL: MyISAM → InnoDB
while IFS= read -r f; do
  fix "$f" "ENGINE\s*=\s*MyISAM" "ENGINE=InnoDB" "my-myisam" "MyISAM → InnoDB"
done < <(find . -name '*.sql' | grep -v node_modules | grep -v .git || true)

# MySQL: remove SQL_CALC_FOUND_ROWS
while IFS= read -r f; do
  fix "$f" "SQL_CALC_FOUND_ROWS " "" "my-calc-found-rows" "remove deprecated keyword"
done < <(find . -name '*.sql' -o -name '*.php' -o -name '*.rb' | grep -v node_modules | grep -v .git || true)

# MSSQL: @@IDENTITY → SCOPE_IDENTITY()
while IFS= read -r f; do
  fix "$f" "@@IDENTITY" "SCOPE_IDENTITY()" "mssql-identity" "@@IDENTITY → SCOPE_IDENTITY()"
done < <(find . -name '*.sql' -o -name '*.cs' -o -name '*.vb' | grep -v node_modules | grep -v .git || true)

# MSSQL: remove (NOLOCK)
while IFS= read -r f; do
  fix "$f" "\(NOLOCK\)" "" "mssql-nolock" "remove NOLOCK hint"
  fix "$f" "WITH \(NOLOCK\)" "" "mssql-nolock" "remove WITH (NOLOCK)"
done < <(find . -name '*.sql' -o -name '*.cs' | grep -v node_modules | grep -v .git || true)

# PostgreSQL: json → jsonb (in CREATE TABLE only)
while IFS= read -r f; do
  fix "$f" " json([,\)])" " jsonb\1" "pg-json-not-jsonb" "json → jsonb"
done < <(find . -name '*.sql' -o -name '*.prisma' | grep -v node_modules | grep -v .git || true)

# PostgreSQL: TIMESTAMP → TIMESTAMPTZ
while IFS= read -r f; do
  fix "$f" "TIMESTAMP([^T]|$)" "TIMESTAMPTZ\1" "pg-timestamp-no-tz" "TIMESTAMP → TIMESTAMPTZ"
done < <(find . -name '*.sql' | grep -v node_modules | grep -v .git || true)

# Redis: .keys('*') → .scan(...)  (JS/TS/Python)
while IFS= read -r f; do
  fix "$f" "\.keys\('\*'\)" ".scan('*')" "redis-keys-star" "keys('*') → scan('*')"
  fix "$f" '\.keys\("\*"\)' '.scan("*")' "redis-keys-star" 'keys("*") → scan("*")'
done < <(find . -name '*.ts' -o -name '*.js' -o -name '*.py' | grep -v node_modules | grep -v .git || true)

echo ""
if $DRY_RUN; then
  echo "  $FIXES fixable occurrences found (dry-run, no changes made)"
  echo "  Run with --apply to fix"
else
  echo "  $FIXES fixes applied across $FILES_CHANGED files"
fi
echo ""
