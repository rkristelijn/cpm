# cpm build

Build the project using the detected build system.

## Usage

```bash
cpm build
```

## Detection order

1. `Makefile` with `build` target → `make build`
2. `CMakeLists.txt` → `cmake -B build && cmake --build build`
3. `Makefile` (default) → `make`

## See also

- `cpm run` — build and run
- `cpm test` — run tests
