#!/usr/bin/env bash
# checks/python/django/check-django-security.sh
# @see ADR-129
# Django security: OWASP-aligned checks for deployment & config
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

py_files=$(find "$REPO" -type f -name "*.py" -not -path "*/migrations/*" -not -path "*/.venv/*" -not -path "*/venv/*" 2>/dev/null)
settings_files=$(echo "$py_files" | grep -E "settings\.py$|settings/.*\.py$" || true)

[ -z "$settings_files" ] && exit 0

# --- 1. DEBUG=True in settings ---
echo "$settings_files" | while IFS= read -r f; do
  if grep -qE "^\s*DEBUG\s*=\s*True" "$f" 2>/dev/null; then
    # Only skip if DEBUG itself comes from env
    if ! grep -qE "^\s*DEBUG\s*=.*os\.environ|^\s*DEBUG\s*=.*env\(|^\s*DEBUG\s*=.*config\(" "$f" 2>/dev/null; then
      error "django-debug-true" "$f: DEBUG=True hardcoded — must use env var in production"
    fi
  fi
done

# --- 2. Hardcoded SECRET_KEY ---
echo "$settings_files" | while IFS= read -r f; do
  if grep -qE "^\s*SECRET_KEY\s*=\s*['\"][^'\"]{8,}['\"]" "$f" 2>/dev/null; then
    error "django-hardcoded-secret" "$f: SECRET_KEY hardcoded — use env var or secrets manager"
  fi
done

# --- 3. ALLOWED_HOSTS = ['*'] or empty ---
echo "$settings_files" | while IFS= read -r f; do
  if grep -qE "ALLOWED_HOSTS\s*=\s*\[\s*'\*'\s*\]" "$f" 2>/dev/null; then
    error "django-allowed-hosts" "$f: ALLOWED_HOSTS=['*'] — restrict to actual domains"
  fi
  if grep -qE "ALLOWED_HOSTS\s*=\s*\[\s*\]" "$f" 2>/dev/null; then
    finding "django-allowed-hosts" "$f: ALLOWED_HOSTS=[] — set for production"
  fi
done

# --- 4. Missing security headers settings ---
all_settings=$(echo "$settings_files" | xargs cat 2>/dev/null)

echo "$all_settings" | grep -q "SECURE_HSTS_SECONDS" || \
  finding "django-no-hsts" "SECURE_HSTS_SECONDS not set — no HTTP Strict Transport Security"

echo "$all_settings" | grep -q "SECURE_SSL_REDIRECT" || \
  finding "django-no-ssl-redirect" "SECURE_SSL_REDIRECT not set — HTTP not redirected to HTTPS"

echo "$all_settings" | grep -q "SESSION_COOKIE_SECURE" || \
  finding "django-insecure-cookies" "SESSION_COOKIE_SECURE not set — cookies sent over HTTP"

echo "$all_settings" | grep -q "CSRF_COOKIE_SECURE" || \
  finding "django-insecure-csrf" "CSRF_COOKIE_SECURE not set — CSRF cookie sent over HTTP"

echo "$all_settings" | grep -q "SECURE_CONTENT_TYPE_NOSNIFF" || \
  finding "django-no-nosniff" "SECURE_CONTENT_TYPE_NOSNIFF not set"

echo "$all_settings" | grep -q "X_FRAME_OPTIONS\|CSP_FRAME_ANCESTORS" || \
  finding "django-no-clickjack" "X_FRAME_OPTIONS or CSP_FRAME_ANCESTORS not configured"

# --- 5. CORS misconfiguration ---
if echo "$all_settings" | grep -qE "CORS_ALLOW_ALL_ORIGINS\s*=\s*True|CORS_ORIGIN_ALLOW_ALL\s*=\s*True"; then
  error "django-cors-wildcard" "CORS allows all origins — restrict to specific domains"
fi

# --- 6. No CSRF protection disabled ---
echo "$py_files" | while IFS= read -r f; do
  if grep -qE "@csrf_exempt|csrf_exempt" "$f" 2>/dev/null; then
    finding "django-csrf-exempt" "$f: @csrf_exempt used — ensure this is intentional and documented"
  fi
done

# --- 7. Unsafe deserialization ---
echo "$py_files" | while IFS= read -r f; do
  if grep -qE "pickle\.loads|yaml\.load\s*\(" "$f" 2>/dev/null; then
    if ! grep -qE "yaml\.safe_load\|Loader=SafeLoader" "$f" 2>/dev/null; then
      error "django-unsafe-deser" "$f: unsafe deserialization (pickle/yaml.load) — use safe alternatives"
    fi
  fi
done

# --- 8. No rate limiting ---
if ! grep -rqE "django-ratelimit\|throttle_classes\|REST_FRAMEWORK.*THROTTLE\|django_axes" "$REPO" 2>/dev/null; then
  finding "django-no-rate-limit" "No rate limiting detected — vulnerable to brute force attacks"
fi

# --- 9. Admin URL not customized ---
url_files=$(echo "$py_files" | grep -E "urls\.py$" || true)
if [ -n "$url_files" ]; then
  if echo "$url_files" | xargs grep -qE "path\s*\(\s*['\"]admin/" 2>/dev/null; then
    finding "django-default-admin-url" "Admin at /admin/ — use a non-obvious URL path"
  fi
fi

# --- 10. No logging configuration ---
if ! echo "$all_settings" | grep -q "LOGGING"; then
  finding "django-no-logging" "No LOGGING configuration — security events not captured"
fi

# --- 11. Outdated Django version ---
for dep_file in "$REPO/requirements.txt" "$REPO/requirements"/*.txt; do
  [ -f "$dep_file" ] || continue
  django_ver=$(grep -iE "^django[=><!~]" "$dep_file" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+" | head -1)
  if [ -n "$django_ver" ]; then
    major=$(echo "$django_ver" | cut -d. -f1)
    [ "$major" -lt 4 ] && error "django-outdated" "Django $django_ver — upgrade to 4.2+ LTS (security patches)"
  fi
done

# --- 12. File upload without size limit ---
echo "$py_files" | while IFS= read -r f; do
  if grep -qE "request\.FILES\|FileUploadParser\|MultiPartParser" "$f" 2>/dev/null; then
    if ! echo "$all_settings" | grep -qE "FILE_UPLOAD_MAX_MEMORY_SIZE\|DATA_UPLOAD_MAX_MEMORY_SIZE"; then
      finding "django-no-upload-limit" "File uploads detected but no size limits in settings"
    fi
  fi
done
