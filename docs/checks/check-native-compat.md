# check-native-compat

`checks/javascript/check-native-compat.sh`

Detects usage of native JavaScript APIs that are not available in your target Node.js version or edge runtime (Cloudflare Workers, Vercel Edge).

## How it works

1. Reads target Node version from `.nvmrc`, `.node-version`, or `package.json` engines
2. Scans code for APIs introduced in newer Node versions
3. Detects edge runtime (wrangler.toml, `runtime = 'edge'`) and flags Node-only APIs

## API compatibility table

| API | Minimum Node |
|-----|-------------|
| `Object.hasOwn()` | 16.9 |
| `structuredClone()` | 17 |
| `.findLast()` | 18 |
| `fetch()` | 18 |
| `crypto.randomUUID()` | 15.6 |
| `.toSorted()`, `.toReversed()`, `.toSpliced()` | 20 |
| `Object.groupBy()`, `Map.groupBy()` | 21 |
| `Promise.withResolvers()` | 22 |
| `fs.glob()` | 22 |
| `Temporal.*` | Not yet stable |

## Edge runtime restrictions

Flags usage of Node-only APIs in files that declare edge runtime:

- `fs`, `child_process` — not available
- `__dirname`, `__filename` — not available in ESM/edge
- `eval()`, `new Function()` — blocked
- `require()` — not available (use import)

## Severity

- warning: API not available in target Node version
- error: API used in edge runtime where it's blocked

## References

- Source: `checks/javascript/check-native-compat.sh`
- [Node.js API compatibility](https://node.green)
- [Cloudflare Workers runtime APIs](https://developers.cloudflare.com/workers/runtime-apis/)
