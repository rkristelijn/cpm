CXX      = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -O2
BINARY   = cpm
SRCS     = src/main.cpp src/commands.cpp src/checks.cpp src/ui.cpp src/toml.cpp src/runner.cpp src/setup.cpp src/scan.cpp

.DEFAULT_GOAL := help

.PHONY: all build clean install help test test-unit e2e smoke

build: $(BINARY) ## Build cpm

$(BINARY): $(SRCS) src/toml.h src/runner.h src/setup.h src/scan.h src/commands.h src/checks.h src/ui.h
	$(CXX) $(CXXFLAGS) -o $@ $(SRCS)

clean: ## Remove build artifacts
	rm -f $(BINARY) build/test_*

install: build ## Install to /usr/local/bin
	cp $(BINARY) /usr/local/bin/$(BINARY)
	@echo "Installed cpm to /usr/local/bin/cpm"

test: build test-unit e2e ## Run all tests

test-unit: ## Run unit tests
	@mkdir -p build
	$(CXX) $(CXXFLAGS) -I vendor -o build/test_toml src/toml_test.cpp src/toml.cpp
	./build/test_toml

e2e: build ## Run end-to-end tests
	bash scripts/test/run-e2e.sh ./$(BINARY)

smoke: build ## Run smoke test (quick sanity check)
	bash scripts/smoke-test.sh ./$(BINARY)

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
