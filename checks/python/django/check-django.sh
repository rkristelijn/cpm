#!/usr/bin/env bash
# checks/python/django/check-django.sh
# @see ADR-129
# Django best practices: thin views, no signals abuse, proper patterns
set -o nounset -o pipefail

REPO="${1:-.}"

# Gate: only run if Django is a dependency
found_django=false
for dep_file in "$REPO/requirements.txt" "$REPO/requirements"/*.txt "$REPO/pyproject.toml" "$REPO/setup.py" "$REPO/setup.cfg" "$REPO/Pipfile"; do
  [ -f "$dep_file" ] && grep -qi "django" "$dep_file" 2>/dev/null && found_django=true && break
done
$found_django || exit 0

finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; }

py_files=$(find "$REPO" -type f -name "*.py" -not -path "*/migrations/*" -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/node_modules/*" 2>/dev/null)
[ -z "$py_files" ] && exit 0

# --- 1. Fat views (>150 lines) ---
echo "$py_files" | grep -E "views\.py$" | while IFS= read -r f; do
  lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  [ "$lines" -gt 150 ] && finding "django-fat-views" "$f: $lines lines — extract to services/use cases"
done

# --- 2. Business logic in signals (anti-pattern) ---
signal_files=$(echo "$py_files" | grep -E "signals\.py$" || true)
if [ -n "$signal_files" ]; then
  echo "$signal_files" | while IFS= read -r f; do
    # Check for heavy logic: DB queries, external calls, complex conditionals
    if grep -cE "\.objects\.|\.filter\(|\.create\(|requests\.|send_mail|celery|\.delay\(" "$f" 2>/dev/null | grep -qv "^0$"; then
      finding "django-signal-logic" "$f: business logic in signals — use explicit service calls"
    fi
  done
fi

# --- 3. No custom user model ---
settings_files=$(echo "$py_files" | grep -E "settings\.py$|settings/.*\.py$" || true)
if [ -n "$settings_files" ]; then
  if ! echo "$settings_files" | xargs grep -lq "AUTH_USER_MODEL" 2>/dev/null; then
    finding "django-no-custom-user" "No AUTH_USER_MODEL — hard to extend later (set before first migration)"
  fi
fi

# --- 4. Raw SQL with string formatting (SQL injection risk) ---
echo "$py_files" | while IFS= read -r f; do
  if grep -nE "cursor\.execute\s*\(.*(%s|%d|\{.*\}|f['\"])" "$f" 2>/dev/null | grep -vq "params\|%s.*,\s*\["; then
    error "django-sql-injection" "$f: raw SQL with string formatting — use parameterized queries"
  fi
  if grep -nE "\.raw\s*\(.*f['\"]|\.raw\s*\(.*\.format\(" "$f" 2>/dev/null; then
    error "django-sql-injection" "$f: QuerySet.raw() with f-string/format — use params argument"
  fi
done

# --- 5. No form/serializer validation (untyped dicts from request) ---
view_files=$(echo "$py_files" | grep -E "views\.py$" || true)
if [ -n "$view_files" ]; then
  echo "$view_files" | while IFS= read -r f; do
    if grep -qE "request\.POST\[|request\.data\[|request\.GET\[" "$f" 2>/dev/null; then
      if ! grep -qE "Form\(|Serializer\(|is_valid\(\)|pydantic|validate" "$f" 2>/dev/null; then
        finding "django-no-validation" "$f: direct request data access without form/serializer validation"
      fi
    fi
  done
fi

# --- 6. N+1 queries: related access without select_related/prefetch_related ---
echo "$py_files" | while IFS= read -r f; do
  if grep -qE "\.objects\.all\(\)|\.objects\.filter\(" "$f" 2>/dev/null; then
    if grep -qE "\.\w+_set\.\|\.related_name\." "$f" 2>/dev/null; then
      if ! grep -qE "select_related\|prefetch_related" "$f" 2>/dev/null; then
        finding "django-n-plus-1" "$f: queryset with related access but no select_related/prefetch_related"
      fi
    fi
  fi
done

# --- 7. Fat models (>300 lines) ---
echo "$py_files" | grep -E "models\.py$" | while IFS= read -r f; do
  lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  [ "$lines" -gt 300 ] && finding "django-fat-models" "$f: $lines lines — split into mixins or separate modules"
done

# --- 8. No middleware for common concerns ---
if [ -n "$settings_files" ]; then
  if ! echo "$settings_files" | xargs grep -lq "SecurityMiddleware\|CsrfViewMiddleware" 2>/dev/null; then
    error "django-no-security-mw" "SecurityMiddleware or CsrfViewMiddleware missing from MIDDLEWARE"
  fi
fi

# --- 9. Circular imports / app coupling ---
echo "$py_files" | while IFS= read -r f; do
  app_dir=$(dirname "$f")
  app_name=$(basename "$app_dir")
  # Check for cross-app model imports in models.py
  if [[ "$(basename "$f")" == "models.py" ]]; then
    foreign_imports=$(grep -cE "^from \w+\.models import" "$f" 2>/dev/null || echo 0)
    [ "$foreign_imports" -gt 3 ] && finding "django-tight-coupling" "$f: $foreign_imports cross-app model imports — use signals or service layer"
  fi
done

# --- 10. Deprecated patterns ---
echo "$py_files" | while IFS= read -r f; do
  grep -nq "django\.utils\.encoding\.smart_text\|django\.utils\.translation\.ugettext" "$f" 2>/dev/null && \
    finding "django-deprecated" "$f: uses deprecated Django utilities"
done
