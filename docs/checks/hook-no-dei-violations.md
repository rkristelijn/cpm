# hook-no-dei-violations

## What it catches

Non-inclusive language in staged code changes. Flags terms that violate Diversity, Equity & Inclusion (DEI) principles and suggests inclusive alternatives.

## What DEI means

**Diversity, Equity & Inclusion** (DEI) in software engineering means writing code, documentation, and commit messages that don't exclude, marginalize, or reinforce stereotypes about any group. Language in code matters — it's read by diverse teams and persists in version history.

## Why this matters in codebases

The software industry has been actively removing exclusionary terminology:

- **GitHub** (2020): renamed default branch from `master` to `main`
- **Chromium/Google** (2020): removed `blacklist`/`whitelist` from codebase, replaced with `blocklist`/`allowlist`
- **IETF** (RFC 8174, 2021): guidance on inclusive terminology in standards
- **Linux kernel** (2020): adopted inclusive terminology guidelines
- **Twitter, Apple, Microsoft**: all undertook similar language reviews

This isn't just about feelings — inclusive language reduces cognitive friction for team members and makes codebases more welcoming to contributors from all backgrounds.

## This is a WARNING check

This check **warns but does not block** commits. Some terms like `normal`, `native`, and `guys` have high false-positive rates in code — they're perfectly valid in many contexts (e.g., `native code`, `normal distribution`, `guys` in informal comments). The warning gives you a chance to reconsider, not a mandate to change.

## Term list

| Pattern | Suggested replacement |
|---------|----------------------|
| `whitelist` | `allowlist` |
| `blacklist` | `denylist` |
| `master/slave` | `primary/secondary` |
| `slave` | `replica/secondary` |
| `whitebox` | `open-box` |
| `blackbox` | `closed-box` |
| `normal` | `default/standard` (when implying a value judgment) |
| `abnormal` | `atypical/unexpected` |
| `sanity check` | `confidence check/validation` |
| `sanity` | `confidence/validity` |
| `sane` | `sensible/reasonable` |
| `crazy` | `unexpected/surprising` |
| `insane` | `unreasonable/extreme` |
| `dummy` | `placeholder/stub/mock` |
| `cripple(s/d)` | `disable/degrade` |
| `lame` | `flawed/weak` |
| `blind spot` | `oversight/gap` |
| `grandfathered` | `legacy/exempt` |
| `manpower` | `workforce/staffing` |
| `man hours` | `person-hours` |
| `man in the middle` | `on-path attack/interceptor` |
| `guys` | `everyone/team/folks` |
| `mankind` | `humanity/humankind` |
| `chairman` | `chair/chairperson` |
| `middleman` | `intermediary/broker` |
| `housekeeping` | `maintenance/cleanup` |
| `native` | `built-in/default` (when not referring to native code/platform) |
| `first class citizen` | `first-class concept/entity` |
| `tribe` | `team/group/squad` |
| `ninja` | `expert/specialist` |
| `rockstar` | `expert/top performer` |
| `guru` | `expert/specialist` |
| `handicapped` | `disabled/with a disability` |
| `wheelchair bound` | `wheelchair user` |
| `retarded` | `delayed/slow` |
| `nuke` | `delete/remove/clear` |
| `segregate(s/d)` | `separate/isolate` |
| `he/she` | `they` |
| `his/her` | `their` |

## Suppress

- **Inline**: add `cpm:ignore dei` comment on the line
- **Per-repo**: add to cpm.toml:

  ```toml
  [hooks.global]
  no-dei-violations = false
  ```

- **Global disable**: `cpm hook --global --disable no-dei-violations`
- **One commit**: `git commit --no-verify`

## How it works

1. Reads from the cached git diff (`$DIFF_CACHE`)
2. Extracts only added lines (`+` lines, not headers)
3. Skips comment lines (`#` and `//`)
4. Skips lines with `cpm:ignore dei`
5. Case-insensitive matching with word boundaries to avoid substring matches
6. Shows the flagged term and suggested replacement
7. Exits 1 if any found (warning, not block)
