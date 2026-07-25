# ADR-155: "You Don't Need" Dependency Detection (JS, Python, C++)

## Status

Accepted (implemented 2026-07-19)

## Context

The npm/pip/conan ecosystem incentivizes adding packages for trivial functionality. This creates:

- Supply chain attack surface (each dep is a trust boundary)
- Bundle bloat (lodash for one function = 72kb)
- Maintenance burden (upgrades, breaking changes, deprecations)
- "Works on my machine" fragility (native module compilation)

Meanwhile, Node.js 18-22, ES2024, Python 3.9+, and C++17/20 have absorbed most functionality that previously required third-party packages.

## Decision

Implement "You Don't Need" checks for three languages:

### JavaScript/Node.js (`check-you-dont-need.sh`)

**Dead projects (error):** grunt, gulp, bower, request, moment, jQuery, enzyme, karma, node-sass

**Native replacements (warning):**

| Package | Native Alternative | Since |
|---------|-------------------|-------|
| node-fetch | global fetch() | Node 18 |
| uuid | crypto.randomUUID() | Node 19 |
| chalk | util.styleText() | Node 21 |
| rimraf | fs.rm({ recursive: true }) | Node 14 |
| mkdirp | fs.mkdir({ recursive: true }) | Node 10 |
| glob | fs.glob() | Node 22 |
| dotenv | --env-file flag | Node 20.6 |
| strip-ansi | util.stripVTControlCharacters() | Node 16 |

**Lodash per-function detection:**

- _.get → optional chaining (?.)
- _.cloneDeep → structuredClone()
- _.uniq → [...new Set(arr)]
- _.flatten → Array.flat()
- _.map/filter/find → native array methods
- Barrel import detection (72kb for one function)

**Philosophy:** If you use 1-3 functions from lodash, copy them. No dep, no supply chain risk, no bundle bloat. Only at 10+ functions is lodash-es justified.

### Python (`checks/python/check-you-dont-need.sh`)

- nose → pytest, pycrypto → cryptography, six → remove (Python 2 is dead)
- os.path → pathlib, subprocess.call → subprocess.run
- %-format → f-strings, typing.Dict → dict (3.9+), Optional → X | None (3.10+)
- mock → unittest.mock, simplejson → json stdlib

### C++ (`checks/universal/quality/check-cpp-you-dont-need.sh`)

- 10 Boost modules now in std (shared_ptr, optional, variant, filesystem, etc)
- Deprecated patterns: auto_ptr, NULL, register, C-style casts
- Modern replacements: constexpr, nullptr, std::format, stoi, string_view

## Alternatives Considered

- **Rely on `npm audit`:** Only flags security issues, not bloat/deprecation
- **Rely on IDE warnings:** Not enforced in CI, developer-specific
- **Blanket "no deps" rule:** Too strict, some deps are genuinely useful

## Consequences

- Projects are leaner (fewer deps = smaller attack surface + faster installs)
- Developers learn native alternatives exist
- CI catches "AI slop" that pulls in deprecated packages
- Each finding links to the native replacement (actionable, not just nagging)
