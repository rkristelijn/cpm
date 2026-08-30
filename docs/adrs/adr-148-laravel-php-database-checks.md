---
summary: Laravel/PHP security & anti-pattern checks, database version/security checks, stack CVE awareness.
status: accepted
---

# ADR-148: Laravel, PHP & Database Checks

## Context

cpm already has Django checks (untracked, not yet merged). The PHP/Laravel ecosystem is the largest web stack by market share (74% of server-side web). We need equivalent coverage for:

1. Laravel best practices & anti-patterns (version-aware)
2. PHP runtime EOL detection
3. Apache/Nginx + PHP stack CVE awareness
4. Database version EOL & security misconfiguration (MySQL, PostgreSQL, MariaDB)

## Decision

Add check scripts following the same pattern as `checks/python/django/`.

## Architecture

```text
checks/
├── php/
│   ├── laravel/
│   │   ├── check-laravel.sh            # anti-patterns + code quality
│   │   └── check-laravel-security.sh   # OWASP-aligned security
│   ├── check-php-eol.sh               # PHP version EOL from composer.json/Dockerfile
│   └── check-php-security.sh          # PHP config anti-patterns
├── universal/
│   ├── check-db-version.sh            # MySQL/PG/MariaDB EOL detection
│   └── check-db-security.sh           # misconfig detection
```

## Laravel Version Matrix (last 5 years)

| Version | Release | Security Until | PHP Required | Status (Jun 2026) |
|---------|---------|----------------|--------------|-------------------|
| 13 | Mar 2026 | Mar 2028 | 8.3+ | ✅ Active |
| 12 | Feb 2025 | Feb 2027 | 8.2+ | ✅ Active |
| 11 | Mar 2024 | Mar 2026 | 8.2+ | ⚠️ EOL |
| 10 | Feb 2023 | Feb 2025 | 8.1+ | ❌ EOL |
| 9 | Feb 2022 | Feb 2024 | 8.0+ | ❌ EOL |
| 8 | Sep 2020 | Jan 2023 | 7.3+ | ❌ EOL |
| 7 | Mar 2020 | Mar 2021 | 7.2+ | ❌ EOL |

## PHP Version Matrix

| Version | Release | Security Until | Status (Jun 2026) |
|---------|---------|----------------|-------------------|
| 8.5 | Nov 2025 | Dec 2029 | ✅ Active |
| 8.4 | Nov 2024 | Dec 2028 | ✅ Active |
| 8.3 | Nov 2023 | Dec 2027 | ⚠️ Security only |
| 8.2 | Dec 2022 | Dec 2026 | ⚠️ Security only (expires soon) |
| 8.1 | Nov 2021 | Dec 2025 | ❌ EOL |
| 8.0 | Nov 2020 | Nov 2023 | ❌ EOL |
| 7.4 | Nov 2019 | Nov 2022 | ❌ EOL |

## Critical CVEs — PHP & Apache Stack

### PHP

| CVE | CVSS | Description |
|-----|------|-------------|
| CVE-2024-4577 | 9.8 | PHP-CGI argument injection → RCE (Windows, all PHP 5.x+) |
| CVE-2024-1874 | 9.4 | Command injection in `proc_open()` (Windows) |
| CVE-2024-2756 | 6.5 | Cookie verification bypass |
| CVE-2024-3096 | — | `password_verify` bypass |
| CVE-2024-2757 | 7.5 | Integer overflow → infinite loop (DoS) |

### Apache HTTP Server

| CVE | CVSS | Description |
|-----|------|-------------|
| CVE-2024-40725 | 7.5 | HTTP request smuggling |
| CVE-2024-40898 | 7.5 | SSL client auth bypass |
| CVE-2025-23048 | 7.4 | TLS 1.3 session resumption auth bypass |
| CVE-2026-23918 | 9.1 | Double-free in HTTP/2 → RCE |

## Laravel Checks Design

### check-laravel.sh (anti-patterns)

| # | Check | Severity | Detection |
|---|-------|----------|-----------|
| 1 | N+1 queries | warning | Relations accessed in loops without `with()` / `load()` |
| 2 | Fat controllers | warning | Controller files > 200 lines |
| 3 | Mass assignment | error | `$guarded = []` or `Request::all()` passed to `create()`/`update()` |
| 4 | No validation | warning | `$request->input()` / `$request->all()` without FormRequest or `validate()` |
| 5 | Business in events | warning | DB queries / HTTP calls in event listeners |
| 6 | Raw SQL injection | error | `DB::raw()` / `DB::select()` with variable interpolation |
| 7 | Fat models | warning | Model files > 300 lines |
| 8 | No service layer | info | All logic in controllers (heuristic: no `app/Services/` or `app/Actions/`) |
| 9 | Deprecated patterns | warning | Version-specific: `$dates`, `$casts` as method (L11+), old route syntax |
| 10 | No eager loading | warning | `->get()` inside loops on relationships |

### check-laravel-security.sh (OWASP-aligned)

| # | Check | Severity | Detection |
|---|-------|----------|-----------|
| 1 | APP_DEBUG=true | error | Hardcoded in .env (not from env var) |
| 2 | Hardcoded APP_KEY | error | APP_KEY visible in committed files |
| 3 | .env in git | error | `.env` tracked by git |
| 4 | CORS wildcard | error | `CORS_ALLOW_ALL_ORIGINS=true` in config |
| 5 | XSS via Blade | warning | `{!! !!}` with user input (heuristic) |
| 6 | No CSRF | warning | Forms without `@csrf`, routes excluded from CSRF |
| 7 | Missing security headers | warning | No HSTS, CSP, X-Frame-Options config |
| 8 | No rate limiting | warning | No throttle middleware on auth routes |
| 9 | Unsafe file uploads | warning | `getClientOriginalName()` used for storage |
| 10 | No auth middleware | warning | Routes accessing models without `auth`/`can` middleware |
| 11 | Laravel version EOL | error | `laravel/framework` version in composer.lock ≤ 10 |
| 12 | Exposed storage | warning | `storage/` symlinked without access control |
| 13 | Insecure session | warning | `SESSION_DRIVER=file` + `SESSION_SECURE_COOKIE=false` |
| 14 | Unsafe deserialization | error | `unserialize()` on user input |
| 15 | Command injection | error | `exec()`/`shell_exec()`/`system()` with `$request` data |

## PHP EOL Check Design

### check-php-eol.sh

Detection sources (in priority order):

1. `composer.json` → `"require": { "php": ">=8.x" }`
2. `Dockerfile` → `FROM php:8.x`
3. `.php-version` file
4. `docker-compose.yml` → image tags

Logic:

- PHP ≤ 8.1 → error (EOL, no security patches)
- PHP 8.2 → warning (security-only, expires Dec 2026)
- PHP 8.3 → info (security-only)
- PHP 8.4+ → pass

## Database Checks Design

### Database Version Matrix

#### MySQL

| Version | EOL | Status |
|---------|-----|--------|
| 5.7 | Oct 2023 | ❌ EOL |
| 8.0 | Apr 2026 | ⚠️ EOL imminent |
| 8.4 LTS | Apr 2032 | ✅ Active |
| 9.x | Short-lived innovation | ⚠️ Not LTS |

#### PostgreSQL

| Version | EOL | Status |
|---------|-----|--------|
| 12 | Nov 2024 | ❌ EOL |
| 13 | Nov 2025 | ❌ EOL |
| 14 | Nov 2026 | ⚠️ Approaching EOL |
| 15 | Nov 2027 | ✅ |
| 16 | Nov 2028 | ✅ |
| 17 | Nov 2029 | ✅ |

#### MariaDB

| Version | EOL | Status |
|---------|-----|--------|
| 10.5 | Jun 2025 | ❌ EOL |
| 10.6 LTS | Jul 2026 | ⚠️ Approaching EOL |
| 10.11 LTS | Feb 2028 | ✅ |
| 11.4 LTS | ~2029 | ✅ |

### check-db-version.sh

Detection sources:

1. `docker-compose.yml` → `image: mysql:5.7` / `postgres:12`
2. `Dockerfile` → `FROM mysql:` / `FROM postgres:`
3. `.env` → `DB_VERSION=`

### check-db-security.sh

| # | Check | Severity | Detection |
|---|-------|----------|-----------|
| 1 | Default port exposed | warning | `ports: "3306:3306"` / `"5432:5432"` in docker-compose |
| 2 | Empty/default password | error | `MYSQL_ALLOW_EMPTY_PASSWORD`, `POSTGRES_PASSWORD=postgres` |
| 3 | Root user in app config | warning | `DB_USERNAME=root` in .env |
| 4 | No SSL/TLS | warning | No `sslmode=require` (PG) or `MYSQL_SSL=true` |
| 5 | Public bind address | error | `bind-address=0.0.0.0` in config |
| 6 | Wildcard grants in migrations | error | `GRANT ALL ON *.*` patterns in SQL files |
| 7 | No connection pooling | info | No PgBouncer/ProxySQL reference |
| 8 | Hardcoded connection string | error | Full DB URL with password in source code |

## Top 5 PHP & Python Frameworks (Market Context)

### PHP

| # | Framework | Stack | Default DB |
|---|-----------|-------|-----------|
| 1 | Laravel | PHP + Nginx/Apache + Redis | MySQL, PostgreSQL |
| 2 | Symfony | PHP + Nginx + Doctrine | PostgreSQL, MySQL |
| 3 | WordPress | PHP + Apache | MySQL, MariaDB |
| 4 | CakePHP | PHP + Apache | MySQL |
| 5 | CodeIgniter | PHP + Apache | MySQL |

### Python

| # | Framework | Stack | Default DB |
|---|-----------|-------|-----------|
| 1 | Django | Python + Gunicorn/Nginx | PostgreSQL, SQLite |
| 2 | FastAPI | Python + Uvicorn | PostgreSQL |
| 3 | Flask | Python + Gunicorn | SQLite, PostgreSQL |
| 4 | Tornado | Python (async) | — |
| 5 | Pyramid | Python + Waitress | PostgreSQL |

## Gating Logic

All checks gate on framework detection:

```bash
# Laravel: composer.json contains "laravel/framework"
grep -q "laravel/framework" "$REPO/composer.json" 2>/dev/null || exit 0

# PHP: any composer.json exists
[ -f "$REPO/composer.json" ] || exit 0

# Database: docker-compose.yml or .env with DB config
[ -f "$REPO/docker-compose.yml" ] || [ -f "$REPO/.env" ] || exit 0
```

## Naming Convention (per CONVENTIONS.md)

| Script | Standardized Name |
|--------|-------------------|
| check-laravel.sh | `code-php-quality-lint` |
| check-laravel-security.sh | `code-php-vulnerability-scan` |
| check-php-eol.sh | `libs-php-version-detect` |
| check-db-version.sh | `libs-generic-version-detect` |
| check-db-security.sh | `configuration-generic-vulnerability-scan` |

## Implementation Priority

| Check | Priority | Effort | Rationale |
|-------|----------|--------|-----------|
| check-laravel-security.sh | High | Medium | Directly maps to OWASP, high impact |
| check-laravel.sh | High | Medium | Most common anti-patterns, easy grep-based |
| check-php-eol.sh | High | Low | Parse composer.json/Dockerfile |
| check-db-version.sh | High | Low | Parse docker-compose.yml |
| check-db-security.sh | Medium | Low | Pattern matching in config files |

## PHP Application Ecosystem (Self-Hosted Software)

PHP dominates self-hosted web software. These are not frameworks — they're deployable applications cpm should detect and check.

### Architecture

```text
checks/
├── php/
│   ├── laravel/
│   │   ├── check-laravel.sh
│   │   └── check-laravel-security.sh
│   ├── wordpress/
│   │   └── check-wordpress.sh          # hardening + version EOL
│   ├── drupal/
│   │   └── check-drupal.sh             # version EOL + misconfig
│   ├── joomla/
│   │   └── check-joomla.sh             # version EOL + misconfig
│   ├── ecommerce/
│   │   └── check-php-ecommerce.sh      # Magento/WooCommerce/PrestaShop/Shopware/OpenCart
│   ├── community/
│   │   └── check-php-community.sh      # phpBB/Flarum/MyBB/vBulletin
│   ├── collaboration/
│   │   └── check-php-collab.sh         # Nextcloud/MediaWiki/MantisBT/osTicket/SuiteCRM
│   ├── check-php-eol.sh
│   └── check-php-security.sh
```

### Categorieën & Versie-Matrix

#### CMS — Content Management Systemen

| Systeem | Huidige versie | EOL versies | Detectie |
|---------|---------------|-------------|----------|
| **WordPress** | 6.9+ | ≤ 6.4 (geen security) | `wp-includes/version.php`, `composer.json` |
| **Drupal** | 11.x | 7 (EOL Jan 2025), 9 (EOL Nov 2023), 10.3 (EOL Jun 2025) | `core/lib/Drupal.php`, `composer.json` |
| **Joomla!** | 5.x/6.x | 3 (EOL Aug 2023), 4 (EOL Oct 2025) | `libraries/src/Version.php`, `administrator/manifests/files/joomla.xml` |
| **TYPO3** | 13.x | 10 (EOL Apr 2023), 11 (EOL Oct 2024), 12 (Apr 2026) | `typo3/sysext/core/Classes/Information/Typo3Version.php` |
| **Craft CMS** | 5.x | 3 (EOL), 4 (limited) | `composer.json` → `craftcms/cms` |
| **Statamic** | 5.x | 3 (EOL) | `composer.json` → `statamic/cms` |

#### E-commerce

| Systeem | Huidige versie | EOL versies | Detectie |
|---------|---------------|-------------|----------|
| **WooCommerce** | 9.x | ≤ 7.x (no security patches) | `wp-content/plugins/woocommerce/woocommerce.php` |
| **Magento/Adobe Commerce** | 2.4.7+ | 2.4.4 (EOL Nov 2024), 2.4.5 (EOL Aug 2025) | `composer.json` → `magento/product-community-edition` |
| **PrestaShop** | 8.x/9.x | ≤ 1.7 (EOL), 8.0 (limited) | `config/settings.inc.php`, `composer.json` |
| **OpenCart** | 4.x | ≤ 3.x (SQL injection CVE-2024-21514) | `config.php`, `index.php` version |
| **Shopware** | 6.6+ | 5 (EOL), 6.4 (EOL) | `composer.json` → `shopware/core` |

#### Forums & Community

| Systeem | Huidige versie | EOL versies | Detectie |
|---------|---------------|-------------|----------|
| **phpBB** | 3.3.x | ≤ 3.2 (EOL Nov 2023) | `includes/constants.php` → `PHPBB_VERSION` |
| **Flarum** | 2.x | 1.x (EOL) | `composer.json` → `flarum/core` |
| **MyBB** | 1.8.x | ≤ 1.6 (EOL) | `inc/class_core.php` |
| **vBulletin** | 6.x | ≤ 4.x (EOL, many CVEs) | `includes/class_core.php` |

#### Collaboration & Project Management

| Systeem | Huidige versie | EOL/Supported | Detectie |
|---------|---------------|---------------|----------|
| **Nextcloud** | 32.x/33.x | ≤ 28 (EOL), 29 (EOL), 30+ active | `version.php`, `config/config.php` |
| **MediaWiki** | 1.42/1.43 | ≤ 1.39 (EOL Jun 2025) | `includes/Defines.php` → `MW_VERSION` |
| **MantisBT** | 2.27+ | ≤ 2.25 (EOL) | `core/constant_inc.php` |
| **osTicket** | 1.18+ | ≤ 1.15 (EOL) | `include/class.osticket.php` |
| **SuiteCRM** | 8.x | 7.x (limited, many CVEs in 2024) | `suitecrm_version.php`, `composer.json` |

### CVEs per Systeem (2022–2026, Hoog Impact)

#### WordPress Ecosystem

| CVE/Issue | CVSS | Beschrijving |
|-----------|------|-------------|
| 7,966 plugin vulns (2024) | — | 34% stijging YoY, 35% ongepatcht |
| Plugin supply chain | — | Contributor-level access = 34% van alle vulns |
| Core XSS (6.9.x) | 6.1 | Notes feature unauthorized access |

**Risico**: WordPress core is relatief veilig; het probleem zit in plugins/themes (95%+ van alle WP vulns).

#### Magento / Adobe Commerce

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-34102 (CosmicSting) | **9.8** | XXE → RCE, 4,275 stores gecompromitteerd |
| CVE-2022-24086 | **9.8** | Template injection → RCE |
| CVE-2024-34103–34108 | 7.5–8.8 | Auth bypass, privilege escalation |

#### PrestaShop

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2022-36408 | **9.8** | RCE via SQL injection in shop |
| CVE-2024-34716 | 8.8 | XSS → admin takeover |

#### Shopware

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-22408 | 7.5 | SSRF via Flow Builder webhook |
| CVE-2024-22407 | 6.5 | Authorization bypass in order state |
| CVE-2024-42354 | 5.3 | Data exposure via API |

#### OpenCart

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-21514 | **9.8** | SQL injection in Divido payment extension (default in v3) |
| CVE-2024-21518 | 8.8 | Arbitrary file creation in web root |

#### TYPO3

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-22188 | **9.8** | Command injection via Install Tool (admin auth required) |
| CVE-2024-25119 | 7.5 | Information disclosure |

#### Nextcloud

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-52523 | 6.5 | Arbitrary file preview access |
| CVE-2024-52519 | 5.9 | OAuth2 secrets recoverable from backup |
| CVE-2024-52525 | 5.3 | Cleartext password in PHP process memory |
| CVE-2026-45722 | 6.8 | SQL injection in Tables app |

#### SuiteCRM

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-36412 | **9.8** | SQL injection (unauthenticated) |
| CVE-2024-36415 | **9.8** | RCE via file upload |
| CVE-2024-49774 | 8.8 | MLP blacklist bypass → code execution |
| CVE-2024-50333 | 7.5 | Arbitrary file write |

#### osTicket

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2026-22200 | **9.8** | Filter chain injection (unauthenticated RCE) |
| CVE-2026-26895 | 5.3 | User enumeration |

#### MantisBT

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-45792 | 4.3 | Information disclosure (user profiles) |

### Hardening & Misconfiguration Checks

#### WordPress (check-wordpress.sh)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | WP_DEBUG=true in production | error | `wp-config.php` |
| 2 | Default `wp_` table prefix | warning | `wp-config.php` → `$table_prefix` |
| 3 | File editing enabled | warning | Missing `DISALLOW_FILE_EDIT` |
| 4 | XML-RPC enabled | warning | No `xmlrpc.php` block / no disable plugin |
| 5 | Exposed wp-config.php | error | Accessible in web root |
| 6 | Default admin username | warning | user `admin` in DB exports/seed |
| 7 | No security keys/salts | error | Empty/default AUTH_KEY etc |
| 8 | Auto-updates disabled | warning | `AUTOMATIC_UPDATER_DISABLED=true` |
| 9 | Directory listing enabled | warning | No `.htaccess` deny or nginx config |
| 10 | Outdated WordPress core | error | Version ≤ 6.4 |
| 11 | wp-content/uploads executable | error | PHP execution in uploads dir |
| 12 | No forced SSL | warning | Missing `FORCE_SSL_ADMIN` |

#### Drupal (check-drupal.sh)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Outdated Drupal core | error | Version ≤ 10.3 (EOL Jun 2025) |
| 2 | settings.php permissions | error | World-readable settings.php |
| 3 | Trusted host patterns missing | warning | `$settings['trusted_host_patterns']` empty |
| 4 | Update module disabled | warning | Core update status module off |
| 5 | Private file path not set | warning | No `$settings['file_private_path']` |

#### Joomla (check-joomla.sh)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Outdated Joomla core | error | Version ≤ 4 (EOL Oct 2025) |
| 2 | Default admin path | warning | `/administrator/` not renamed/protected |
| 3 | FTP layer enabled | warning | `$ftp_enable = 1` in configuration.php |
| 4 | Error reporting on | warning | `$error_reporting = 'maximum'` |
| 5 | No 2FA enforced | info | No 2FA plugin active |

#### E-commerce (check-php-ecommerce.sh)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Magento version EOL | error | ≤ 2.4.5 |
| 2 | Magento admin URL default | warning | `/admin` not customized |
| 3 | PrestaShop install dir present | error | `/install/` directory exists |
| 4 | OpenCart 3.x (SQL injection risk) | error | Version detection |
| 5 | Shopware 5.x EOL | error | Version in composer.json |
| 6 | Payment module outdated | warning | Known vulnerable payment extensions |
| 7 | No CSP headers | warning | Missing in response config |

#### Community/Forums (check-php-community.sh)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | phpBB ≤ 3.2 EOL | error | Version in constants |
| 2 | Install directory present | error | `/install/` not removed |
| 3 | Config file permissions | warning | World-readable config.php |
| 4 | Default admin username | warning | `admin` user |
| 5 | Registration CAPTCHA missing | warning | No CAPTCHA in config |

#### Collaboration (check-php-collab.sh)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Nextcloud ≤ 28 EOL | error | version.php |
| 2 | MediaWiki ≤ 1.39 EOL | error | MW_VERSION constant |
| 3 | MantisBT install dir present | error | `/admin/install.php` exists |
| 4 | SuiteCRM ≤ 7.x (many critical CVEs) | error | Version file |
| 5 | osTicket ≤ 1.15 (critical RCE) | error | Version detection |
| 6 | Nextcloud no HTTPS redirect | warning | `overwrite.cli.url` = http:// |
| 7 | Nextcloud default password policy | warning | No password policy app |

### Detection Gating

```bash
# WordPress
[ -f "$REPO/wp-includes/version.php" ] || [ -f "$REPO/wp-config.php" ] || exit 0

# Drupal
[ -f "$REPO/core/lib/Drupal.php" ] || [ -d "$REPO/sites/default" ] || exit 0

# Joomla
[ -f "$REPO/libraries/src/Version.php" ] || [ -f "$REPO/configuration.php" ] || exit 0

# Magento
grep -q "magento" "$REPO/composer.json" 2>/dev/null || exit 0

# Nextcloud
[ -f "$REPO/version.php" ] && grep -q "OC_Version" "$REPO/version.php" 2>/dev/null || exit 0

# Generic PHP app: any of the above markers
```

### Naming Convention (per CONVENTIONS.md)

| Script | Standardized Name |
|--------|-------------------|
| check-wordpress.sh | `code-php-vulnerability-scan` |
| check-drupal.sh | `code-php-vulnerability-scan` |
| check-joomla.sh | `code-php-vulnerability-scan` |
| check-php-ecommerce.sh | `code-php-vulnerability-scan` |
| check-php-community.sh | `code-php-vulnerability-scan` |
| check-php-collab.sh | `code-php-vulnerability-scan` |

Note: bij scan-modus worden deze automatisch per gedetecteerde app ingeladen.

### Implementation Priority

| Check | Priority | Effort | Impact |
|-------|----------|--------|--------|
| check-wordpress.sh | **Critical** | Medium | WordPress = 43% van alle websites |
| check-php-ecommerce.sh | **High** | Medium | Financiële impact bij breach |
| check-drupal.sh | High | Low | Enterprise / overheid |
| check-php-collab.sh | High | Low | Nextcloud/SuiteCRM vele kritieke CVEs |
| check-joomla.sh | Medium | Low | Dalende markt maar nog steeds relevant |
| check-php-community.sh | Medium | Low | Minder kritiek, kleiner aanvalsoppervlak |

## Python Application Ecosystem (Self-Hosted Software)

Where PHP dominates with ready-to-install systems, Python works modularly: powerful frameworks as foundation, with specialized applications on top. Python excels in data/AI dashboards, DevOps tooling, and enterprise ERP — areas where PHP has no equivalent.

### Architecture

```text
checks/
├── python/
│   ├── django/
│   │   ├── check-django.sh              # (exists, anti-patterns)
│   │   └── check-django-security.sh     # (exists, OWASP-aligned)
│   ├── fastapi/
│   │   └── check-fastapi.sh             # API security + misconfig
│   ├── cms/
│   │   └── check-python-cms.sh          # Wagtail/DjangoCMS/Plone
│   ├── ecommerce/
│   │   └── check-python-ecommerce.sh    # Saleor/Oscar
│   ├── data/
│   │   └── check-python-data.sh         # Streamlit/Dash security
│   ├── devops/
│   │   └── check-python-devops.sh       # NetBox/Sentry/Odoo
│   └── check-python-eol.sh             # Python runtime EOL
```

### Django Version Matrix (Framework Foundation)

| Version | Release | Active Support | Security Until | Python | Status (Jun 2026) |
|---------|---------|----------------|----------------|--------|-------------------|
| **6.0** | Dec 2025 | Aug 2026 | Apr 2027 | 3.12–3.14 | ✅ Active |
| **5.2 LTS** | Apr 2025 | Dec 2025 (ended) | Apr 2028 | 3.10–3.14 | ✅ Security (LTS) |
| **5.1** | Aug 2024 | Apr 2025 (ended) | Dec 2025 (ended) | 3.10–3.13 | ❌ EOL |
| **5.0** | Dec 2023 | Aug 2024 (ended) | Apr 2025 (ended) | 3.10–3.12 | ❌ EOL |
| **4.2 LTS** | Apr 2023 | Dec 2023 (ended) | Apr 2026 (ended) | 3.8–3.12 | ❌ EOL |
| **4.1** | Aug 2022 | Apr 2023 (ended) | Dec 2023 (ended) | 3.8–3.11 | ❌ EOL |
| **4.0** | Dec 2021 | Aug 2022 (ended) | Apr 2023 (ended) | 3.8–3.10 | ❌ EOL |
| **3.2 LTS** | Apr 2021 | Dec 2021 (ended) | Apr 2024 (ended) | 3.6–3.10 | ❌ EOL |

**cpm check**: Django ≤ 4.2 → error (EOL). Django 5.1 → error (EOL). Only 5.2 LTS and 6.0 are supported.

### Python Runtime EOL

| Version | Release | EOL | Status (Jun 2026) |
|---------|---------|-----|-------------------|
| **3.14** | Oct 2025 | Oct 2030 | ✅ Active |
| **3.13** | Oct 2024 | Oct 2029 | ✅ Active |
| **3.12** | Oct 2023 | Oct 2028 | ✅ Active |
| **3.11** | Oct 2022 | Oct 2027 | ✅ Security only |
| **3.10** | Oct 2021 | Oct 2026 | ⚠️ Approaching EOL |
| **3.9** | Oct 2020 | Oct 2025 | ❌ EOL |
| **3.8** | Oct 2019 | Oct 2024 | ❌ EOL |

### Categorieën & Versie-Matrix

#### CMS — Content Management Systemen (Django-based)

| Systeem | Huidige versie | EOL versies | Detectie |
|---------|---------------|-------------|----------|
| **Wagtail** | 7.x (LTS: 7.4) | ≤ 5.x (EOL), 6.x (limited) | `pyproject.toml`/`requirements.txt` → `wagtail` |
| **Django CMS** | 4.x | ≤ 3.x (EOL) | `requirements.txt` → `django-cms` |
| **Plone** | 6.1 | ≤ 5.2 (EOL Oct 2024) | `buildout.cfg`, `requirements.txt` → `Plone` |
| **FeinCMS** | 24.x | Legacy, minimal updates | `requirements.txt` → `feincms` |
| **Lektor** | 3.x | — (static site gen, less critical) | `*.lektorproject` file |

#### E-commerce (Python)

| Systeem | Huidige versie | Stack | Detectie |
|---------|---------------|-------|----------|
| **Saleor** | 3.x | Django + GraphQL + PostgreSQL | `saleor/` dir, `pyproject.toml` |
| **Oscar (django-oscar)** | 3.x | Django + PostgreSQL | `requirements.txt` → `django-oscar` |
| **Shuup** | 2.x | Django + PostgreSQL | `requirements.txt` → `shuup` |

#### Data Products & AI Dashboards

| Systeem | Huidige versie | Risk Profile | Detectie |
|---------|---------------|-------------|----------|
| **Streamlit** | 1.37+ | Path traversal (Windows), XSS | `requirements.txt` → `streamlit` |
| **Dash (Plotly)** | 2.x | XSS in callbacks, no built-in auth | `requirements.txt` → `dash` |

#### ERP, Project Management & Collaboration

| Systeem | Huidige versie | EOL versies | Detectie |
|---------|---------------|-------------|----------|
| **Odoo** | 18.x | ≤ 14 (EOL Oct 2023), 15 (EOL Oct 2024), 16 (EOL Oct 2025) | `odoo/release.py`, `__manifest__.py` |
| **Taiga** | 6.x | ≤ 5.x (EOL) | `requirements.txt` → `taiga-back` |

#### DevOps, Documentation & Monitoring

| Systeem | Huidige versie | EOL versies | Detectie |
|---------|---------------|-------------|----------|
| **NetBox** | 4.x | ≤ 3.5 (EOL) | `requirements.txt` → `netbox`, `netbox/settings.py` |
| **Sentry** | 24.x (self-hosted) | Rolling releases, ≤ 23.x unsupported | `docker-compose.yml` → `sentry` |
| **MkDocs** | 1.6+ | — (static gen, low risk) | `mkdocs.yml` |

### CVEs per Systeem (2022–2026, Hoog Impact)

#### Django (Framework)

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2025-64459 | **9.8** | SQL injection in column aliases |
| CVE-2025-13372 | **9.1** | SQL injection in column aliases (variant) |
| CVE-2024-39330 | 7.5 | Path traversal |
| CVE-2024-38875 | 7.5 | DoS via large number of request parameters |
| CVE-2024-39614 | 5.3 | DoS via `get_supported_language_variant()` |
| CVE-2023-36053 | 7.5 | ReDoS in EmailValidator/URLValidator |

#### Wagtail CMS

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2026-25517 | 6.1 | XSS (found in security audit, already patched) |
| CVE-2024-39317 | 5.4 | Search query injection (admin-only) |
| CVE-2023-28837 | 6.5 | DoS via large file upload |
| CVE-2023-45809 | 4.3 | User enumeration via admin |
| CVE-2023-28836 | 5.4 | XSS in ModelAdmin (admin-only) |

#### Saleor (E-commerce)

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2026-35401 | 7.5 | GraphQL DoS via query batching/aliases |

#### Odoo (ERP)

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2023-48050 | **9.8** | SQL injection in biometric module (3rd party) |
| CVE-2023-1434 | 6.1 | XSS via incorrect content type |
| Mail module (2024) | 5.3 | Information disclosure via oracle attack |

#### Streamlit

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-42474 | 7.5 | Path traversal → password hash leak (Windows) |
| CVE-2023-27494 | 6.1 | Stored XSS |

#### Sentry SDK

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2024-40647 | 5.3 | Subprocess environment inheritance bypass |

### Hardening & Misconfiguration Checks

#### check-django.sh + check-django-security.sh (exists)

Already covers: fat views, signal abuse, custom user model, SQL injection, N+1, security middleware, DEBUG, SECRET_KEY, ALLOWED_HOSTS, CORS, CSRF, HSTS, rate limiting, admin URL, logging, uploads.

#### check-fastapi.sh (API Security)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | No authentication | error | No `Depends(get_current_user)` or OAuth2 in routes |
| 2 | CORS wildcard | error | `allow_origins=["*"]` in CORSMiddleware |
| 3 | No rate limiting | warning | No `slowapi` or middleware throttle |
| 4 | Debug mode in production | error | `--reload` flag in Dockerfile/docker-compose |
| 5 | No input validation | warning | Route params without Pydantic model |
| 6 | Exposed docs in production | warning | `/docs` and `/redoc` enabled without auth |
| 7 | No HTTPS redirect | warning | No `HTTPSRedirectMiddleware` |
| 8 | Unsafe file handling | warning | `UploadFile` without size/type validation |

#### check-python-cms.sh (Wagtail/DjangoCMS/Plone)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Wagtail ≤ 5.x EOL | error | Version in requirements |
| 2 | Plone ≤ 5.2 EOL | error | Version in buildout/requirements |
| 3 | Django CMS ≤ 3.x EOL | error | Version in requirements |
| 4 | No image upload size limit | warning | Missing `WAGTAILIMAGES_MAX_UPLOAD_SIZE` |
| 5 | Admin accessible without 2FA | warning | No `django-otp` or `wagtail-2fa` |

#### check-python-ecommerce.sh (Saleor/Oscar)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | GraphQL introspection enabled | warning | No `GRAPHQL_MIDDLEWARE` to disable |
| 2 | No query depth/complexity limit | error | Missing `graphene-django` depth limiter |
| 3 | Payment secrets in code | error | Stripe/payment keys in source |
| 4 | No CSP headers | warning | Missing django-csp |

#### check-python-data.sh (Streamlit/Dash)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Streamlit < 1.37 (path traversal) | error | Version in requirements |
| 2 | No authentication | error | No `st.login` / no auth wrapper |
| 3 | Static file sharing enabled | warning | `.streamlit/config.toml` → `enableStaticServing` |
| 4 | Dash debug mode | error | `app.run_server(debug=True)` in production code |
| 5 | Callbacks without auth | warning | No `dash-auth` or Flask-Login |

#### check-python-devops.sh (NetBox/Odoo/Sentry)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Odoo ≤ 16 EOL | error | Version in `odoo/release.py` / docker image |
| 2 | NetBox ≤ 3.5 EOL | error | Version in requirements/docker |
| 3 | Odoo master password default | error | `admin_passwd` = 'admin' in config |
| 4 | NetBox SECRET_KEY default | error | Default/empty `SECRET_KEY` in config |
| 5 | Sentry debug mode | warning | `DEBUG=True` in `.env` |
| 6 | No HTTPS in Odoo config | warning | `xmlrpc_interface` on `0.0.0.0` without proxy |

### Detection Gating

```bash
# Django (framework)
grep -q "django" "$REPO/requirements.txt" "$REPO/pyproject.toml" 2>/dev/null || exit 0

# FastAPI
grep -q "fastapi" "$REPO/requirements.txt" "$REPO/pyproject.toml" 2>/dev/null || exit 0

# Wagtail
grep -q "wagtail" "$REPO/requirements.txt" "$REPO/pyproject.toml" 2>/dev/null || exit 0

# Odoo
[ -f "$REPO/odoo-bin" ] || grep -q "odoo" "$REPO/requirements.txt" 2>/dev/null || exit 0

# Streamlit
grep -q "streamlit" "$REPO/requirements.txt" "$REPO/pyproject.toml" 2>/dev/null || exit 0

# Saleor
[ -d "$REPO/saleor" ] && grep -q "saleor" "$REPO/pyproject.toml" 2>/dev/null || exit 0
```

### Naming Convention (per CONVENTIONS.md)

| Script | Standardized Name |
|--------|-------------------|
| check-django.sh | `code-python-quality-lint` |
| check-django-security.sh | `code-python-vulnerability-scan` |
| check-fastapi.sh | `code-python-vulnerability-scan` |
| check-python-cms.sh | `code-python-vulnerability-scan` |
| check-python-ecommerce.sh | `code-python-vulnerability-scan` |
| check-python-data.sh | `code-python-vulnerability-scan` |
| check-python-devops.sh | `code-python-vulnerability-scan` |
| check-python-eol.sh | `libs-python-version-detect` |

### Implementation Priority

| Check | Priority | Effort | Impact |
|-------|----------|--------|--------|
| check-django.sh / security (exists) | ✅ Done | — | Foundation for all Django-based apps |
| check-fastapi.sh | **High** | Low | FastAPI = fastest growing Python framework |
| check-python-devops.sh | **High** | Medium | Odoo/NetBox widely deployed, critical CVEs |
| check-python-cms.sh | Medium | Low | Smaller market than PHP CMS |
| check-python-data.sh | Medium | Low | Growing fast, often internal/exposed tools |
| check-python-ecommerce.sh | Medium | Low | Niche but high financial impact |
| check-python-eol.sh | **High** | Low | Parse pyproject.toml / Dockerfile |

### Key Difference: PHP vs Python Ecosystem

| Aspect | PHP | Python |
|--------|-----|--------|
| **Deployment model** | Ready-to-install (download, extract, run) | Build from source / pip install / Docker |
| **Version detection** | Version constants in PHP files | `requirements.txt`, `pyproject.toml`, Dockerfile |
| **Update cycle** | Manual (often neglected) | pip/poetry update (often automated) |
| **Primary risk** | Outdated installations, plugin vulns | Misconfiguration, exposed APIs, no auth |
| **Attack surface** | Publicly exposed web interfaces | APIs, dashboards, internal tools exposed |
| **CVE profile** | More RCE/SQLi (legacy code) | More DoS, info disclosure, auth bypass |

## Web Hosting Control Panels & PaaS Platforms

Hosting panels are the most critical infrastructure software — a compromised panel means full server takeover. They manage PHP versions, databases, SSL, DNS, email, and file systems. cpm should detect and check these when scanning servers or Docker deployments.

### Architecture

```text
checks/
├── universal/
│   ├── check-hosting-panel.sh          # Version EOL + hardening (all panels)
│   └── check-paas-platform.sh          # Docker PaaS security (Coolify/CapRover/Dokku)
```

### Categorieën & Systemen

#### Commercial Hosting Panels

| Systeem | Stack | Detectie | Risk Profile |
|---------|-------|----------|-------------|
| **cPanel/WHM** | Perl/PHP + Apache/LiteSpeed + MySQL | `/usr/local/cpanel/`, port 2087 | High (massive attack surface) |
| **Plesk** | PHP + Nginx/Apache + MariaDB | `/usr/local/psa/`, port 8443 | High (XSS→server compromise) |
| **DirectAdmin** | C++ + Apache/Nginx + MySQL | `/usr/local/directadmin/`, port 2222 | Medium |
| **InterWorx** | PHP + Apache + MySQL | `/home/interworx/`, port 2443 | Medium |

#### Cloud Panels (SaaS-managed, check in docker-compose/Dockerfile)

| Systeem | Stack | Detectie |
|---------|-------|----------|
| **RunCloud** | Agent-based | `runcloud-agent` service |
| **Laravel Forge** | Agent-based | `/etc/forge/` config |
| **SpinupWP** | Agent-based | `spinupwp` service |
| **Ploi** | Agent-based | `ploi-agent` |
| **ServerAvatar** | Agent-based | `serveravatar` |

#### Open-Source Panels (Self-Hosted)

| Systeem | Stack | Detectie | Risk Profile |
|---------|-------|----------|-------------|
| **CyberPanel** | Python + OpenLiteSpeed | `/usr/local/CyberPanel/`, port 8090 | **CRITICAL** (mass exploitation 2024) |
| **aaPanel** | Python + Nginx/Apache | `/www/server/panel/`, port 8888 | High |
| **HestiaCP** | Bash/PHP + Nginx/Apache | `/usr/local/hestia/`, port 8083 | Medium |
| **CloudPanel** | Node.js + Nginx + MySQL | `/home/clp/`, port 8443 | High (RCE CVE-2023-35885) |
| **FastPanel** | PHP + Nginx | port 8888 | Medium |
| **KeyHelp** | PHP + Apache/Nginx | `/opt/keyhelp/`, port 8443 | Low-Medium |
| **Webmin/Virtualmin** | Perl + Apache | `/etc/webmin/`, port 10000 | High (RCE CVE-2024-12828) |
| **Cockpit** | C + systemd | port 9090 | Low (limited scope) |

#### PaaS / Docker Platforms

| Systeem | Stack | Detectie | Risk Profile |
|---------|-------|----------|-------------|
| **Coolify** | PHP/Laravel + Docker | `docker-compose.yml` → coolify image | Medium (7 CVEs found in 2025) |
| **CapRover** | Node.js + Docker | `captain-definition`, port 3000 | Medium |
| **Dokku** | Bash + Docker + Herokuish | `/home/dokku/`, `dokku` command | Low-Medium |
| **Easypanel** | Node.js + Docker | port 3000 | Medium |

### Critical CVEs — Hosting Panels (2022–2026)

#### CyberPanel (CRITICAL — Mass Exploitation)

| CVE | CVSS | Beschrijving | Impact |
|-----|------|-------------|--------|
| **CVE-2024-51378** | **10.0** | Pre-auth RCE via command injection in `/dns/getresetstatus` | **22,000 servers compromised by PSAUX ransomware** |
| **CVE-2024-51567** | **10.0** | Pre-auth RCE via `upgrademysqlstatus` | Same mass exploitation campaign |
| **CVE-2024-51568** | **9.8** | Pre-auth RCE via File Manager upload | Unauthenticated |
| **CVE-2024-53376** | 8.8 | Authenticated RCE (< 2.3.8) | Post-auth |

#### CloudPanel

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| **CVE-2023-35885** | **9.8** | RCE in CloudPanel 2 (< 2.3.1) |

#### Webmin / Virtualmin

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| **CVE-2024-12828** | **9.8** | CGI command injection → RCE (authenticated, ~1M installs) |
| **CVE-2024-45692** | **9.1** | DoS → server inaccessible |
| CVE-2023-52046 | 6.1 | Stored XSS |
| CVE-2023-38303 | 8.8 | XSS → RCE via user real name field |
| CVE-2024-36450 | 6.1 | XSS in Virtualmin |

#### Plesk

| CVE | CVSS | Beschrijving |
|-----|------|-------------|
| CVE-2023-0829 | **8.4** | Stored XSS → full server compromise (admin visits page) |
| CVE-2023-4931 | 7.8 | DLL hijacking in installer |
| CVE-2023-24044 | 6.1 | Open redirect (phishing) |

#### Coolify

| Issue | Beschrijving |
|-------|-------------|
| 7 CVEs (2025) | Found via AI pentesting: auth bypass, SSRF, info disclosure |

### Hardening & Misconfiguration Checks

#### check-hosting-panel.sh

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | CyberPanel detected (any version < 2.3.8) | **critical** | Port 8090, `/usr/local/CyberPanel/` |
| 2 | CloudPanel < 2.3.1 (RCE) | **critical** | Port 8443, `/home/clp/` |
| 3 | Webmin/Virtualmin < 2.111 | error | Port 10000, `/etc/webmin/` |
| 4 | Panel on default port (public) | error | Panel port exposed in docker-compose/firewall |
| 5 | Panel accessible without IP allowlist | error | No `allow_ip` or firewall restrict |
| 6 | No 2FA on panel login | warning | Config check per panel |
| 7 | Panel SSL self-signed | warning | Self-signed cert on panel port |
| 8 | Panel auto-update disabled | warning | Auto-update config per panel |
| 9 | Panel running as root | warning | Process user check |
| 10 | Default admin credentials | error | Default username `admin`/`administrator` |
| 11 | Panel version outdated (>6 months) | warning | Version vs latest release |
| 12 | Backup not configured | warning | No backup job in panel config |
| 13 | phpMyAdmin publicly accessible | warning | `/phpmyadmin/` on default port |
| 14 | Webmail on default path | info | `/webmail/`, `/roundcube/` |

#### check-paas-platform.sh (Docker PaaS)

| # | Check | Severity | Detectie |
|---|-------|----------|----------|
| 1 | Coolify outdated (< latest stable) | warning | docker-compose image tag |
| 2 | CapRover dashboard exposed publicly | error | Port 3000 in docker-compose without auth |
| 3 | Dokku SSH keys not rotated | warning | Key age in `/home/dokku/.ssh/` |
| 4 | Docker socket mounted without protection | error | `/var/run/docker.sock` in docker-compose |
| 5 | No reverse proxy with SSL | warning | Direct port exposure without Traefik/Nginx |
| 6 | Default Coolify admin password | error | First-run password not changed |
| 7 | CapRover wildcard DNS not configured | warning | Missing `*.captain.domain` |

### Detection Gating

```bash
# Hosting panel detection (scan mode)
detect_panel() {
  # File-based detection (fast, for scan mode)
  [ -d "$REPO/usr/local/CyberPanel" ] && echo "cyberpanel" && return
  [ -d "$REPO/usr/local/hestia" ] && echo "hestiacp" && return
  [ -d "$REPO/home/clp" ] && echo "cloudpanel" && return
  [ -f "$REPO/etc/webmin/config" ] && echo "webmin" && return

  # Docker-compose based detection
  if [ -f "$REPO/docker-compose.yml" ]; then
    grep -q "coolify" "$REPO/docker-compose.yml" && echo "coolify" && return
    grep -q "caprover" "$REPO/docker-compose.yml" && echo "caprover" && return
    grep -q "dokku" "$REPO/docker-compose.yml" && echo "dokku" && return
    grep -q "easypanel" "$REPO/docker-compose.yml" && echo "easypanel" && return
  fi
  exit 0
}
```

### Implementation Priority

| Check | Priority | Effort | Rationale |
|-------|----------|--------|-----------|
| CyberPanel detection | **Critical** | Low | Mass exploitation (22k servers ransomwared) |
| CloudPanel < 2.3.1 | **Critical** | Low | Public RCE exploit |
| Webmin < 2.111 | **High** | Low | ~1M installations, RCE |
| Panel port exposure | **High** | Low | Generic, applies to all panels |
| PaaS Docker socket | **High** | Low | Container escape risk |
| Generic panel hardening | Medium | Medium | 2FA, IP allowlist, auto-update |

## References

- OWASP Laravel Cheat Sheet: <https://cheatsheetseries.owasp.org/cheatsheets/Laravel_Cheat_Sheet>
- Securing Laravel Top 10 (2024): <https://securinglaravel.com/in-depth-laravel-security-audits-top-10-2024/>
- WordPress Security (Patchstack 2025): <https://patchstack.com/whitepaper/state-of-wordpress-security-in-2025/>
- Wordfence Annual Report 2024: <https://www.wordfence.com/blog/2025/04/2024-annual-wordpress-security-report-by-wordfence/>
- Magento CosmicSting: <https://mgt-commerce.com/blog/magento-2-4-exploit/>
- PHP EOL: <https://endoflife.date/php>
- Laravel EOL: <https://laravelversions.com/>
- MySQL EOL: <https://endoflife.date/mysql>
- PostgreSQL EOL: <https://endoflife.date/postgresql>
- Drupal EOL: <https://eosl.date/eol/product/drupal/>
- Nextcloud EOL: <https://eosl.date/eol/product/nextcloud/>
- Joomla EOL: <https://eosl.date/eol/product/joomla/>
- CVE-2024-4577: <https://nvd.nist.gov/vuln/detail/cve-2024-4577>
- CVE-2024-34102 (Magento): <https://nvd.nist.gov/vuln/detail/CVE-2024-34102>
- CVE-2024-36412 (SuiteCRM): <https://www.sonicwall.com/blog/critical-sql-injection-vulnerability-in-suitecrm-cve-2024-36412>
- @see docs/adrs/adr-013-product-positioning.md
- @see checks/python/django/check-django.sh (reference implementation)
