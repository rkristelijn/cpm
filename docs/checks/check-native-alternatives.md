# check-native-alternatives

`checks/javascript/check-native-alternatives.sh`

Detects usage of library functions (lodash, moment, axios, uuid) that have native JavaScript/Node.js alternatives.

## Usage

```bash
# Detect only
bash checks/javascript/check-native-alternatives.sh .

# Auto-fix safe patterns
bash checks/javascript/check-native-alternatives.sh . --fix
```

## What it detects

### Auto-fixable (safe 1:1 replacements)

| Library call | Native alternative |
|---|---|
| `_.isArray()` | `Array.isArray()` |
| `_.isNaN()` | `Number.isNaN()` |
| `_.isFinite()` | `Number.isFinite()` |
| `_.isInteger()` | `Number.isInteger()` |
| `_.keys()` | `Object.keys()` |
| `_.values()` | `Object.values()` |
| `_.entries()` | `Object.entries()` |
| `_.fromPairs()` | `Object.fromEntries()` |
| `_.assign()` | `Object.assign()` |
| `_.flatten()` | `array.flat()` |
| `_.includes()` | `array.includes()` |
| `_.padStart()` | `string.padStart()` |
| `_.padEnd()` | `string.padEnd()` |
| `_.trim()` | `string.trim()` |
| `_.repeat()` | `string.repeat()` |
| `_.startsWith()` | `string.startsWith()` |
| `_.endsWith()` | `string.endsWith()` |

### Detect-only (manual review needed)

| Library call | Native alternative |
|---|---|
| `_.get()` | Optional chaining `?.` |
| `_.cloneDeep()` | `structuredClone()` |
| `_.uniq()` | `[...new Set(array)]` |
| `_.groupBy()` | `Object.groupBy()` (ES2024) |
| `_.sortBy()` | `array.toSorted()` |
| `_.find/filter/map/reduce/some/every()` | Native array methods |
| `moment()` | `Intl.DateTimeFormat` or Temporal API |
| `.fromNow()` | `Intl.RelativeTimeFormat` |
| `axios` | Native `fetch()` |
| `node-fetch` | Native `fetch()` (Node 18+) |
| `uuid` | `crypto.randomUUID()` |
| `query-string` | `URLSearchParams` |

## Severity

warning

## Auto-fix

Run with `--fix` to apply safe replacements. Complex patterns require manual refactoring.

## References

- Source: `checks/javascript/check-native-alternatives.sh`
- [You Don't Need Lodash](https://youmightnotneed.com/lodash)
- [You Don't Need Moment](https://github.com/nicedoc/you-dont-need-momentjs)
