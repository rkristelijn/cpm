---
title: Frontend framework misuse detection — 75 rules across 50 frameworks
type: feat
created: 2026-08-30T14:10:00+02:00
labels: [feat, rules, frameworks, quality]
priority: high
---

## Concept

Detect when developers "fight the framework" — using a tool but ignoring how it's meant to be used. Examples:
- MUI project with inline `style={{}}` instead of `sx` prop
- TanStack Query project with `useEffect + fetch` instead of `useQuery`
- Redux with deprecated `createStore` instead of RTK `configureStore`
- Next.js App Router with `getServerSideProps` (Pages Router pattern)

These aren't security issues — they're correctness and maintainability issues that cause bugs, poor performance, and make the codebase harder to work with.

## Already done (this session)

9 rules in `rules/ui-frameworks/`:
- MUI: UI-MIS-010..015 (inline style, hardcoded colors/spacing, Typography, raw HTML, deprecated makeStyles)
- Tailwind: UI-MIS-020..022 (inline style, custom CSS override, arbitrary values)

## High priority — write next (~25 rules)

### State management (10 rules)
| ID | Framework | Pattern | Severity |
|----|-----------|---------|----------|
| STATE-MIS-010 | Redux | deprecated createStore import | warning |
| STATE-MIS-011 | Redux | deprecated extraReducers object syntax | warning |
| STATE-MIS-013 | Redux | connect() HOC instead of hooks | info |
| STATE-MIS-020 | Zustand | subscribing to entire store (no selector) | warning |
| STATE-MIS-040 | Pinia/Vuex | Vuex import in Vue 3 project | warning |
| STATE-MIS-055 | XState | deprecated Machine() import | info |
| STATE-MIS-060 | Recoil | unmaintained library | info |
| STATE-MIS-065 | Angular | BehaviorSubject where signals work | info |
| FORM-MIS-020 | Formik | maintenance mode warning | info |
| ANIM-MIS-010 | Motion | deprecated framer-motion package name | warning |

### Meta-framework misuse (10 rules)
| ID | Framework | Pattern | Severity |
|----|-----------|---------|----------|
| NJS-MIS-022 | Next.js | getServerSideProps in App Router | warning |
| NJS-MIS-023 | Next.js | deprecated next/legacy/image | warning |
| NX-MIS-010 | Nuxt 3 | $fetch in setup (double fetch) | warning |
| NX-MIS-012 | Nuxt 3 | Vuex instead of Pinia | warning |
| SK-MIS-010 | SvelteKit | onMount+fetch instead of load() | info |
| RMX-MIS-011 | Remix | deprecated @remix-run imports | info |
| SOLID-MIS-010 | SolidJS | destructured props breaks reactivity | error |
| SVE-MIS-010 | Svelte 5 | deprecated $: reactive declarations | info |
| QWIK-MIS-010 | Qwik | useEffect instead of useTask$ | warning |
| VUE-MIS-012 | Vue 3 | removed filter syntax | error |

### Data fetching (5 rules)
| ID | Framework | Pattern | Severity |
|----|-----------|---------|----------|
| DATA-MIS-010 | TanStack Query | useEffect+fetch instead of useQuery | warning |
| DATA-MIS-011 | TanStack Query | deprecated onSuccess/onError | warning |
| DATA-MIS-012 | TanStack Query | v4 array query key syntax | info |
| DATA-MIS-030 | Apollo | deprecated onCompleted/onError | info |
| DATA-MIS-040 | tRPC | raw fetch to tRPC endpoint | warning |

## Medium priority (~25 rules)

### Component libraries
- Ant Design: v4 deprecated imports, Form.create(), inline styles (3 rules)
- Chakra UI: v3 deprecated props, inline style (2 rules)
- Bootstrap 5: data-toggle without bs prefix, jQuery methods, inline override (3 rules)
- Vuetify 3: renamed components, inline style (2 rules)
- shadcn/ui: npm import anti-pattern (1 rule)
- Mantine: deep imports, inline style (2 rules)
- HeroUI: NextUI rename (1 rule)
- DaisyUI: inline style on component class (1 rule)

### Core frameworks
- React: class components, deprecated lifecycle, PropTypes in TS (3 rules)
- Vue 3: Options API, deprecated .sync, removed filters (3 rules)
- Angular: NgModule deprecated, manual subscribe (2 rules)
- Svelte 5: deprecated export let (1 rule)

### Animation
- GSAP: deprecated TweenMax/TweenLite (1 rule)
- React Spring: deprecated import path (1 rule)

## Low priority (~15 rules)

- Tailwind v4 migration (2 rules)
- Radix UI patterns (2 rules)
- Open Props (1 rule)
- Element Plus (1 rule)
- PrimeVue (1 rule)
- Base UI (1 rule)
- TanStack Form (1 rule)
- SWR (2 rules)
- Astro client:load overuse (1 rule)
- Headless UI v2 (1 rule)
- Qwik/Solid niche patterns (1 rule)

## Detection strategy

All rules use `content_contains` for fast pre-filtering:
- Only scan files that actually import the framework
- No performance impact on projects that don't use the framework
- Example: `content_contains: "@mui"` → rule only fires on MUI projects

## Effort estimate

- High priority: ~3 hours (25 rules)
- Medium priority: ~3 hours (25 rules)
- Low priority: ~2 hours (15 rules)
- Total: ~8 hours for ~65 rules (75 planned, some too complex for regex)

## Definition of done

- [ ] Rules created and pass smoke test
- [ ] At least 1 test fixture per framework category in cpm-eval
- [ ] No false positives on cpm's own codebase
- [ ] Benchmark re-run to verify noise level acceptable
