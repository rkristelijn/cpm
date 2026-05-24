#!/usr/bin/env bash
# checks/javascript/express/check-express-security.sh
# Express security anti-patterns: helmet, rate limiting, CORS, validation, error handling
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"express"' "$REPO/package.json" || exit 0

findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/routes" ] && SRC="$SRC $REPO/routes/"
[ -d "$REPO" ] && [ -f "$REPO/index.js" ] && SRC="$REPO"
[ -z "$SRC" ] && exit 0

# No helmet() middleware
while IFS= read -r file; do
  if grep -qE "express\(\)|createServer|http\.createServer" "$file" 2>/dev/null; then
    if ! grep -qE "helmet" "$file" 2>/dev/null; then
      findings_add "warning" "express-no-helmet" "No helmet() middleware for security headers" \
        "Add helmet() to set security HTTP headers" \
        "https://helmetjs.github.io/"
    fi
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No rate limiting (express-rate-limit)
while IFS= read -r file; do
  if grep -qE "express\(\)|createServer" "$file" 2>/dev/null; then
    if ! grep -qE "rateLimit|express-rate-limit" "$file" 2>/dev/null; then
      findings_add "warning" "express-no-rate-limit" "No rate limiting middleware" \
        "Add express-rate-limit to prevent brute force attacks" \
        "https://github.com/nfriedly/express-rate-limit"
    fi
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No input validation (express-validator/zod)
while IFS= read -r file; do
  if grep -qE "app\.(post|put|patch)\s*\(" "$file" 2>/dev/null; then
    if ! grep -qE "express-validator|zod|joi|yup|validate" "$file" 2>/dev/null; then
      findings_add "warning" "express-no-validation" "No input validation middleware" \
        "Add express-validator or zod for request validation" \
        "https://express-validator.github.io/docs/"
    fi
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No CORS configuration (or cors({origin: '*'}))
while IFS= read -r file; do
  if grep -qE "cors\s*\(\s*\{[^}]*origin\s*:\s*['\"]\*['\"]" "$file" 2>/dev/null; then
    findings_add "warning" "express-cors-wildcard" "CORS with origin: '*' (insecure)" \
      "Use specific origins: cors({ origin: ['https://example.com'] })" \
      "https://github.com/expressjs/cors"
  elif grep -qE "express\(\)" "$file" 2>/dev/null && ! grep -qE "cors" "$file" 2>/dev/null; then
    findings_add "warning" "express-no-cors" "No CORS configuration" \
      "Add cors() middleware for cross-origin requests" \
      "https://github.com/expressjs/cors"
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No error handling middleware (app.use((err,req,res,next)))
while IFS= read -r file; do
  if grep -qE "express\(\)" "$file" 2>/dev/null; then
    if ! grep -qE "app\.use\s*\(\s*function\s*\(\s*err" "$file" 2>/dev/null; then
      findings_add "warning" "express-no-error-handler" "No error handling middleware" \
        "Add app.use((err, req, res, next) => {...}) for error handling" \
        "https://expressjs.com/en/guide/error-handling.html"
    fi
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# req.body used without validation
while IFS= read -r file; do
  if grep -qE "req\.body\." "$file" 2>/dev/null; then
    if ! grep -qE "express-validator|zod" "$file" 2>/dev/null; then
      findings_add "warning" "express-unvalidated-body" "req.body accessed without validation" \
        "Validate req.body before use with express-validator or zod" \
        "https://expressjs.com/en/advanced/best-practice-security.html"
    fi
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# SQL/NoSQL in route handler (no service layer)
while IFS= read -r file; do
  if grep -qE "\.query\s*\(|db\.collection|INSERT INTO|SELECT .* FROM" "$file" 2>/dev/null; then
    if grep -qE "app\.(get|post|put|delete|patch)" "$file" 2>/dev/null; then
      findings_add "warning" "express-db-in-route" "Database operations in route handler" \
        "Move DB logic to service layer. Route handlers should only call services" \
        "https://expressjs.com/en/advanced/best-practice-security.html"
    fi
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No request size limit (json({limit}))
while IFS= read -r file; do
  if grep -qE "express\.json\(\)" "$file" 2>/dev/null && ! grep -qE "limit:" "$file" 2>/dev/null; then
    findings_add "warning" "express-no-size-limit" "No request size limit on express.json()" \
      "Add limit: '10kb' or similar to prevent DoS attacks" \
      "https://expressjs.com/en/api.html"
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# Secrets in code (process.env without validation)
while IFS= read -r file; do
  if grep -qE "process\.env\.(API_KEY|SECRET|PASSWORD|TOKEN)" "$file" 2>/dev/null; then
    findings_add "warning" "express-hardcoded-secret" "Potential hardcoded secret in code" \
      "Use process.env with validation library like envalid" \
      "https://github.com/af/envalid"
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No HTTPS redirect in production
while IFS= read -r file; do
  if grep -qE "NODE_ENV" "$file" 2>/dev/null && ! grep -qE "https|redirect.*https" "$file" 2>/dev/null; then
    findings_add "warning" "express-no-https-redirect" "No HTTPS redirect for production" \
      "Add middleware to redirect HTTP to HTTPS in production" \
      "https://expressjs.com/en/advanced/best-practice-security.html"
  fi
done < <(find $REPO -name "*.js" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

echo "  ✓ Express security patterns checked"