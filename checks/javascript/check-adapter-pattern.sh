#!/usr/bin/env bash
# checks/javascript/check-adapter-pattern.sh
# @see ADR-129
# Adapter/Wrapper pattern enforcement: external libraries used in 3+ files
# should be wrapped in a project-local adapter for single-point-of-change.
#
# Why: if you import dayjs in 30 files, swapping to Temporal API requires
# changing 30 files. With a wrapper (src/lib/time.ts), you change 1 file.
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

# Threshold: if a lib is imported in more than N files, it needs a wrapper
THRESHOLD=3

# Libraries that should be wrapped when used widely
# Format: "import-pattern|wrapper-indicator|suggested-wrapper-name"
WRAPPABLE_LIBS=(
  "dayjs|lib/time\|lib/date\|utils/date\|helpers/date|time adapter (src/lib/time.ts)"
  "date-fns|lib/time\|lib/date\|utils/date\|helpers/date|time adapter (src/lib/time.ts)"
  "moment|lib/time\|lib/date\|utils/date\|helpers/date|time adapter (src/lib/time.ts)"
  "axios|lib/http\|lib/api\|lib/fetch\|services/api\|utils/http|API client adapter (src/lib/api.ts)"
  "ky|lib/http\|lib/api\|lib/fetch\|services/api|API client adapter (src/lib/api.ts)"
  "localforage\|localStorage|lib/storage\|utils/storage\|hooks/useStorage|storage adapter (src/lib/storage.ts)"
  "winston\|pino\|bunyan|lib/logger\|utils/logger\|logger|logger adapter (src/lib/logger.ts)"
  "analytics\|mixpanel\|amplitude\|posthog|lib/analytics\|utils/tracking\|analytics|analytics adapter (src/lib/analytics.ts)"
  "stripe\|@stripe|lib/payment\|services/payment\|payment|payment adapter (src/lib/payment.ts)"
  "nodemailer\|sendgrid\|@sendgrid\|resend|lib/email\|services/email\|email|email adapter (src/lib/email.ts)"
  "firebase|lib/firebase\|services/firebase\|firebase/config|Firebase adapter (src/lib/firebase.ts)"
  "supabase\|@supabase|lib/supabase\|services/supabase\|db/client|Supabase adapter (src/lib/db.ts)"
  "prisma\|@prisma|lib/db\|lib/prisma\|db/client|database adapter (src/lib/db.ts)"
  "sentry\|@sentry|lib/monitoring\|lib/sentry\|utils/sentry|error tracking adapter (src/lib/monitoring.ts)"
  "i18next\|react-i18next|lib/i18n\|i18n/config\|utils/i18n|i18n adapter (src/lib/i18n.ts)"
  "toast\|sonner\|react-hot-toast\|notistack|lib/toast\|lib/notify\|utils/toast|notification adapter (src/lib/notify.ts)"
  "zod|lib/validation\|lib/schema\|utils/schema|schema adapter (src/lib/schema.ts) — only if used in 5+ files"
)

for entry in "${WRAPPABLE_LIBS[@]}"; do
  IMPORT_PATTERN=$(echo "$entry" | cut -d'|' -f1)
  WRAPPER_INDICATOR=$(echo "$entry" | cut -d'|' -f2)
  SUGGESTED=$(echo "$entry" | cut -d'|' -f3)

  # Count files that directly import this lib
  DIRECT_IMPORTS=$(grep -rl "from.*$IMPORT_PATTERN\|require.*$IMPORT_PATTERN" $SRC --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | \
    grep -v node_modules | grep -v "test\|spec\|mock" | wc -l)
  DIRECT_IMPORTS=$(echo "$DIRECT_IMPORTS" | tr -d ' ')

  # Skip if below threshold
  [ "${DIRECT_IMPORTS:-0}" -lt "$THRESHOLD" ] && continue

  # Check if a wrapper/adapter already exists
  if grep -rq "$WRAPPER_INDICATOR" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
    # Wrapper exists — but are components importing the lib directly anyway?
    # (bypassing the adapter)
    BYPASS=$(grep -rl "from ['\"].*$IMPORT_PATTERN" $SRC --include="*.tsx" 2>/dev/null | \
      grep -v node_modules | grep -v "lib/\|utils/\|services/\|adapter\|wrapper\|config" | wc -l)
    BYPASS=$(echo "$BYPASS" | tr -d ' ')
    [ "${BYPASS:-0}" -gt 2 ] && \
      finding "adapter-bypass" "$BYPASS files import '$IMPORT_PATTERN' directly — use your existing adapter instead"
  else
    finding "adapter-missing" "'$IMPORT_PATTERN' imported in $DIRECT_IMPORTS files without wrapper — create a local adapter"
  fi
done

# =============================================
# ADDITIONAL ADAPTER PATTERNS
# =============================================

# Environment variables: should go through a validated config
ENV_DIRECT=$(grep -rn "process\.env\.\|import\.meta\.env\." $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | \
  grep -v node_modules | grep -v "lib/\|config\|env\.\|test\|spec\|\.d\.ts" | wc -l)
ENV_DIRECT=$(echo "$ENV_DIRECT" | tr -d ' ')
[ "${ENV_DIRECT:-0}" -gt 5 ] && {
  if ! grep -rq "lib/env\|lib/config\|config/env\|env\.mjs\|@t3-oss/env" $SRC --include="*.ts" 2>/dev/null; then
    finding "adapter-env" "$ENV_DIRECT direct process.env reads — create config adapter (src/lib/env.ts) with validation"
  fi
}

# Router: direct useRouter usage should be wrapped for testing/abstraction
ROUTER_DIRECT=$(grep -rn "useRouter\|usePathname\|useSearchParams" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
ROUTER_DIRECT=$(echo "$ROUTER_DIRECT" | tr -d ' ')
[ "${ROUTER_DIRECT:-0}" -gt 8 ] && {
  if ! grep -rq "useNavigation\|useAppRouter\|lib/router\|hooks/useNav" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
    finding "adapter-router" "$ROUTER_DIRECT direct router hook calls — consider useNavigation() wrapper for testability"
  fi
}

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Adapter pattern: external libs properly wrapped\n"
exit 0
