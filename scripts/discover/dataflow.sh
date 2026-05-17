#!/usr/bin/env bash
# scripts/dataflow.sh — Map data sources, sinks, and transformations
# Usage: bash scripts/dataflow.sh [path]
# Answers: Where does data come from? Where does it go? What transforms it?
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__|\.test\.|\.spec\."

FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.py" -o -name "*.go" 2>/dev/null |
  grep -vE "$EXCLUDE" || true)
[ -z "$FILES" ] && {
  echo "  No source files found"
  exit 0
}

echo ""
echo "  ■ Data flow: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# === 1. Data Sources (where data comes IN) ===
echo "  ┌ Data Sources (input)"

# HTTP/API calls
API_FILES=$(echo "$FILES" | xargs grep -l "fetch(\|axios\|http\.\|HttpClient\|request(\|got(\|ky\." 2>/dev/null || true)
if [ -n "$API_FILES" ]; then
  URLS=$(echo "$API_FILES" | xargs grep -ohE "(https?://[^\s'\"]+|/api/[^\s'\"]+|['\"]/[a-z][a-z0-9/-]+['\"])" 2>/dev/null | sort -u | head -10)
  echo "  │ HTTP/API:"
  [ -n "$URLS" ] && echo "$URLS" | sed 's/^/  │   /'
  [ -z "$URLS" ] && echo "  │   (dynamic URLs — check $(echo "$API_FILES" | wc -l | tr -d ' ') files)"
fi

# Database
DB_FILES=$(echo "$FILES" | xargs grep -l "prisma\|mongoose\|sequelize\|typeorm\|knex\|pg\.\|mysql\|sqlite\|mongodb\|\.query(\|SELECT \|INSERT \|UPDATE \|DELETE " 2>/dev/null || true)
[ -n "$DB_FILES" ] && echo "  │ Database: $(echo "$DB_FILES" | wc -l | tr -d ' ') files interact with DB"

# File system
FS_FILES=$(echo "$FILES" | xargs grep -l "readFile\|writeFile\|createReadStream\|fopen\|fread\|os\.open\|ioutil\." 2>/dev/null || true)
[ -n "$FS_FILES" ] && echo "  │ File I/O: $(echo "$FS_FILES" | wc -l | tr -d ' ') files read/write filesystem"

# Environment / Config
ENV_VARS=$(echo "$FILES" | xargs grep -ohE "process\.env\.[A-Z_]+|getenv\(\"[^\"]+\"\)|os\.environ\[\"[^\"]+\"\]|Env\.[A-Z_]+" 2>/dev/null | sort -u)
if [ -n "$ENV_VARS" ]; then
  COUNT=$(echo "$ENV_VARS" | wc -l | tr -d ' ')
  echo "  │ Environment vars ($COUNT):"
  echo "$ENV_VARS" | sed 's/process\.env\.//; s/getenv("//; s/")//; s/os\.environ\["//; s/"\]//' | sort -u | sed 's/^/  │   /' | head -12
fi

# User input (forms, CLI args)
echo "$FILES" | xargs grep -l "stdin\|readline\|argv\|FormData\|useForm\|handleSubmit\|onChange\|onInput" 2>/dev/null | head -1 | grep -q . &&
  echo "  │ User input: forms/CLI args detected"

# Proxy configs (reveals hidden backend dependencies)
PROXY=$(find "$REPO" -maxdepth 1 -name "*proxy*" -o -name "*Proxy*" 2>/dev/null | grep -E "\.(js|json|ts)$" | head -1)
if [ -n "$PROXY" ]; then
  TARGETS=$(grep -oE "target.*['\"][^'\"]+['\"]" "$PROXY" 2>/dev/null | grep -oE "https*://[^'\"]*" | sort -u)
  [ -n "$TARGETS" ] && echo "  │ Proxy backends:" && echo "$TARGETS" | sed 's/^/  │   /'
fi

echo "  └"
echo ""

# === 2. Data Sinks (where data goes OUT) ===
echo "  ┌ Data Sinks (output)"

# API responses
echo "$FILES" | xargs grep -l "res\.json\|res\.send\|res\.status\|Response\.\|return.*json\|JsonResponse" 2>/dev/null | head -1 | grep -q . &&
  echo "  │ HTTP responses (API server)"

# Rendering / UI
echo "$FILES" | xargs grep -l "render\|innerHTML\|document\.write\|ReactDOM\|template:\|<template" 2>/dev/null | head -1 | grep -q . &&
  echo "  │ UI rendering (DOM/templates)"

# Logging
echo "$FILES" | xargs grep -l "console\.log\|logger\.\|winston\|pino\|log\.\|syslog\|fprintf" 2>/dev/null | head -1 | grep -q . &&
  echo "  │ Logging"

# File output
[ -n "$FS_FILES" ] && echo "  │ File output (write to disk)"

# External services (webhooks, queues, email)
echo "$FILES" | xargs grep -l "sendMail\|smtp\|SQS\|SNS\|kafka\|amqp\|webhook\|publish(" 2>/dev/null | head -1 | grep -q . &&
  echo "  │ External services (email/queue/webhook)"

echo "  └"
echo ""

# === 3. Data Transformations (what happens in between) ===
echo "  ┌ Transformations (processing)"

# Mapping/transform functions
MAPPERS=$(echo "$FILES" | xargs grep -l "\.map(\|\.reduce(\|\.filter(\|transform\|serialize\|deserialize\|parse\|format\|convert\|mapper\|dto\|DTO" 2>/dev/null | wc -l | tr -d ' ')
[ "$MAPPERS" -gt 0 ] && echo "  │ Data transforms: $MAPPERS files (map/filter/reduce/serialize)"

# Validation
VALIDATORS=$(echo "$FILES" | xargs grep -l "validate\|schema\|zod\|yup\|joi\|class-validator\|ajv" 2>/dev/null | wc -l | tr -d ' ')
[ "$VALIDATORS" -gt 0 ] && echo "  │ Validation: $VALIDATORS files"

# State management
echo "$FILES" | xargs grep -l "useState\|useReducer\|createStore\|createSlice\|BehaviorSubject\|signal(\|writable(" 2>/dev/null | head -1 | grep -q . &&
  echo "  │ State management (React/Redux/RxJS/Signals)"

# Caching
echo "$FILES" | xargs grep -l "cache\|Cache\|redis\|memcached\|lru\|memoize\|useMemo" 2>/dev/null | head -1 | grep -q . &&
  echo "  │ Caching layer"

echo "  └"
echo ""

# === 4. Mermaid data flow diagram ===
echo "  ┌ Flow diagram (mermaid)"
echo '  │ ```mermaid'
echo "  │ flowchart LR"
[ -n "$ENV_VARS" ] && echo "  │     ENV[Env Vars] --> App"
[ -n "$API_FILES" ] && echo "  │     ExtAPI[External APIs] --> App"
[ -n "$DB_FILES" ] && echo "  │     DB[(Database)] <--> App"
[ -n "$FS_FILES" ] && echo "  │     FS[File System] <--> App"
echo "$FILES" | xargs grep -l "stdin\|argv\|FormData\|handleSubmit" 2>/dev/null | head -1 | grep -q . &&
  echo "  │     User[User Input] --> App"
echo "$FILES" | xargs grep -l "res\.json\|render\|ReactDOM" 2>/dev/null | head -1 | grep -q . &&
  echo "  │     App --> UI[UI/Response]"
echo "$FILES" | xargs grep -l "console\.log\|logger\.\|winston" 2>/dev/null | head -1 | grep -q . &&
  echo "  │     App --> Logs[Logs]"
echo "$FILES" | xargs grep -l "sendMail\|kafka\|webhook" 2>/dev/null | head -1 | grep -q . &&
  echo "  │     App --> ExtSvc[External Services]"
echo '  │ ```'
echo "  └"
echo ""
