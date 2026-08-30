# Level 2 Packages — Transitive dependency replacements

> ℹ️ **Note:** This research was conducted for Node.js ecosystem analysis, not for cpm internals.

"Level 2" packages are libraries that internally depend on lodash, moment, axios, etc.
Replacing them with modern alternatives eliminates the entire transitive tree.

---

## 📦 Packages that pull in `lodash`

| Package (uses lodash) | Size with lodash | Native alternative | Size |
|---|---|---|---|
| `@mui/x-data-grid` | Uses lodash internally | No replacement needed (tree-shakes) | — |
| `formik` | lodash dep | `react-hook-form` | 10KB (no lodash) |
| `react-select` | lodash dep | `@radix-ui/react-select` | No lodash |
| `sequelize` | lodash dep | `drizzle-orm` or `prisma` | No lodash |
| `express-validator` | lodash dep | `zod` + middleware | No lodash |
| `json-server` | lodash dep | `@hono/node-server` + file | No lodash |
| `async` (caolan) | lodash-like | Native `Promise.all/allSettled/race` | 0KB |
| `yargs` | Uses lodash internally | `commander` or `citty` | No lodash |
| `inquirer` | lodash dep | `@clack/prompts` | No lodash |
| `gulp` | lodash dep | Native `node:fs` + scripts | No lodash |
| `request` (deprecated) | lodash dep | `fetch()` | 0KB |

---

## 📦 Packages that pull in `moment`

| Package (uses moment) | Native alternative | Benefit |
|---|---|---|
| `react-datepicker` (old) | `react-day-picker` | date-fns or Temporal |
| `fullcalendar` (v4) | `fullcalendar` v6 | Uses native Date/Temporal |
| `antd` DatePicker (v4) | `antd` v5 + dayjs adapter | -300KB |
| `chart.js` (with time axis) | chart.js + `chartjs-adapter-date-fns` | -300KB |
| `react-big-calendar` | Same lib + `luxon`/`dayjs` localizer | -300KB |
| `graphql-scalars` (DateTime) | Custom scalar with Temporal | -300KB |
| `cron-parser` | `croner` | No moment dep |
| `rrule` (recurrence) | `rrule` v2.8+ | Dropped moment |

---

## 📦 Packages that pull in `axios`

| Package (uses axios) | Native alternative | Benefit |
|---|---|---|
| `@nestjs/axios` | `@nestjs/common` HttpModule with fetch | -30KB |
| `@octokit/rest` | `@octokit/rest` v20+ | Uses fetch internally |
| `firebase/auth` (old) | `firebase` v10+ | Uses fetch |
| `stripe` (old versions) | `stripe` v13+ | Uses fetch |
| `@sendgrid/mail` | `@sendgrid/mail` v8+ | Uses fetch |
| `openai` (old) | `openai` v4+ | Uses fetch |
| `@apollo/client` | `@apollo/client` v3.8+ | Uses fetch |
| `swr` / `react-query` | Same libs — they use YOUR fetcher | Pass `fetch` directly |

---

## 📦 Packages that pull in `uuid`

| Package (uses uuid) | Fix |
|---|---|
| `typeorm` | Uses uuid internally — can't avoid, but your code can use `crypto.randomUUID()` |
| `prisma` | Generates UUIDs via `@default(uuid())` — DB-side, no JS dep needed |
| `express-session` | Pass custom `genid: () => crypto.randomUUID()` |
| `multer` | Uses uuid for filenames — fork or configure custom naming |
| `socket.io` | Internal — no action needed |

---

## 🔄 Upgrade paths (same API, no lodash/moment/axios)

| Old stack | New stack | What you lose |
|---|---|---|
| `express` + `body-parser` + `cors` | `hono` | Nothing (same patterns, 10x smaller) |
| `axios` + `axios-retry` | `fetch()` + `retry` util (5 lines) | Nothing |
| `moment` + `moment-timezone` | `Temporal` (Node 26) | Nothing (better API) |
| `lodash` (full) | Native + `remeda` (tree-shakeable) | Nothing |
| `request` + `request-promise` | `fetch()` | Nothing (request is deprecated) |
| `bluebird` | Native `Promise` | Nothing (V8 is fast now) |
| `async` (waterfall/series) | `async/await` | Nothing |
| `underscore` | Native methods | Nothing |
| `chalk` | `picocolors` (no deps, 6x smaller) | Nothing |
| `dotenv` | `--env-file` flag (Node 20+) | Nothing |

---

## 📊 Impact estimation

For a typical enterprise monorepo with 10 services:

| Action | Savings | Effort |
|---|---|---|
| Replace `uuid` → `crypto.randomUUID()` | 90KB total | 1 hour |
| Replace `axios` → `fetch()` | 300KB total | 1 day |
| Upgrade packages that dropped lodash | 700KB total | 2 hours (version bump) |
| Replace `moment` → Temporal (Node 26) | 3MB total | 1 week |
| Replace `lodash` → native methods | 700KB total | 2 weeks (gradual) |
| **Total** | **~5MB** | **~3 weeks** |

---

## 🔍 How to find level 2 deps in your project

```bash
# Which of your deps pull in lodash?
npm ls lodash 2>/dev/null | grep -v deduped

# Which pull in moment?
npm ls moment 2>/dev/null | grep -v deduped

# Full transitive tree size
npx cost-of-modules
```

---

*This list should be updated as packages release new versions that drop legacy deps.*
