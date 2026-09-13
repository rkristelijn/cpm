# Code Review Questions

> A reusable checklist of the questions a good reviewer asks. Feed this to an AI
> review (or use it yourself) to get a consistent, evidence-based review instead
> of a vibe check.
>
> **How to use:** Point the reviewer at a diff/branch and this file. Ask it to
> answer each applicable question with a verdict (pass / concern / blocker) and
> **cite evidence** (file:line, test output, command result). Skip questions
> that don't apply — not every change touches every axis. A "pass" without cited
> evidence is not a pass.

## Reviewer's stance (tone)

- **Data first, opinion later.** Cite the line, the test, the command output.
  "This looks off" is a question, not a finding.
- **Attack the code, respect the author.** No blame, no praise-theatre.
- **Distinguish blocker / concern / nit.** Don't drown a real blocker in nits.
- **"Functional, not theatre."** Does it actually work, or does it just look
  like it works?
- **Silence on an axis means "not checked", not "fine".** Say what you did not
  verify.

---

## 1. Scope & intent (does this change belong?)

1. Does the change match the stated intent (issue / ticket / PR description)?
2. Is there **anything in the diff not explained by the intent**? (scope creep)
3. Could this be **smaller**? Can any file/hunk be split into its own change?
4. Are unrelated reformattings / renames mixed in with logic changes?
5. Does it solve the actual problem, or a symptom of it?
6. Is this the **right layer** for the change (UI vs domain vs data)?
7. Does it duplicate something that already exists in the codebase?
8. Was a simpler approach considered and rejected? Is that reasoning recorded?
9. Does the change belong in this repo/module at all?
10. Is anything added "just in case" (speculative generality)?

## 2. Correctness (does it work?)

11. Does it do what it claims for the **happy path**?
12. What are the **boundary values** (0, 1, n, n+1, empty, max)?
13. How does it behave on **empty / null / undefined** input?
14. Off-by-one: loops, slices, ranges, indices — checked?
15. Are all **branches reachable** and correct, including the `else` nobody writes?
16. Are error paths handled, or only the success path?
17. Are return values / error codes actually checked by callers?
18. Any **race conditions** or ordering assumptions in async/concurrent code?
19. Any **reentrancy** issues (callback fires while state is mid-update)?
20. Are there integer overflow / precision / rounding concerns?
21. Does it handle the **resource-not-present** case (file, node, key missing)?
22. Are there states the code can reach that it doesn't handle?
23. Does undo/redo / back / cancel restore the expected state?
24. Is the change **idempotent** where it should be (re-run, double-click, retry)?

## 3. Tests (how do we know it works?)

25. Is there a test that **fails without the change and passes with it**?
26. Do tests assert **specific outcomes**, or just `assert true` / "no throw"?
27. Are boundary and error cases tested, not only the happy path?
28. Is the **pure logic** testable without the DOM / network / filesystem?
29. Are tests deterministic (no time, no random, no order dependence)?
30. Do test names describe the behavior, not the method?
31. Is there a test proving the **bug can't come back** (regression test)?
32. Are mocks asserting real behavior, or masking it?
33. What is **not** covered? Is that gap acknowledged?
34. Did the author actually **run** the tests? Is the output cited?
35. Does the build/typecheck pass clean (no new warnings)?

## 4. Readability & clarity (can the next person maintain it?)

36. Can you understand each function without reading its body twice?
37. Are names accurate (does `getX` have side effects; is `isY` a boolean)?
38. Is control flow flat, or nested 4+ deep?
39. Are there magic numbers / strings that should be named constants?
40. Do comments explain **why**, not restate **what**?
41. Are there stale / misleading comments left from an earlier version?
42. Is there commented-out code or debug logging left in?
43. Would a smaller function or an early return make it clearer?
44. Is the diff free of AI-slop tells (promotional headers, "comprehensive",
    "robust", feature-list comments)?
45. Is formatting consistent with the surrounding file (not a personal style)?

## 5. Complexity & design (is it as simple as it can be?)

46. Does the change **add complexity** the feature doesn't require?
47. Is there a new abstraction with only **one** caller?
48. Is state kept in the fewest places possible (single source of truth)?
49. Is coupling introduced across module/layer boundaries?
50. Is the cyclomatic complexity of any function creeping up?
51. Could data flow one direction instead of two?
52. Are side effects isolated, or scattered through pure-looking functions?
53. Is the public surface (exports/API) as small as possible?
54. Does it follow the existing pattern in this codebase, or invent a new one?
55. If it invents a new pattern, is the old one demonstrably inadequate?

## 6. Regressions & blast radius (what could it break?)

56. What existing behavior touches this code path?
57. What callers depend on the changed function's old contract?
58. Does it change a **serialized format**, wire protocol, or persisted state?
59. Does it change public API / CLI flags / config keys (breaking change)?
60. Are defaults changed in a way that surprises existing users?
61. Could it affect performance on the hot path (added work per keystroke/frame/request)?
62. Does it hold locks / resources longer than before?
63. Are there feature flags / migrations needed to roll out safely?
64. Is it reversible? Can it be reverted cleanly if it misbehaves?
65. Does it affect other platforms/browsers/OSes than the one tested?

## 7. Security & data (can it be abused or leak?)

66. Is all external input (user, file, network, env) treated as untrusted?
67. Any injection surface (SQL, shell, HTML/XSS, path traversal, template)?
68. Is output encoded/escaped for its sink?
69. Are secrets kept out of code, logs, and error messages?
70. Are authz/authn checks on the right side (server, not just UI)?
71. Does it log PII or sensitive data?
72. Are dependencies pinned, reputable, and free of typosquat risk?
73. Does it widen permissions, CORS, or trust boundaries?
74. Are error messages informative to users but not leaky to attackers?
75. Is cryptographic material handled correctly (no home-rolled crypto)?

## 8. Accessibility & UX (for user-facing change)

76. Is every interactive element keyboard-operable?
77. Are ARIA roles / labels / states correct and updated on state change?
78. Is there a **visible affordance** for any hidden/collapsed/disabled state?
79. Does focus land somewhere sensible after the action?
80. Are colors/contrast sufficient; is state conveyed by more than color?
81. Does it work at narrow widths / zoom / different themes?
82. Are error/empty/loading states designed, not just the full state?
83. Is the change discoverable, or does it rely on hidden knowledge?
84. Is copy/localization handled (all languages, not just one)?
85. Does it respect reduced-motion / other user preferences?

## 9. Errors, logging & observability

86. Are errors handled at the right level (not swallowed, not over-caught)?
87. Do error messages tell the user what to do next?
88. Is logging at the right level (no debug spam, no silent failures)?
89. Are failures observable (metric, log, surfaced to UI) rather than silent?
90. On partial failure, is state left consistent (no half-applied change)?

## 10. Docs, dependencies & housekeeping

91. Are user-facing docs / README / changelog updated if behavior changed?
92. Are design notes / ADRs updated if a decision changed?
93. Are new dependencies justified, licensed compatibly, and minimal?
94. Are TODOs actionable and tracked, not "TODO: fix this"?
95. Are temporary / scratch files removed from the diff?
96. Is the commit history clean and the message explanatory (why, not what)?
97. Does the change leave the tree in a **known-good, buildable** state?

## 11. The meta-questions (step back)

98. If this ships and breaks at 2am, is there enough here to debug it?
99. Will you understand this diff in six months without the author?
100. What is the **one thing most likely to be wrong** — and did you check it?

---

## Verdict template

```text
Scope:        pass | concern | blocker  — <evidence>
Correctness:  pass | concern | blocker  — <evidence>
Tests:        pass | concern | blocker  — <evidence>
Readability:  pass | concern | blocker  — <evidence>
Complexity:   pass | concern | blocker  — <evidence>
Regressions:  pass | concern | blocker  — <evidence>
Security:     pass | concern | blocker  — <evidence / n/a>
A11y/UX:      pass | concern | blocker  — <evidence / n/a>
Errors/Obs:   pass | concern | blocker  — <evidence>
Docs/Deps:    pass | concern | blocker  — <evidence>

Blockers:   <list, or none>
Concerns:   <list>
Nits:       <list>
Not checked: <axes you did not verify, and why>
```
