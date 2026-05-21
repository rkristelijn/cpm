# cpm test

Run tests using the detected test framework.

## Usage

```bash
cpm test
```

## Detection order

1. `Makefile` with `test` target → `make test`
2. `CMakeLists.txt` with CTest → `cd build && ctest --output-on-failure`
3. `Makefile` with `test-unit` target → `make test-unit`
4. `Makefile` with `check` target → `make check`
