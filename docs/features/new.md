# cpm new

Scaffold new projects, test files, or modules.

## Usage

```bash
cpm new my-project       # create a new project directory
cpm new test parser      # add src/parser_test.cpp
cpm new module logger    # add src/logger.cpp + src/logger.hpp
```

## New project

```bash
$ cpm new code-cpp-vulnerability-scan
  ✓ created cpm.toml
  ✓ created src/main.cpp
```

Creates:

- Directory with the project name
- `cpm.toml` (via `cpm init`)
- `src/main.cpp` with hello world

**Naming convention**: `<domain>-<flavor>-<intent>-<method>`

## New test

```bash
$ cpm new test parser
  ✓ created src/parser_test.cpp
```

Creates a minimal test file in `src/` with the `_test.cpp` suffix.

## New module

```bash
$ cpm new module logger
  ✓ created src/logger.cpp
  ✓ created src/logger.hpp
```

Creates a `.cpp` + `.hpp` pair. The header includes a pragma once guard and empty class. The source includes the header.

## Notes

- Won't overwrite existing files
- Creates `src/` directory if missing
- Generated code is minimal — just enough to compile
