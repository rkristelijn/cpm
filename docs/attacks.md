# Attack Detection Rules

A catalog of frontend and backend attack patterns detected by the cpm rule engine.

30 rules total: 13 frontend (web), 17 backend. Each rule runs as a regex pattern matcher against source files.

## Frontend Attacks (rules/web/)

### WEB-SEC-010: Clickjacking / Missing Frame Protection

**Severity:** warning | **CWE-1021**

Detects missing or misconfigured frame protection headers that allow attackers to embed your page in an iframe and trick users into clicking hidden elements.

**Patterns detected:**
- X-Frame-Options set to ALLOWALL — allows clickjacking. Use DENY or SAMEORIGIN
- Helmet frameguard set to allow — enables clickjacking. Use 'deny' or 'sameorigin'
- Django X_FRAME_OPTIONS set to ALLOW — clickjacking risk. Use 'DENY'
- CSP frame-ancestors set to * — allows any site to frame this page (clickjacking)

**Fix:** Set `X-Frame-Options: DENY` and CSP `frame-ancestors 'self'`.

---

### WEB-SEC-011: Tabnabbing via target=_blank

**Severity:** warning | **CWE-1022**

Detects links with `target=_blank` that lack `rel=noopener`, allowing the opened page to access `window.opener` and redirect the original tab.

**Patterns detected:**
- target='_blank' found — ensure rel='noopener noreferrer' is also set to prevent reverse tabnabbing
- window.open() — ensure 'noopener' feature is specified to prevent opener reference leak

**Fix:** Add `rel='noopener noreferrer'` to links with `target=_blank`. Use `window.open(url, '_blank', 'noopener')`.

---

### WEB-SEC-012: HTML Base Tag Injection

**Severity:** warning | **CWE-79**

Detects `<base>` tags that, if user-controlled, allow attackers to hijack all relative URLs and form actions on the page.

**Patterns detected:**
- `<base>` tag sets document base URL — if user-controlled, all relative URLs/forms can be hijacked
- Dynamic `<base>` tag injection via innerHTML — base jumping attack vector

**Fix:** Avoid `<base>` tag or hardcode it. Set CSP `base-uri 'self'` to prevent injection.

---

### WEB-SEC-013: Prototype Pollution

**Severity:** error | **CWE-1321**

Detects patterns that allow attackers to inject properties into JavaScript object prototypes via `__proto__` or `constructor.prototype`, potentially affecting all objects in the application.

**Patterns detected:**
- `__proto__` access — prototype pollution vector. Use Object.create(null) for dictionaries
- constructor.prototype access — prototype pollution. Validate and sanitize object keys
- Object.assign with user input — prototype pollution risk. Use allowlist of permitted keys
- Deep merge with user input — prototype pollution risk. Use allowlisted key merge
- JSON.parse of user input can contain `__proto__` — sanitize or use Object.create(null)

**Fix:** Freeze prototypes with `Object.freeze(Object.prototype)`. Validate keys against allowlist. Use `Map` instead of plain objects.

---

### WEB-SEC-014: DOM XSS via Dangerous Sinks

**Severity:** error | **CWE-79**

Detects dangerous DOM manipulation methods that can execute attacker-controlled HTML or JavaScript when fed user input.

**Patterns detected:**
- innerHTML assignment — DOM XSS risk if value contains user input. Use textContent or DOMPurify.sanitize()
- outerHTML assignment — DOM XSS risk. Use safe DOM APIs or sanitize input
- document.write() — XSS risk and blocks page rendering. Use DOM APIs instead
- document.writeln() — same risks as document.write(). Use DOM APIs
- insertAdjacentHTML() with dynamic content — XSS risk. Sanitize input first

**Fix:** Use `textContent` for text, `DOMPurify.sanitize()` for HTML. Prefer React/Vue rendering over raw DOM.

---

### WEB-SEC-015: Insecure postMessage Usage

**Severity:** warning | **CWE-345**

Detects `postMessage` calls with wildcard origin and message event listeners that don't validate the sender's origin.

**Patterns detected:**
- postMessage with wildcard origin '*' — any window can receive the message. Specify exact origin
- Message event listener — ensure event.origin is validated before processing event.data

**Fix:** Always specify target origin in `postMessage()`. Always check `event.origin` in message handlers.

---

### WEB-SEC-016: CORS Misconfiguration

**Severity:** error | **CWE-942**

Detects overly permissive CORS configurations that allow any website to make authenticated cross-origin requests to your API.

**Patterns detected:**
- CORS Access-Control-Allow-Origin set to * — allows any site to make requests. Restrict to specific origins
- CORS origin set to wildcard — allows any domain. Specify allowed origins explicitly
- Django CORS_ALLOW_ALL_ORIGINS = True — allows all cross-origin requests. Specify CORS_ALLOWED_ORIGINS
- cors() middleware with no config — allows all origins by default. Pass explicit origin option
- CORS AllowedOrigins set to wildcard — restrict to specific trusted domains

**Fix:** Specify exact allowed origins. Never combine wildcard with `Access-Control-Allow-Credentials`.

---

### WEB-SEC-020: Secrets in localStorage/sessionStorage

**Severity:** error | **CWE-922**

Detects authentication tokens and secrets stored in browser storage, which is accessible to any JavaScript (including XSS payloads).

**Patterns detected:**
- Storing auth token/secret in localStorage — accessible to XSS. Use httpOnly cookies instead
- Storing auth token/secret in sessionStorage — accessible to XSS. Use httpOnly cookies
- Auth data in localStorage — XSS can steal it. Use httpOnly secure cookies

**Fix:** Store auth tokens in httpOnly secure cookies, not in browser storage.

---

### WEB-SEC-021: Source Map Exposure in Production

**Severity:** warning | **CWE-615**

Detects source maps enabled in production builds, which expose original source code to anyone with browser DevTools.

**Patterns detected:**
- Source map reference found — exposes original source code in production. Remove for prod builds
- Webpack devtool set to generate source maps — disable for production builds
- Source maps enabled — original source code visible in browser DevTools in production
- Production source maps explicitly enabled — exposes source code to attackers

**Fix:** Set `sourceMap: false` or `devtool: false` in production builds. Remove `.map` files from deployment.

---

### WEB-SEC-022: JavaScript URI Scheme

**Severity:** error | **CWE-79**

Detects `javascript:` URIs in HTML attributes and JavaScript, which execute arbitrary code and bypass many sanitization approaches.

**Patterns detected:**
- javascript: URI in href — XSS vector. Use onclick handler or button element instead
- javascript: URI in src — code execution risk
- javascript: URI in location assignment — XSS risk
- Dynamic javascript: URI assignment — XSS risk. Validate URL scheme against allowlist

**Fix:** Never use `javascript:` URIs. Use event handlers or button elements for actions. CSP can block these.

---

### WEB-SEC-023: Insecure iframe Sandbox

**Severity:** warning | **CWE-1021**

Detects iframe sandbox configurations that effectively bypass sandboxing or allow dangerous capabilities like top-level navigation.

**Patterns detected:**
- iframe sandbox with allow-scripts + allow-same-origin — sandbox is effectively bypassed
- iframe sandbox with allow-top-navigation — embedded page can redirect parent (clickjacking variant)
- `<iframe>` loading external content — ensure sandbox attribute is set

**Fix:** Use `sandbox=''` (most restrictive) and add only needed permissions. Never combine `allow-scripts` with `allow-same-origin`.

---

### WEB-SEC-024: CSS Injection / Exfiltration

**Severity:** warning | **CWE-79**

Detects user input injected into CSS styles, which can be used to exfiltrate data via CSS selectors or deface the UI.

**Patterns detected:**
- User input in inline style assignment — CSS injection risk. Use CSS classes instead
- Template literal in `<style>` tag — CSS injection / exfiltration risk
- User input in cssText — CSS injection risk. Validate against allowlist of CSS properties

**Fix:** Never inject user input into CSS. Use CSS custom properties (variables) or className toggling.

---

### WEB-SEC-025: Missing CSRF Protection

**Severity:** error | **CWE-352**

Detects disabled or exempted CSRF protection on state-changing endpoints, allowing cross-site request forgery attacks.

**Patterns detected:**
- Django @csrf_exempt — endpoint unprotected against CSRF attacks
- Laravel CSRF exceptions — listed routes have no CSRF protection
- Rails CSRF verification skipped — controller actions vulnerable to CSRF
- CSRF protection ignoring POST/PUT/DELETE methods — these need CSRF tokens

**Fix:** Enable CSRF protection on all state-changing endpoints. Use `SameSite=Strict` cookies.

---

## Backend Attacks (rules/backend/)

### BE-SEC-010: NoSQL Injection

**Severity:** error | **CWE-943**

Detects user input passed directly into MongoDB queries or operators, allowing attackers to manipulate query logic and bypass authentication.

**Patterns detected:**
- MongoDB $where operator executes JavaScript — injection risk with user input
- MongoDB operator with user input — NoSQL injection risk. Sanitize input or use explicit field queries
- MongoDB find() with $ operator — ensure user input cannot inject NoSQL operators
- MongoDB eval enabled — server-side JavaScript execution risk
- Direct user input in MongoDB find() — sanitize to prevent NoSQL injection

**Fix:** Validate and sanitize input. Use mongoose schemas with strict mode. Strip `$` operators from user input.

---

### BE-SEC-011: LDAP Injection

**Severity:** error | **CWE-90**

Detects user input concatenated into LDAP search filters or bind DNs, allowing attackers to modify query logic and access unauthorized directory entries.

**Patterns detected:**
- String concat in LDAP search filter — LDAP injection risk. Use parameterized LDAP queries
- User input in LDAP filter — injection risk. Escape special characters (*, (, ), \\, NUL)
- User input in LDAP bind DN — injection risk. Validate against allowlist
- f-string in LDAP filter — injection risk. Use ldap.filter.escape_filter_chars()

**Fix:** Escape LDAP special characters. Use parameterized filters. Validate input against strict patterns.

---

### BE-SEC-012: Server-Side Template Injection (SSTI)

**Severity:** error | **CWE-1336**

Detects user input passed to template engines, which can lead to remote code execution when attackers inject template expressions.

**Patterns detected:**
- Flask render_template_string with user input — SSTI leads to RCE. Use render_template with file
- User input in template constructor — SSTI risk. Use pre-compiled template files
- Jinja2 from_string() — SSTI risk if template content includes user input
- Template engine eval with user input — SSTI risk
- Rails render inline with user input — SSTI risk. Use template files
- FreeMarker template from user input — SSTI leads to RCE in Java

**Fix:** Never pass user input to template engines. Use pre-compiled template files. Sandbox template engines.

---

### BE-SEC-013: Log Injection / Log Forging

**Severity:** warning | **CWE-117**

Detects user input written directly to log statements, allowing attackers to forge log entries or inject ANSI escape sequences.

**Patterns detected:**
- User input in log statement — log injection risk. Attacker can forge log entries or inject ANSI/CRLF
- User input in console output — log injection/information exposure
- String concat with user input in log — sanitize to prevent log forging (remove \n, \r)

**Fix:** Sanitize log input: strip newlines, encode special chars. Use structured logging (JSON).

---

### BE-SEC-014: CRLF Injection / HTTP Response Splitting

**Severity:** error | **CWE-113**

Detects user input in HTTP response headers, allowing attackers to inject `\r\n` sequences to add arbitrary headers or split responses.

**Patterns detected:**
- User input in HTTP header — CRLF injection risk. Validate and strip \r\n from header values
- User input in response header value — CRLF injection can add arbitrary headers
- User input in redirect — open redirect + potential CRLF injection

**Fix:** Strip `\r\n` from all header values. Validate redirect URLs against allowlist.

---

### BE-SEC-015: Server-Side Request Forgery (SSRF)

**Severity:** error | **CWE-918**

Detects user input used as URLs in server-side HTTP requests, allowing attackers to access internal services, cloud metadata endpoints, or local files.

**Patterns detected:**
- User input in HTTP request URL — SSRF risk. Validate URL against allowlist of domains/IPs
- Request parameter directly used as URL — SSRF can access internal services
- User input in URL constructor — validate protocol (https only) and domain against allowlist
- User input in XMLHttpRequest URL — SSRF risk
- PHP file_get_contents with user URL — SSRF/LFI risk. Validate against allowlist

**Fix:** Validate URLs: allowlist domains, block internal IPs (127.0.0.1, 10.x, 169.254.x, ::1). Use URL parser.

---

### BE-SEC-020: JWT Security Weaknesses

**Severity:** error | **CWE-347**

Detects insecure JWT configurations including disabled signature verification, weak secrets, and the `none` algorithm bypass.

**Patterns detected:**
- JWT 'none' algorithm — signature verification bypassed entirely. Always enforce RS256 or HS256
- JWT signature verification disabled — tokens can be forged. Always verify signatures
- PyJWT decode without verification — token can be tampered. Use jwt.decode(token, key, algorithms=[...])
- JWT signed with short secret (<8 chars) — brute-forceable. Use 256+ bit secret or RS256
- JWT with long expiration (days+) — use short-lived tokens with refresh token rotation
- Weak HS256 secret — use at least 256-bit (32+ char) random secret

**Fix:** Use RS256 with key pairs, or HS256 with 256-bit random secret. Always verify. Set short expiration.

---

### BE-SEC-021: Insecure Session/Cookie Configuration

**Severity:** warning | **CWE-614**

Detects cookies and sessions configured without security flags, making them vulnerable to theft via XSS or interception over HTTP.

**Patterns detected:**
- Cookie HttpOnly disabled — JavaScript can access cookie (XSS token theft). Set httpOnly: true
- Cookie Secure flag disabled — cookie sent over HTTP (interceptable). Set secure: true
- Cookie SameSite=None — cookie sent on cross-site requests (CSRF risk). Use Strict or Lax
- Django session cookie without Secure flag — sent over plain HTTP
- PHP session cookie without Secure flag

**Fix:** Set `httpOnly: true`, `secure: true`, `sameSite: 'Strict'`. Use short session timeouts.

---

### BE-SEC-022: Mass Assignment

**Severity:** error | **CWE-915**

Detects request body or parameters passed directly to ORM create/update methods, allowing attackers to set fields like `role` or `isAdmin` that should not be user-controlled.

**Patterns detected:**
- Direct req.body in ORM create() — mass assignment. Attacker can set role, isAdmin, etc.
- Direct req.body in ORM update() — mass assignment risk. Whitelist allowed fields
- Direct request data in create() — mass assignment. Use serializer/form with explicit fields
- Object.assign with req.body — mass assignment. Destructure only allowed fields
- Rails params.permit! allows ALL parameters — mass assignment. Use params.permit(:field1, :field2)
- Laravel $guarded = [] — all fields are mass assignable. Use $fillable with explicit fields
- Laravel fill() with request.all() — mass assignment. Use only() to limit fields

**Fix:** Whitelist fields: use DTOs, serializers, `params.permit()`, `$fillable`. Never pass raw request body to ORM.

---

### BE-SEC-023: GraphQL Security Issues

**Severity:** warning | **CWE-200**

Detects GraphQL misconfigurations that expose the full schema, allow deeply nested DoS queries, or leave interactive playgrounds accessible in production.

**Patterns detected:**
- GraphQL introspection enabled — exposes full schema to attackers. Disable in production
- GraphQL depth limit too high or disabled — enables deeply nested DoS queries
- GraphiQL/playground enabled — interactive query tool exposed in production
- GraphQL query complexity limit disabled — enables expensive queries (DoS)
- GraphQL IDE exposed in production — disable playground/explorer endpoints

**Fix:** Disable introspection + playground in production. Set depth limit (7–10), complexity limit, and rate limiting.

---

### BE-SEC-024: Open Redirect

**Severity:** warning | **CWE-601**

Detects user input used in redirect URLs, allowing attackers to redirect users to phishing or malware sites from a trusted domain.

**Patterns detected:**
- User input in redirect — open redirect risk. Validate URL against allowlist of internal paths
- User input in Location header — open redirect / phishing risk
- Rails redirect_to with user input — open redirect. Validate against allowlist
- Django redirect with user input — open redirect. Use url_has_allowed_host_and_scheme()
- Client-side redirect with user input — open redirect / XSS risk

**Fix:** Validate redirect URLs: allow only relative paths or an explicit allowlist of domains.

---

### BE-SEC-025: Directory Listing / Information Disclosure

**Severity:** warning | **CWE-548**

Detects enabled directory listing on web servers, which exposes internal file structure and potentially sensitive files to attackers.

**Patterns detected:**
- Directory listing enabled — exposes file structure to attackers. Disable in production
- express.static with index: false — may expose directory listing if no default file exists
- Django SHOW_INDEXES enabled — directory listing exposed
- Apache Options +Indexes — directory listing enabled. Use Options -Indexes
- sendFile with path traversal pattern — information disclosure risk

**Fix:** Disable directory listing. Add index files. Configure web server to return 403 for directory requests.

---

### BE-SEC-030: SMTP Injection / Email Header Injection

**Severity:** error | **CWE-93**

Detects user input in email functions and headers, allowing attackers to inject CRLF sequences to add Bcc recipients or relay spam.

**Patterns detected:**
- User input in email function — SMTP header injection risk (Bcc: injection, spam relay)
- User input in email Subject — SMTP injection via CRLF (\r\n) to add headers
- User input in email header — SMTP injection can redirect or Bcc emails to attacker

**Fix:** Validate email addresses strictly (RFC 5321). Strip `\r\n` from all header values. Use email library APIs.

---

### BE-SEC-031: XML Bomb / Billion Laughs

**Severity:** error | **CWE-776**

Detects XML entity definitions and DTD processing that can cause exponential memory consumption (billion laughs) or external entity injection (XXE).

**Patterns detected:**
- XML entity definition — potential billion laughs DoS or XXE. Disable DTD processing entirely
- Inline DTD detected — billion laughs / XML bomb risk. Disable DTD parsing
- External entity reference (SYSTEM) — XXE risk. Disable external entity loading
- XML entity resolution enabled — billion laughs / XXE risk. Set resolve_entities=False

**Fix:** Disable DTD processing entirely. Set parser limits on entity expansion. Use JSON instead of XML where possible.

---

### BE-SEC-032: Race Condition (TOCTOU)

**Severity:** warning | **CWE-367**

Detects time-of-check-to-time-of-use patterns where a resource is checked and then acted upon non-atomically, allowing concurrent modification between the two steps.

**Patterns detected:**
- TOCTOU: checking file existence then opening — file could change between check and use
- TOCTOU: check-then-act on file — race condition. Use atomic operations or file locks
- TOCTOU: fs.existsSync then fs.operation — race condition. Use fs.open with flags
- Check-then-update on balance/stock — race condition. Use database transactions or atomic ops

**Fix:** Use atomic operations, file locks (flock), or database transactions. Avoid check-then-act patterns.

---

### BE-SEC-033: Insecure Random Number Generation

**Severity:** error | **CWE-330**

Detects non-cryptographic random number generators used for security-sensitive values like tokens, secrets, and session IDs.

**Patterns detected:**
- Math.random() for security-sensitive value — predictable. Use crypto.randomUUID() or crypto.getRandomValues()
- Python random.random() is not cryptographically secure. Use secrets.token_hex() or secrets.token_urlsafe()
- java.util.Random is not cryptographically secure. Use java.security.SecureRandom
- rand()/random() for security value — predictable. Use cryptographic random source
- srand(time()) — predictable seed. Use /dev/urandom or OS random source

**Fix:** Use cryptographic random: `crypto.getRandomValues` (JS), `secrets` module (Python), `SecureRandom` (Java).

---

### BE-SEC-034: ReDoS (Regular Expression Denial of Service)

**Severity:** warning | **CWE-1333**

Detects regex patterns with catastrophic backtracking potential and user input compiled as regular expressions.

**Patterns detected:**
- Nested quantifier pattern (.+)+ — catastrophic backtracking (ReDoS). Simplify or use RE2/atomic groups
- Alternation with repetition — exponential backtracking risk
- User input in RegExp constructor — ReDoS risk. Validate or use RE2 library
- User input in regex compilation — ReDoS risk. Use re2 library or validate pattern

**Fix:** Use RE2 (linear-time regex). Avoid nested quantifiers. Never compile user input as regex. Set regex timeout.
