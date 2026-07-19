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
# Format: "import-pattern|wrapper-indicator|category"
WRAPPABLE_LIBS=(
  # --- Date/Time ---
  "dayjs|lib/time\|lib/date\|utils/date\|helpers/date|date"
  "date-fns|lib/time\|lib/date\|utils/date\|helpers/date|date"
  "moment|lib/time\|lib/date\|utils/date\|helpers/date|date"
  "luxon|lib/time\|lib/date\|utils/date|date"
  "temporal-polyfill|lib/time\|lib/date|date"

  # --- HTTP / API ---
  "axios|lib/http\|lib/api\|lib/fetch\|services/api\|utils/http|http"
  "ky|lib/http\|lib/api\|lib/fetch\|services/api|http"
  "got|lib/http\|lib/api\|services/api|http"
  "superagent|lib/http\|lib/api|http"
  "ofetch|lib/http\|lib/api|http"

  # --- Storage ---
  "localforage|lib/storage\|utils/storage\|hooks/useStorage|storage"
  "idb|lib/storage\|lib/db\|utils/storage|storage"
  "@react-native-async-storage|lib/storage\|utils/storage|storage"

  # --- Logging ---
  "winston|lib/logger\|utils/logger\|logger|logging"
  "pino|lib/logger\|utils/logger|logging"
  "bunyan|lib/logger\|utils/logger|logging"
  "loglevel|lib/logger\|utils/logger|logging"

  # --- Analytics / Tracking ---
  "mixpanel|lib/analytics\|utils/tracking\|analytics|analytics"
  "amplitude|lib/analytics\|utils/tracking|analytics"
  "posthog|lib/analytics\|utils/tracking|analytics"
  "@segment|lib/analytics\|utils/tracking|analytics"
  "plausible|lib/analytics\|utils/tracking|analytics"

  # --- Payment ---
  "stripe|lib/payment\|services/payment\|payment|payment"
  "@stripe|lib/payment\|services/payment|payment"
  "paypal|lib/payment\|services/payment|payment"

  # --- Email ---
  "nodemailer|lib/email\|services/email\|email|email"
  "@sendgrid|lib/email\|services/email|email"
  "resend|lib/email\|services/email|email"
  "postmark|lib/email\|services/email|email"

  # --- Database / ORM ---
  "prisma|lib/db\|lib/prisma\|db/client|database"
  "@prisma|lib/db\|lib/prisma\|db/client|database"
  "drizzle-orm|lib/db\|db/client|database"
  "typeorm|lib/db\|db/client|database"
  "knex|lib/db\|db/client|database"
  "mongoose|lib/db\|db/client\|models/|database"
  "sequelize|lib/db\|db/client|database"

  # --- BaaS ---
  "firebase|lib/firebase\|services/firebase\|firebase/config|baas"
  "supabase|lib/supabase\|services/supabase\|db/client|baas"
  "@supabase|lib/supabase\|services/supabase|baas"
  "@aws-sdk|lib/aws\|services/aws\|aws/client|cloud"
  "@google-cloud|lib/gcp\|services/gcp|cloud"
  "@azure|lib/azure\|services/azure|cloud"

  # --- Auth ---
  "jsonwebtoken|lib/auth\|lib/jwt\|utils/auth|auth"
  "bcrypt|lib/auth\|lib/crypto\|utils/auth|auth"
  "passport|lib/auth\|services/auth|auth"
  "next-auth|lib/auth\|auth/config|auth"
  "@clerk|lib/auth\|services/auth|auth"
  "lucia|lib/auth\|services/auth|auth"

  # --- Error Tracking / Monitoring ---
  "sentry|lib/monitoring\|lib/sentry\|utils/sentry|monitoring"
  "@sentry|lib/monitoring\|lib/sentry|monitoring"
  "datadog|lib/monitoring\|lib/datadog|monitoring"
  "newrelic|lib/monitoring\|lib/newrelic|monitoring"
  "bugsnag|lib/monitoring\|lib/bugsnag|monitoring"

  # --- i18n ---
  "i18next|lib/i18n\|i18n/config\|utils/i18n|i18n"
  "react-i18next|lib/i18n\|i18n/config|i18n"
  "next-intl|lib/i18n\|i18n/config|i18n"
  "@formatjs|lib/i18n\|i18n/config|i18n"

  # --- Notifications / Toast ---
  "sonner|lib/toast\|lib/notify\|utils/toast|notification"
  "react-hot-toast|lib/toast\|lib/notify|notification"
  "notistack|lib/toast\|lib/notify|notification"
  "react-toastify|lib/toast\|lib/notify|notification"

  # --- File Upload / Media ---
  "multer|lib/upload\|services/upload|upload"
  "sharp|lib/image\|services/image\|utils/image|media"
  "cloudinary|lib/media\|services/media\|lib/cloudinary|media"
  "@uploadthing|lib/upload\|services/upload|upload"

  # --- Queue / Jobs ---
  "bullmq|lib/queue\|services/queue\|lib/jobs|queue"
  "bull|lib/queue\|services/queue|queue"
  "agenda|lib/queue\|services/queue|queue"

  # --- Cache ---
  "ioredis|lib/cache\|lib/redis\|services/cache|cache"
  "redis|lib/cache\|lib/redis\|services/cache|cache"
  "node-cache|lib/cache\|services/cache|cache"

  # --- Validation (only if 5+ files) ---
  "zod|lib/validation\|lib/schema\|utils/schema|validation"

  # --- PDF / Docs ---
  "pdfkit|lib/pdf\|services/pdf|docs"
  "puppeteer|lib/browser\|services/pdf\|lib/puppeteer|docs"
  "jspdf|lib/pdf\|services/pdf|docs"
)

for entry in "${WRAPPABLE_LIBS[@]}"; do
  IMPORT_PATTERN=$(echo "$entry" | cut -d'|' -f1)
  WRAPPER_INDICATOR=$(echo "$entry" | cut -d'|' -f2)
  CATEGORY=$(echo "$entry" | cut -d'|' -f3)

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
    finding "adapter-missing" "'$IMPORT_PATTERN' ($CATEGORY) imported in $DIRECT_IMPORTS files — create src/lib/$CATEGORY.ts adapter"
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
