---
title: sanitize popen/system calls in scan.cpp and runner.cpp
type: fix
created: 2026-05-19T05:02:29+00:00
labels: [fix, security]
remote:
---

## Problem

`scan.cpp` and `runner.cpp` use `popen()` and `system()` with unsanitized paths. A repo with shell metacharacters in its path (e.g. `; rm -rf /`) could execute arbitrary commands.

## Reproduce

1. Create a directory with shell metacharacters: `mkdir "/tmp/test; echo pwned"`
2. Run `cpm scan /tmp/`
3. Observe command injection via popen

## Expected vs actual

- Expected: paths are escaped or validated before shell execution
- Actual: raw string concatenation into shell commands

## Value

- Quality characteristic: Security

## Acceptance criteria

- [ ] AC1: `scan.cpp` uses `std::filesystem::create_directories()` instead of `system("mkdir -p ...")` → test: test_unit_scan_mkdir
- [ ] AC2: All `popen()` calls escape shell metacharacters in paths → test: test_unit_path_sanitize
- [ ] AC3: Repo paths with spaces, quotes, semicolons don't cause injection → test: test_e2e_scan_special_chars

## Done when

- [ ] Bug fixed (acceptance criteria met)
- [ ] Test reproduces the issue (regression test)
- [ ] No regression (existing tests pass)

## References

- @see src/scan.cpp:819,836,865,984 (popen/system calls)
- @see src/runner.cpp:43,53,158 (system calls)
- @see ADR-129 (unified findings contract — runner architecture)
