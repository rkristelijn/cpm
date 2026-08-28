# Secrets Detection Rules (SECRETS-001 – SECRETS-080)

cpm ships 80 pattern-based rules that detect hardcoded secrets, tokens, and credentials across all file types. These complement the existing `secrets.cpp` built-in checks (AWS AKIA, GitHub ghp_/gho_, OpenAI sk-, Slack xox, Google AIza, Stripe sk_live_, BEGIN PRIVATE KEY).

## Rules

### Cloud Providers (001–010)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-001 | Azure Storage Account Key | error | pattern |
| SECRETS-002 | Azure AD Client Secret | error | pattern |
| SECRETS-003 | GCP Service Account JSON Key | error | pattern |
| SECRETS-004 | DigitalOcean Personal Access Token | error | pattern |
| SECRETS-005 | DigitalOcean OAuth Token | error | pattern |
| SECRETS-006 | Heroku API Key | error | pattern |
| SECRETS-007 | Alibaba Cloud AccessKey | error | pattern |
| SECRETS-008 | IBM Cloud API Key | error | pattern |
| SECRETS-009 | Linode API Token | error | pattern |
| SECRETS-010 | Vultr API Key | error | pattern |

### CI/CD & DevOps (011–020)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-011 | GitLab Personal Access Token | error | pattern |
| SECRETS-012 | GitLab Pipeline Token | error | pattern |
| SECRETS-013 | GitLab Runner Registration Token | error | pattern |
| SECRETS-014 | Bitbucket App Password | error | pattern |
| SECRETS-015 | CircleCI API Token | error | pattern |
| SECRETS-016 | Travis CI Token | error | pattern |
| SECRETS-017 | Jenkins API Token | error | pattern |
| SECRETS-018 | Drone CI Token | error | pattern |
| SECRETS-019 | npm Token | error | pattern |
| SECRETS-020 | PyPI Token | error | pattern |

### Communication & Messaging (021–030)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-021 | Discord Bot Token | error | pattern |
| SECRETS-022 | Discord Webhook URL | error | pattern |
| SECRETS-023 | Telegram Bot Token | error | pattern |
| SECRETS-024 | Twilio API Key | error | pattern |
| SECRETS-025 | Twilio Account SID | error | pattern |
| SECRETS-026 | SendGrid API Key | error | pattern |
| SECRETS-027 | Mailgun API Key | error | pattern |
| SECRETS-028 | Mailchimp API Key | error | pattern |
| SECRETS-029 | Postmark Server Token | error | pattern |
| SECRETS-030 | Microsoft Teams Webhook | error | pattern |

### Payment & Finance (031–038)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-031 | Stripe Restricted API Key | error | pattern |
| SECRETS-032 | Square Access Token | error | pattern |
| SECRETS-033 | Square OAuth Secret | error | pattern |
| SECRETS-034 | PayPal Braintree Access Token | error | pattern |
| SECRETS-035 | Shopify Access Token | error | pattern |
| SECRETS-036 | Shopify Custom App Token | error | pattern |
| SECRETS-037 | Shopify Shared Secret | error | pattern |
| SECRETS-038 | Adyen API Key | error | pattern |

### Database Connection Strings (039–045)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-039 | MongoDB Connection URI with Password | error | pattern |
| SECRETS-040 | PostgreSQL URI with Password | error | pattern |
| SECRETS-041 | MySQL URI with Password | error | pattern |
| SECRETS-042 | Redis URI with Password | error | pattern |
| SECRETS-043 | AMQP URI with Password | error | pattern |
| SECRETS-044 | JDBC Connection String with Password | error | pattern |
| SECRETS-045 | SQLAlchemy URI with Password | error | pattern |

### SaaS & API Services (046–065)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-046 | Datadog API Key | error | pattern |
| SECRETS-047 | New Relic API Key | error | pattern |
| SECRETS-048 | New Relic License Key | error | pattern |
| SECRETS-049 | PagerDuty API Key | error | pattern |
| SECRETS-050 | Sentry DSN | error | pattern |
| SECRETS-051 | Algolia API Key | error | pattern |
| SECRETS-052 | Cloudflare API Key | error | pattern |
| SECRETS-053 | Cloudflare Global API Key | error | pattern |
| SECRETS-054 | Auth0 Client Secret | error | pattern |
| SECRETS-055 | Firebase Cloud Messaging Server Key | error | pattern |
| SECRETS-056 | Supabase Service Key | error | pattern |
| SECRETS-057 | Vercel Access Token | error | pattern |
| SECRETS-058 | Netlify Access Token | error | pattern |
| SECRETS-059 | LaunchDarkly SDK Key | error | pattern |
| SECRETS-060 | Contentful Access Token | error | pattern |
| SECRETS-061 | HubSpot API Key | error | pattern |
| SECRETS-062 | Intercom Access Token | error | pattern |
| SECRETS-063 | Zendesk API Token | error | pattern |
| SECRETS-064 | Atlassian API Token | error | pattern |
| SECRETS-065 | Linear API Key | error | pattern |

### Infrastructure & Security (066–075)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-066 | HashiCorp Vault Token | error | pattern |
| SECRETS-067 | HashiCorp Terraform Cloud Token | error | pattern |
| SECRETS-068 | Doppler Service Token | error | pattern |
| SECRETS-069 | Age Secret Key | error | pattern |
| SECRETS-070 | 1Password Service Account Token | error | pattern |
| SECRETS-071 | Pulumi Access Token | error | pattern |
| SECRETS-072 | Grafana API Key | error | pattern |
| SECRETS-073 | Elastic API Key | error | pattern |
| SECRETS-074 | Confluent Cloud API Key | error | pattern |
| SECRETS-075 | Snyk API Token | error | pattern |

### Generic High-Signal (076–080)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| SECRETS-076 | Generic API Key Assignment | error | pattern |
| SECRETS-077 | Generic Secret Assignment | error | pattern |
| SECRETS-078 | Generic Password Assignment | error | pattern |
| SECRETS-079 | Generic Private Key (DSA/OPENSSH/PGP) | error | pattern |
| SECRETS-080 | Bearer Token in Source Code | error | pattern |

## Fix guidance

All secrets rules have severity `error` — they always block in `guard` and `enforce` modes.

**General fix:** Move secrets to environment variables or a secrets manager.

```bash
# Bad — hardcoded in source
STRIPE_KEY=rk_live_abc123

# Good — environment variable
STRIPE_KEY=${STRIPE_KEY:?Missing STRIPE_KEY}

# Good — secrets manager
vault kv get -field=stripe_key secret/app
```

**Exclude paths:** All rules automatically skip `node_modules/`, `vendor/`, `.git/`, `test/fixtures/`, and lock files.

## Configuration

```toml
# cpm.toml — skip specific rules
[skip]
rules = ["SECRETS-076"]  # too noisy for this project

# Or disable the entire category
[checks]
code-generic-secrets-scan = false
```

## Relationship to built-in checks

The `secrets.cpp` engine in cpm's C++ binary handles the highest-priority patterns (AWS, GitHub, OpenAI, Slack, Google, Stripe, PEM keys). These 80 `.rule` files extend coverage to 80+ additional providers and generic patterns via the rule engine.

## References

- @see rules/secrets/ — all 80 rule files
- @see src/secrets.cpp — built-in high-priority patterns
- @see docs/adrs/adr-014-findings-database.md — JSONL output format
