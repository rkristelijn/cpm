# cpm eject

Generate standalone build configs so your project works without cpm.

## Usage

```bash
cpm eject
```

## What it generates

| File | Purpose |
|------|---------|
| `.config/.clang-format` | C++ formatting rules |
| `.config/.clang-tidy` | C++ static analysis config |
| `.config/yamllint.yml` | YAML linting rules |
| `.config/rumdl.toml` | Markdown linting rules |
| `.config/Doxyfile` | Documentation generation |
| `Makefile` | Build system (if missing) |
| `CMakeLists.txt` | CMake config (if missing) |

## Behavior

- Only creates files that don't already exist (non-destructive)
- Respects `config-dir` from `cpm.toml` for tool configs
- Generated Makefile includes `build`, `test`, and `clean` targets
- Generated CMakeLists.txt auto-discovers sources and tests

## When to use

- Removing cpm from a project but keeping the build setup
- Sharing configs with team members who don't use cpm
- CI environments where only Make/CMake is available

## Generated Makefile

```makefile
CXX      = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -O2 -I src
BINARY   = my-project
SRCS     = $(wildcard src/*.cpp)

.PHONY: all build clean test

all: build

build: $(BINARY)

$(BINARY): $(SRCS)
	$(CXX) $(CXXFLAGS) -o $@ $(SRCS)

test:
	@find src -name '*_test.cpp' | xargs -I{} $(CXX) $(CXXFLAGS) {} -o test_bin && ./test_bin && rm test_bin

clean:
	rm -f $(BINARY) test_bin
```

## Related

- [config.md](config.md) — cpm.toml settings that drive eject
- [init.md](init.md) — create cpm.toml first
