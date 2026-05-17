#!/usr/bin/env bash
# scripts/techradar.sh — Full technology radar: detect everything in use
# Usage: bash scripts/techradar.sh [path]
# Detects: ORM, state, auth, API style, logging, deprecations, docs, comments
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__|\.test\.|\.spec\."

FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.py" -o -name "*.go" \
  -o -name "*.java" -o -name "*.cs" -o -name "*.rb" 2>/dev/null | grep -vE "$EXCLUDE" || true)
[ -z "$FILES" ] && {
  echo "  No source files found"
  exit 0
}

echo ""
echo "  ■ Tech Radar: $(basename "$(cd "$REPO" && pwd)")"
echo ""

found() { printf "    ✓ %-25s %s\n" "$1" "$2"; }
section() { echo "  $1:"; }

# === ORM / Database Layer ===
section "Database / ORM"
echo "$FILES" | xargs grep -l "prisma\|PrismaClient" 2>/dev/null | head -1 | grep -q . && found "Prisma" "ORM"
echo "$FILES" | xargs grep -l "typeorm\|TypeORM\|@Entity\|@Column" 2>/dev/null | head -1 | grep -q . && found "TypeORM" "ORM"
echo "$FILES" | xargs grep -l "sequelize\|Sequelize" 2>/dev/null | head -1 | grep -q . && found "Sequelize" "ORM"
echo "$FILES" | xargs grep -l "mongoose\|Schema(\|model(" 2>/dev/null | head -1 | grep -q . && found "Mongoose" "MongoDB ODM"
echo "$FILES" | xargs grep -l "knex\|Knex" 2>/dev/null | head -1 | grep -q . && found "Knex" "Query builder"
echo "$FILES" | xargs grep -l "drizzle\|drizzleOrm" 2>/dev/null | head -1 | grep -q . && found "Drizzle" "ORM"
echo "$FILES" | xargs grep -l "kysely\|Kysely" 2>/dev/null | head -1 | grep -q . && found "Kysely" "Type-safe SQL"
echo "$FILES" | xargs grep -l "SQLAlchemy\|sqlalchemy" 2>/dev/null | head -1 | grep -q . && found "SQLAlchemy" "Python ORM"
echo "$FILES" | xargs grep -l "ActiveRecord\|has_many\|belongs_to" 2>/dev/null | head -1 | grep -q . && found "ActiveRecord" "Ruby ORM"
echo "$FILES" | xargs grep -l "Entity Framework\|DbContext\|DbSet" 2>/dev/null | head -1 | grep -q . && found "Entity Framework" ".NET ORM"
echo ""

# === State Management ===
section "State Management"
echo "$FILES" | xargs grep -l "createStore\|createSlice\|configureStore\|@reduxjs" 2>/dev/null | head -1 | grep -q . && found "Redux/RTK" ""
echo "$FILES" | xargs grep -l "zustand\|create(" 2>/dev/null | grep -v "prisma" | head -1 | grep -q . && found "Zustand" ""
echo "$FILES" | xargs grep -l "@ngrx\|createEffect\|createReducer" 2>/dev/null | head -1 | grep -q . && found "NgRx" "Angular"
echo "$FILES" | xargs grep -l "BehaviorSubject\|ReplaySubject\|Subject(" 2>/dev/null | head -1 | grep -q . && found "RxJS Subjects" "Reactive state"
echo "$FILES" | xargs grep -l "signal(\|computed(\|effect(" 2>/dev/null | head -1 | grep -q . && found "Signals" "Angular/Solid"
echo "$FILES" | xargs grep -l "useContext\|createContext" 2>/dev/null | head -1 | grep -q . && found "React Context" ""
echo "$FILES" | xargs grep -l "pinia\|defineStore" 2>/dev/null | head -1 | grep -q . && found "Pinia" "Vue"
echo "$FILES" | xargs grep -l "mobx\|observable\|makeAutoObservable" 2>/dev/null | head -1 | grep -q . && found "MobX" ""
echo "$FILES" | xargs grep -l "jotai\|atom(" 2>/dev/null | head -1 | grep -q . && found "Jotai" "Atomic state"
echo "$FILES" | xargs grep -l "recoil\|useRecoilState" 2>/dev/null | head -1 | grep -q . && found "Recoil" ""
echo ""

# === API Style ===
section "API Layer"
echo "$FILES" | xargs grep -l "GraphQL\|gql\`\|typeDefs\|resolvers\|useQuery\|useMutation" 2>/dev/null | head -1 | grep -q . && found "GraphQL" ""
echo "$FILES" | xargs grep -l "tRPC\|trpc\|createTRPCRouter\|t\.procedure" 2>/dev/null | head -1 | grep -q . && found "tRPC" "End-to-end typesafe"
echo "$FILES" | xargs grep -l "swagger\|openapi\|@ApiProperty\|@ApiOperation" 2>/dev/null | head -1 | grep -q . && found "OpenAPI/Swagger" "REST spec"
echo "$FILES" | xargs grep -l "\.get(\|\.post(\|\.put(\|\.delete(" 2>/dev/null | grep -v "test" | head -1 | grep -q . && found "REST" "HTTP methods"
echo "$FILES" | xargs grep -l "WebSocket\|socket\.io\|ws\.\|wss:" 2>/dev/null | head -1 | grep -q . && found "WebSocket" "Real-time"
echo "$FILES" | xargs grep -l "grpc\|protobuf\|\.proto" 2>/dev/null | head -1 | grep -q . && found "gRPC" "Protocol Buffers"
echo ""

# === Authentication / Authorization ===
section "Auth"
echo "$FILES" | xargs grep -l "next-auth\|NextAuth\|getServerSession" 2>/dev/null | head -1 | grep -q . && found "NextAuth/Auth.js" ""
echo "$FILES" | xargs grep -l "passport\|Passport" 2>/dev/null | head -1 | grep -q . && found "Passport.js" ""
echo "$FILES" | xargs grep -l "jsonwebtoken\|jwt\|JWT\|verify.*token\|sign.*token" 2>/dev/null | head -1 | grep -q . && found "JWT" "Token-based"
echo "$FILES" | xargs grep -l "oauth\|OAuth\|oauth2" 2>/dev/null | head -1 | grep -q . && found "OAuth2" ""
echo "$FILES" | xargs grep -l "clerk\|@clerk" 2>/dev/null | head -1 | grep -q . && found "Clerk" "Auth service"
echo "$FILES" | xargs grep -l "supabase.*auth\|createClient" 2>/dev/null | head -1 | grep -q . && found "Supabase Auth" ""
echo "$FILES" | xargs grep -l "firebase.*auth\|getAuth\|signInWith" 2>/dev/null | head -1 | grep -q . && found "Firebase Auth" ""
echo "$FILES" | xargs grep -l "bcrypt\|argon2\|scrypt\|hashPassword" 2>/dev/null | head -1 | grep -q . && found "Password hashing" "bcrypt/argon2"
echo "$FILES" | xargs grep -l "RBAC\|role.*guard\|canActivate\|authorize\|@Roles\|hasPermission" 2>/dev/null | head -1 | grep -q . && found "RBAC" "Role-based access"
echo ""

# === Logging / Tracing / Observability ===
section "Logging & Observability"
echo "$FILES" | xargs grep -l "winston\|createLogger" 2>/dev/null | head -1 | grep -q . && found "Winston" "Logger"
echo "$FILES" | xargs grep -l "pino\|pino(" 2>/dev/null | head -1 | grep -q . && found "Pino" "Fast logger"
echo "$FILES" | xargs grep -l "bunyan" 2>/dev/null | head -1 | grep -q . && found "Bunyan" "Logger"
echo "$FILES" | xargs grep -l "morgan\|morgan(" 2>/dev/null | head -1 | grep -q . && found "Morgan" "HTTP logger"
echo "$FILES" | xargs grep -l "sentry\|Sentry\|@sentry" 2>/dev/null | head -1 | grep -q . && found "Sentry" "Error tracking"
echo "$FILES" | xargs grep -l "datadog\|dd-trace\|StatsD" 2>/dev/null | head -1 | grep -q . && found "Datadog" "APM"
echo "$FILES" | xargs grep -l "opentelemetry\|otel\|trace\.getTracer" 2>/dev/null | head -1 | grep -q . && found "OpenTelemetry" "Distributed tracing"
echo "$FILES" | xargs grep -l "newrelic\|newRelicAgent" 2>/dev/null | head -1 | grep -q . && found "New Relic" "APM"
echo "$FILES" | xargs grep -l "log4j\|log4js\|getLogger" 2>/dev/null | head -1 | grep -q . && found "Log4j/Log4js" "Logger"
echo ""

# === Rendering Strategy ===
section "Rendering Strategy"
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && found "Next.js" "SSR/SSG/ISR"
[ -f "$REPO/nuxt.config.ts" ] || [ -f "$REPO/nuxt.config.js" ] && found "Nuxt" "SSR/SSG (Vue)"
[ -f "$REPO/gatsby-config.js" ] || [ -f "$REPO/gatsby-config.ts" ] && found "Gatsby" "SSG"
[ -f "$REPO/astro.config.mjs" ] && found "Astro" "Islands/SSG"
[ -f "$REPO/remix.config.js" ] && found "Remix" "SSR"
echo "$FILES" | xargs grep -l "createBrowserRouter\|BrowserRouter\|HashRouter" 2>/dev/null | head -1 | grep -q . && found "SPA (client-only)" "React Router"
echo ""

# === Styling ===
section "Styling & UI"
echo "$FILES" | xargs grep -l "tailwind\|@apply" 2>/dev/null | head -1 | grep -q . && found "Tailwind CSS" "Utility-first"
[ -f "$REPO/tailwind.config.js" ] || [ -f "$REPO/tailwind.config.ts" ] && found "Tailwind config" ""
echo "$FILES" | xargs grep -l "styled-components\|@emotion\|css\`" 2>/dev/null | head -1 | grep -q . && found "CSS-in-JS" "styled/emotion"
echo "$FILES" | xargs grep -l "\.module\.css\|\.module\.scss" 2>/dev/null | head -1 | grep -q . && found "CSS Modules" "Scoped"
echo "$FILES" | xargs grep -l "@mui\|material-ui\|Material" 2>/dev/null | head -1 | grep -q . && found "Material UI" "Component lib"
echo "$FILES" | xargs grep -l "shadcn\|@radix-ui" 2>/dev/null | head -1 | grep -q . && found "shadcn/Radix" "Headless UI"
echo "$FILES" | xargs grep -l "bootstrap\|Bootstrap" 2>/dev/null | head -1 | grep -q . && found "Bootstrap" ""
echo ""

# === Validation & Serialization ===
section "Validation"
echo "$FILES" | xargs grep -l "zod\|z\.object\|z\.string" 2>/dev/null | head -1 | grep -q . && found "Zod" "Schema validation"
echo "$FILES" | xargs grep -l "yup\|Yup\.\|yup\.object" 2>/dev/null | head -1 | grep -q . && found "Yup" ""
echo "$FILES" | xargs grep -l "joi\|Joi\." 2>/dev/null | head -1 | grep -q . && found "Joi" ""
echo "$FILES" | xargs grep -l "class-validator\|@IsString\|@IsEmail" 2>/dev/null | head -1 | grep -q . && found "class-validator" "Decorator-based"
echo "$FILES" | xargs grep -l "ajv\|Ajv" 2>/dev/null | head -1 | grep -q . && found "Ajv" "JSON Schema"
echo ""

# === Queues & Messaging ===
section "Async Messaging / Queues"
echo "$FILES" | xargs grep -l "bull\|Bull\|BullMQ\|@InjectQueue" 2>/dev/null | head -1 | grep -q . && found "BullMQ" "Redis queue"
echo "$FILES" | xargs grep -l "SQS\|sqs\|SendMessageCommand" 2>/dev/null | head -1 | grep -q . && found "AWS SQS" ""
echo "$FILES" | xargs grep -l "kafka\|Kafka\|KafkaJS" 2>/dev/null | head -1 | grep -q . && found "Kafka" "Event streaming"
echo "$FILES" | xargs grep -l "amqp\|RabbitMQ\|rabbitmq" 2>/dev/null | head -1 | grep -q . && found "RabbitMQ" "AMQP"
echo "$FILES" | xargs grep -l "pubsub\|PubSub\|SNS\|EventBridge" 2>/dev/null | head -1 | grep -q . && found "Pub/Sub" "Event-driven"
echo ""

# === CI/CD ===
section "CI/CD & Deployment"
[ -d "$REPO/.github/workflows" ] && found "GitHub Actions" "$(ls "$REPO/.github/workflows/" | wc -l | tr -d ' ') workflows"
[ -f "$REPO/.gitlab-ci.yml" ] && found "GitLab CI" ""
[ -f "$REPO/Jenkinsfile" ] && found "Jenkins" ""
[ -f "$REPO/.circleci/config.yml" ] && found "CircleCI" ""
[ -f "$REPO/Dockerfile" ] && found "Docker" ""
[ -f "$REPO/docker-compose.yml" ] && found "Docker Compose" ""
[ -f "$REPO/vercel.json" ] && found "Vercel" "Serverless deploy"
[ -f "$REPO/netlify.toml" ] && found "Netlify" ""
echo ""

# === IaC ===
section "Infrastructure as Code"
find "$REPO" -name "*.tf" -maxdepth 3 2>/dev/null | head -1 | grep -q . && found "Terraform" "Cloud-agnostic"
find "$REPO" -name "cdk.json" -maxdepth 2 2>/dev/null | head -1 | grep -q . && found "AWS CDK" "TypeScript IaC"
find "$REPO" -name "Pulumi.yaml" -maxdepth 2 2>/dev/null | head -1 | grep -q . && found "Pulumi" ""
find "$REPO" -name "serverless.yml" -maxdepth 2 2>/dev/null | head -1 | grep -q . && found "Serverless Framework" ""
[ -f "$REPO/sam-template.yaml" ] || [ -f "$REPO/template.yaml" ] && found "AWS SAM" ""
echo ""

# === Secret Management ===
section "Secret Management"
echo "$FILES" | xargs grep -l "vault\|Vault\|hashicorp" 2>/dev/null | head -1 | grep -q . && found "HashiCorp Vault" ""
echo "$FILES" | xargs grep -l "SecretsManager\|getSecretValue" 2>/dev/null | head -1 | grep -q . && found "AWS Secrets Manager" ""
echo "$FILES" | xargs grep -l "dotenv\|config()\|\.env" 2>/dev/null | head -1 | grep -q . && found "dotenv (.env files)" ""
echo "$FILES" | xargs grep -l "KeyVault\|@azure/keyvault" 2>/dev/null | head -1 | grep -q . && found "Azure Key Vault" ""
echo ""

# === Feature Flags ===
section "Feature Flags"
echo "$FILES" | xargs grep -l "launchdarkly\|LaunchDarkly\|ldclient" 2>/dev/null | head -1 | grep -q . && found "LaunchDarkly" ""
echo "$FILES" | xargs grep -l "unleash\|Unleash" 2>/dev/null | head -1 | grep -q . && found "Unleash" "Open source"
echo "$FILES" | xargs grep -l "featureFlag\|feature_flag\|FEATURE_\|isFeatureEnabled" 2>/dev/null | head -1 | grep -q . && found "Custom feature flags" "env/config based"
echo "$FILES" | xargs grep -l "posthog\|PostHog" 2>/dev/null | head -1 | grep -q . && found "PostHog" "Analytics + flags"
echo ""

# === Deprecations & TODOs (the code tells the story) ===
section "Deprecations & Technical Debt"
DEPRECATED=$(echo "$FILES" | xargs grep -cn "@deprecated\|@Deprecated\|DEPRECATED\|deprecated" 2>/dev/null | awk -F: '$2>0{s+=$2} END{print s+0}')
TODOS=$(echo "$FILES" | xargs grep -cn "TODO\|FIXME\|HACK\|XXX\|TEMP" 2>/dev/null | awk -F: '$2>0{s+=$2} END{print s+0}')
NOSONAR=$(echo "$FILES" | xargs grep -cn "NOSONAR\|noinspection\|eslint-disable\|@ts-ignore\|@ts-expect-error" 2>/dev/null | awk -F: '$2>0{s+=$2} END{print s+0}')
[ "$DEPRECATED" -gt 0 ] && found "@deprecated" "$DEPRECATED occurrences"
[ "$TODOS" -gt 0 ] && found "TODO/FIXME/HACK" "$TODOS markers"
[ "$NOSONAR" -gt 0 ] && found "Suppressed warnings" "$NOSONAR (eslint-disable, @ts-ignore, etc)"
echo ""

# === Documentation from code (comments, JSDoc, etc) ===
section "Documentation signals"
JSDOC=$(echo "$FILES" | xargs grep -c "/\*\*" 2>/dev/null | awk -F: '$2>0{s+=$2} END{print s+0}')
[ "$JSDOC" -gt 0 ] && found "JSDoc/Doxygen blocks" "$JSDOC"
[ -f "$REPO/README.md" ] && found "README.md" "$(wc -l <"$REPO/README.md" | tr -d ' ') lines"
[ -f "$REPO/CONTRIBUTING.md" ] && found "CONTRIBUTING.md" "exists"
[ -f "$REPO/CHANGELOG.md" ] && found "CHANGELOG.md" "exists"
[ -d "$REPO/docs" ] && found "docs/" "$(find "$REPO/docs" -type f | wc -l | tr -d ' ') files"
INLINE=$(echo "$FILES" | xargs grep -c "^//" 2>/dev/null | awk -F: '$2>0{s+=$2} END{print s+0}')
[ "$INLINE" -gt 0 ] && found "Inline comments (//)" "$INLINE"
echo ""
