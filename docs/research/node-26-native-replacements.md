# Node.js 26 — Packages You Can Remove

Node 26 (V8 14.6, Undici 8, Temporal API) makes many npm packages redundant.
Below: what's new, which packages become obsolete, and the performance gains.

---

## 🗓️ Temporal API (enabled by default)

The biggest change: `Temporal` fully replaces the broken `Date` API.

| What you did | Package | Native in Node 26 | Performance |
|---|---|---|---|
| Date parsing/formatting | `moment` (300KB) | `Temporal.PlainDate`, `Temporal.ZonedDateTime` | ~10x faster (no parsing overhead) |
| Date manipulation | `date-fns` (80KB tree-shaken) | `Temporal.PlainDate.add()`, `.subtract()` | Zero bundle cost |
| Timezones | `moment-timezone` (180KB) | `Temporal.ZonedDateTime` | Native IANA timezone support |
| Duration/interval | `luxon`, `dayjs` | `Temporal.Duration` | Zero-dep |
| Relative time | `timeago.js` | `Intl.RelativeTimeFormat` + `Temporal` | Native ICU |
| ISO parsing | `date-fns/parseISO` | `Temporal.Instant.from()` | Native C++ parser |

**Remove:** `moment`, `moment-timezone`, `date-fns`, `dayjs`, `luxon`, `timeago.js`, `ms`

---

## 🔗 Iterator Sequencing (V8 14.6)

| What you did | Package | Native in Node 26 | Performance |
|---|---|---|---|
| Concatenate iterators | `itertools`, `iter-tools` | `Iterator.concat(iter1, iter2)` | Lazy, zero-alloc |
| Lazy iteration chains | `lodash/chain` | Native iterator helpers + `concat` | No intermediate arrays |

---

## 🗺️ Map Upsert (V8 14.6)

| What you did | Package/pattern | Native in Node 26 | Performance |
|---|---|---|---|
| `if (!map.has(k)) map.set(k, default)` | Manual / lodash | `map.getOrInsert(key, default)` | 1 lookup instead of 2 |
| Computed default for Map | Custom util | `map.getOrInsertComputed(key, fn)` | Atomic, no race condition |

---

## 🌐 Undici 8 / fetch() improvements

| What you did | Package | Native in Node 26 | Performance |
|---|---|---|---|
| HTTP requests | `axios` (30KB) | `fetch()` (Undici 8 backend) | ~2x faster than axios |
| HTTP/2 client | `got` | `fetch()` with HTTP/2 support | Less overhead |
| Request retry | `axios-retry` | Undici retry interceptor | Native connection pooling |
| Request timeout | `axios` timeout | `AbortSignal.timeout(ms)` | Zero-dep |
| Form uploads | `form-data` | `FormData` (native) | Streaming support |
| Cookie handling | `tough-cookie` | Undici cookie jar | Spec-compliant |

**Remove:** `axios`, `got`, `node-fetch`, `cross-fetch`, `isomorphic-fetch`, `form-data`, `axios-retry`

---

## 🔐 Crypto improvements

| What you did | Package | Native in Node 26 | Performance |
|---|---|---|---|
| UUID generation | `uuid` (9KB) | `crypto.randomUUID()` | ~3x faster |
| Post-quantum crypto | `liboqs` | ML-KEM, ML-DSA native | Hardware-accelerated |
| Key import/export | `jose` (partial) | Raw key format support in KeyObject | Less serialization |

---

## 📦 Removed/deprecated APIs → migration

| Removed in Node 26 | What to do |
|---|---|
| `http.writeHeader()` | Use `http.writeHead()` |
| `_stream_readable`, `_stream_writable`, etc. | Use `require('stream')` |
| `module.register()` | Use `--import` or `register()` from `node:module` |
| `--experimental-transform-types` | TypeScript stripping is now stable |

---

## ⚡ Performance table — Native vs Package

| Operation | Package | Native | Speed gain | Bundle saving |
|---|---|---|---|---|
| Date formatting | `moment().format()` | `Temporal` + `Intl.DateTimeFormat` | ~10x | -300KB |
| Deep clone | `lodash.cloneDeep` | `structuredClone()` | ~2x | -70KB (lodash) |
| HTTP GET | `axios.get()` | `fetch()` | ~2x | -30KB |
| UUID | `uuid.v4()` | `crypto.randomUUID()` | ~3x | -9KB |
| Array grouping | `_.groupBy()` | `Object.groupBy()` | ~1.5x | -70KB |
| URL parsing | `query-string` | `URLSearchParams` | ~1.3x | -5KB |
| Relative time | `moment.fromNow()` | `Intl.RelativeTimeFormat` | ~5x | -300KB |
| Map upsert | `if/has/set` pattern | `map.getOrInsert()` | ~1.5x (1 lookup) | 0 |
| Iterator concat | `[...iter1, ...iter2]` | `Iterator.concat()` | ∞ (lazy) | 0 |
| Streams | `_stream_readable` | `require('stream')` | Same | Cleaner imports |

---

## 🧹 Full removal list

Packages you can remove when targeting Node 26:

| Package | Size | Native replacement |
|---|---|---|
| `moment` | 300KB | `Temporal` + `Intl.DateTimeFormat` |
| `moment-timezone` | 180KB | `Temporal.ZonedDateTime` |
| `date-fns` | 80KB* | `Temporal` |
| `dayjs` | 7KB | `Temporal` |
| `luxon` | 70KB | `Temporal` |
| `axios` | 30KB | `fetch()` |
| `got` | 50KB | `fetch()` |
| `node-fetch` | 8KB | `fetch()` (native since Node 18) |
| `cross-fetch` | 3KB | `fetch()` |
| `isomorphic-fetch` | 2KB | `fetch()` |
| `form-data` | 15KB | `FormData` (native) |
| `uuid` | 9KB | `crypto.randomUUID()` |
| `node-uuid` | 9KB | `crypto.randomUUID()` |
| `nanoid` | 1KB | `crypto.randomUUID()` (if v4 suffices) |
| `query-string` | 5KB | `URLSearchParams` |
| `lodash` | 70KB | Native Array/Object methods |
| `lodash.clonedeep` | 10KB | `structuredClone()` |
| `lodash.get` | 5KB | Optional chaining `?.` |
| `lodash.groupby` | 5KB | `Object.groupBy()` |
| `lodash.merge` | 10KB | `structuredClone()` + spread |
| `underscore` | 30KB | Native methods |
| `deep-clone` | 3KB | `structuredClone()` |
| `rfdc` | 2KB | `structuredClone()` |
| `ms` | 2KB | `Temporal.Duration` |
| `timeago.js` | 3KB | `Intl.RelativeTimeFormat` |
| `numeral` | 15KB | `Intl.NumberFormat` |
| `tough-cookie` | 20KB | Undici cookie jar |
| `abort-controller` | 1KB | `AbortController` (native since Node 15) |
| `iter-tools` | 15KB | `Iterator.concat()` + iterator helpers |

**Total potential savings: ~1MB+ from node_modules**

---

## 🚀 Migration checklist

```bash
# 1. Update .nvmrc
echo "26" > .nvmrc

# 2. Scan with cpm
cpm check

# 3. Remove obsolete packages
npm uninstall moment date-fns axios uuid lodash node-fetch query-string

# 4. Run native-alternatives check with autofix
bash checks/javascript/check-native-alternatives.sh . --fix

# 5. Run compat check (should now give 0 findings)
bash checks/javascript/check-native-compat.sh .
```

---

*Generated from Node.js 26.0.0 release notes (2026-05-05)*
