# Adapter Pattern — When to Wrap External Libraries

## Rule of Thumb

| Question | Yes → Wrap | No → Don't wrap |
|----------|-----------|-----------------|
| Can you swap the lib in <1 day? | ✅ | |
| Does the lib render UI components? | | ❌ |
| Do you use only 3-5 functions from it? | ✅ | |
| Does your component structure depend on it? | | ❌ |
| Is the lib's API your code's public contract? | | ❌ |
| Is the lib an implementation detail? | ✅ | |

## ✅ Wrap These (Infrastructure)

Your code calls their API. The lib is invisible to users.

```text
src/lib/time.ts      → wraps dayjs/date-fns/luxon
src/lib/api.ts       → wraps axios/ky/fetch
src/lib/db.ts        → wraps prisma/drizzle/mongoose
src/lib/logger.ts    → wraps pino/winston
src/lib/storage.ts   → wraps localStorage/localforage/idb
src/lib/email.ts     → wraps sendgrid/resend/nodemailer
src/lib/payment.ts   → wraps stripe/paypal
src/lib/analytics.ts → wraps mixpanel/posthog/amplitude
src/lib/auth.ts      → wraps jwt/bcrypt helpers
src/lib/cache.ts     → wraps redis/ioredis
src/lib/notify.ts    → wraps sonner/react-hot-toast
src/lib/monitoring.ts→ wraps sentry/datadog
```

**Benefits:**

- Swap lib in 1 file, not 30
- Know exactly which functions you use
- Mock the adapter in tests, not the lib
- Smaller bundle (re-export only what you need)

## ❌ Don't Wrap These (UI/Framework)

Your code IS the lib. Wrapping adds indirection without value.

- **MUI components** — `<Button>`, `<TextField>`, `<Dialog>` — you can't abstract "render a button"
- **TanStack Query** — `useQuery`, `useMutation` — the hook IS your abstraction
- **Next.js** — `<Link>`, `<Image>`, `useRouter` — the framework IS your adapter
- **React** — `useState`, `useEffect`, `useRef` — this is the language you write in

**Why not:** Swapping these means rewriting your entire UI. A wrapper wouldn't help — you'd still need to change every component.

## 🟡 Grey Area (Wrap the Config, Not the Component)

Some libs have both "use directly" and "configure centrally" aspects:

| Lib | Don't wrap | DO centralize |
|-----|-----------|---------------|
| MUI | `<Button>` usage | Theme tokens (colors, spacing, typography) |
| TanStack Query | `useQuery()` hooks | `queryFn` fetchers → service layer |
| Next.js | `<Link>`, `<Image>` | `next.config.ts` settings, middleware |
| Zod | Schema definitions | Shared base schemas, custom error maps |

## Example: Good Adapter

```typescript
// src/lib/time.ts — wraps dayjs
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
dayjs.extend(relativeTime);

export function formatDate(date: string | Date): string {
  return dayjs(date).format('DD MMM YYYY');
}

export function fromNow(date: string | Date): string {
  return dayjs(date).fromNow();
}

export function isOlderThan(date: string | Date, days: number): boolean {
  return dayjs().diff(dayjs(date), 'day') > days;
}
```

Now if you switch to `date-fns` or `Temporal`, you change this one file.
All 30 components that use `formatDate()` keep working.

## Example: Bad Wrapper (Don't Do This)

```typescript
// ❌ src/components/MyButton.tsx — pointless wrapper
import { Button, ButtonProps } from '@mui/material';

export function MyButton(props: ButtonProps) {
  return <Button {...props} />;  // adds nothing
}
```

This is not an adapter. It's a passthrough that:

- Adds a file to maintain
- Hides where the real component is
- Makes IDE "go to definition" useless
- Will diverge from MUI's API over time

## Threshold

- **3+ files** importing the same lib directly → create adapter
- **1-2 files** → fine to import directly (not worth the abstraction yet)
- **Test/config files** → excluded (they're allowed to import directly)
