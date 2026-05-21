# cpm clean

Remove build artifacts.

## Usage

```bash
cpm clean
```

## What it removes

- `make clean` target (if exists)
- CMake build directory
- `.tmp/` (cpm temp files)
- Coverage data (`.gcda`, `.gcno`)
