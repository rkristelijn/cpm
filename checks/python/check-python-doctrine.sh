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

# Detect Python files
py_files=$(find "$REPO" -type f -name "*.py" 2>/dev/null | head -100)
[[ -z "$py_files" ]] && exit 0

# Detect framework
has_django=false
has_fastapi=false
has_flask=false

for f in $py_files; do
    if grep -l -E "django|fastapi|flask" "$f" 2>/dev/null; then
        :
    fi
done

# Check requirements.txt / setup.py / pyproject.toml for frameworks
if grep -rqE "django" "$REPO" 2>/dev/null; then
    has_django=true
fi
if grep -rqE "fastapi" "$REPO" 2>/dev/null; then
    has_fastapi=true
fi
if grep -rqE "flask" "$REPO" 2>/dev/null; then
    has_flask=true
fi

# Django checks
if $has_django; then
    # Fat views (>200 lines)
    for f in $py_files; do
        if [[ $(basename "$f") == "views.py" ]]; then
            lines=$(wc -l < "$f" 2>/dev/null || echo 0)
            if [[ $lines -gt 200 ]]; then
                findings_add "warning" "django-fat-view" "views.py has $lines lines (>200), consider service layer"
            fi
        fi
    done

    # Raw SQL with string format
    for f in $py_files; do
        if grep -qE "cursor\.execute\s*\([^)]*['\"][^)]*%[sr]" "$f" 2>/dev/null; then
            findings_add "error" "django-raw-sql" "$f: raw SQL with % formatting, use parameterized queries"
        fi
    done

    # DEBUG=True or hardcoded SECRET_KEY
    for f in $py_files; do
        if grep -qE "DEBUG\s*=\s*True" "$f" 2>/dev/null; then
            findings_add "error" "django-debug-true" "$f: DEBUG=True in code, use environment variable"
        fi
        if grep -qE "SECRET_KEY\s*=\s*['\"][^'\"]+['\"]" "$f" 2>/dev/null; then
            findings_add "error" "django-hardcoded-secret" "$f: hardcoded SECRET_KEY, use environment variable"
        fi
    done

    # No AUTH_USER_MODEL
    settings_files=$(find "$REPO" -type f -name "settings.py" 2>/dev/null)
    if ! grep -rqE "AUTH_USER_MODEL" $settings_files 2>/dev/null; then
        findings_add "warning" "django-no-custom-user" "No AUTH_USER_MODEL found, consider custom user model"
    fi
fi

# FastAPI checks
if $has_fastapi; then
    for f in $py_files; do
        # No Depends() for DB session
        if grep -qE "@.*\.get\s*\(|@.*\.post\s*\(" "$f" 2>/dev/null; then
            if ! grep -qE "Depends\s*\(" "$f" 2>/dev/null; then
                findings_add "warning" "fastapi-no-depends" "$f: route without Depends() for DB session"
            fi
        fi

        # No response_model on routes
        if grep -qE "@.*\.get\s*\(|@.*\.post\s*\(|@.*\.put\s*\(" "$f" 2>/dev/null; then
            if ! grep -qE "response_model" "$f" 2>/dev/null; then
                findings_add "warning" "fastapi-no-response-model" "$f: route without response_model, potential data leak"
            fi
        fi

        # Sync def on IO routes (heuristic: contains await but defined sync)
        if grep -qE "def\s+\w+\s*\([^)]*\)\s*:\.*\n.*await" "$f" 2>/dev/null; then
            findings_add "warning" "fastapi-sync-io" "$f: sync function contains await, use async def"
        fi

        # No Pydantic model for request body
        if grep -qE "def\s+\w+\s*\([^)]*request\s*:\s*Request" "$f" 2>/dev/null; then
            if ! grep -qE "BaseModel|pydantic" "$f" 2>/dev/null; then
                findings_add "warning" "fastapi-no-pydantic" "$f: request handler without Pydantic model"
            fi
        fi
    done
fi

# Flask checks
if $has_flask; then
    for f in $py_files; do
        # Only check files that import Flask
        if ! grep -qE "from flask|import flask" "$f" 2>/dev/null; then
            continue
        fi

        # App factory pattern check
        if grep -qE "app\s*=\s*Flask\s*\(__name__\)" "$f" 2>/dev/null; then
            findings_add "warning" "flask-no-factory" "$f: Flask app created at module level, use app factory"
        fi

        # No blueprints
        if ! grep -qE "Blueprint" "$f" 2>/dev/null; then
            findings_add "warning" "flask-no-blueprints" "$f: no Blueprint usage detected"
        fi

        # Hardcoded secret key
        if grep -qE "secret_key\s*=\s*['\"][^'\"]+['\"]" "$f" 2>/dev/null; then
            findings_add "error" "flask-hardcoded-secret" "$f: hardcoded secret_key, use environment variable"
        fi

        # flask.g for business logic
        if grep -qE "flask\.g\.\w+\s*=" "$f" 2>/dev/null; then
            findings_add "warning" "flask-g-business-logic" "$f: flask.g used for business logic, use proper storage"
        fi
    done
fi