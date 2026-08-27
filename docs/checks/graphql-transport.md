# GraphQL & Transport Security Rules

Two rule categories that cover API-layer and network-layer security: GraphQL server hardening (GQL-001–GQL-015) and TLS/transport verification (TRANS-001–TRANS-007).

## GraphQL Rules (GQL-001 – GQL-015)

Detect misconfiguration and denial-of-service risks in GraphQL servers (Apollo, Express-GraphQL, Yoga, etc.).

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| GQL-001 | GraphQL server without depth limiting | warning | presence |
| GQL-002 | GraphQL server without query cost/complexity analysis | warning | presence |
| GQL-003 | GraphQL introspection enabled in production | warning | pattern |
| GQL-004 | Apollo CSRF prevention disabled | error | pattern |
| GQL-005 | GraphQL server without rate limiting | warning | presence |
| GQL-006 | GraphQL resolvers without DataLoader (N+1 risk) | warning | absence |
| GQL-007 | GraphQL error formatting may leak stack traces | warning | pattern |
| GQL-008 | Deprecated schemaDirectives usage (Apollo Server 4) | info | pattern |
| GQL-010 | GraphQL server without query depth limit (DoS risk) | warning | pattern |
| GQL-011 | Query without pagination | info | pattern |
| GQL-012 | Mutation without input type | info | pattern |
| GQL-013 | Deeply nested array type | warning | pattern |
| GQL-014 | Exposed introspection in production | warning | pattern |
| GQL-015 | Missing @deprecated directive | info | pattern |

### Fix guidance

```javascript
// Bad — no depth limit, no complexity limit, introspection on
const server = new ApolloServer({
  schema,
  introspection: true,
  csrfPrevention: false,
});

// Good — hardened Apollo Server
import depthLimit from 'graphql-depth-limit';
import { createComplexityLimitRule } from 'graphql-validation-complexity';

const server = new ApolloServer({
  schema,
  introspection: process.env.NODE_ENV !== 'production',
  csrfPrevention: true,
  validationRules: [
    depthLimit(10),
    createComplexityLimitRule(1000),
  ],
  formatError: (err) => ({
    message: err.message,  // no stack trace
  }),
});
```

```javascript
// Bad — N+1 queries in resolvers
resolve: (parent) => db.query('SELECT * FROM users WHERE id = ?', [parent.userId])

// Good — DataLoader batching
const userLoader = new DataLoader(ids => db.query('SELECT * FROM users WHERE id IN (?)', [ids]));
resolve: (parent) => userLoader.load(parent.userId)
```

## Transport Security Rules (TRANS-001 – TRANS-007)

Detect disabled TLS verification and insecure transport patterns. Disabling certificate checks enables man-in-the-middle attacks.

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| TRANS-001 | TLS certificate verification disabled via environment variable | error | pattern |
| TRANS-002 | curl with --insecure flag skips TLS verification | error | pattern |
| TRANS-003 | wget with --no-check-certificate skips TLS verification | error | pattern |
| TRANS-004 | Python requests with verify=False disables TLS verification | error | pattern |
| TRANS-005 | Plain HTTP URL in configuration file | warning | pattern |
| TRANS-006 | SSH host key checking disabled (MITM risk) | error | pattern |
| TRANS-007 | Git SSL verification disabled (MITM risk) | error | pattern |

### Fix guidance

```bash
# Bad — disables TLS verification
curl -k https://api.example.com/data
curl --insecure https://api.example.com/data
wget --no-check-certificate https://files.example.com/pkg.tar.gz
export NODE_TLS_REJECT_UNAUTHORIZED=0
export GIT_SSL_NO_VERIFY=true

# Good — proper certificate handling
curl --cacert /etc/ssl/certs/ca-certificates.crt https://api.example.com/data
wget https://files.example.com/pkg.tar.gz  # uses system CA bundle
# If you need a custom CA:
curl --cacert /path/to/custom-ca.pem https://internal.api/data
```

```python
# Bad
requests.get('https://api.example.com', verify=False)

# Good — use system CA or specify bundle
requests.get('https://api.example.com')
requests.get('https://internal.api', verify='/path/to/ca-bundle.crt')
```

## Configuration

```toml
# cpm.toml — skip transport check for dev scripts
[skip]
rules = ["TRANS-005"]  # allow http:// in local dev config

# Target files:
# GraphQL: .ts, .js, .mjs, .graphql, .gql
# Transport: .sh, .bash, .yml, .yaml, .toml, .env, .py, .js, .ts
```

## References

- @see rules/graphql/ — GraphQL rule files
- @see rules/transport/ — transport rule files
- @see https://cheatsheetseries.owasp.org/cheatsheets/GraphQL_Cheat_Sheet.html
- @see https://owasp.org/www-project-web-security-testing-guide/ — TLS testing
