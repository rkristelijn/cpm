CXX      = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -O2
BINARY   = cpm
SRCS     = src/main.cpp src/commands.cpp src/checks.cpp src/ui.cpp src/toml.cpp src/runner.cpp src/setup.cpp src/scan.cpp src/io/drawio.cpp

.DEFAULT_GOAL := help

.PHONY: all build clean install help test test-unit e2e smoke version bump package pr pr-create pr-merge pr-ready

build: $(BINARY) ## Build cpm

$(BINARY): $(SRCS) src/toml.h src/runner.h src/setup.h src/scan.h src/commands.h src/checks.h src/ui.h src/io/drawio.h
	$(CXX) $(CXXFLAGS) -I src -o $@ $(SRCS)

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
	$(CXX) $(CXXFLAGS) -I src -o build/test_checks src/checks_test.cpp src/io/filesystem.cpp
	./build/test_checks

e2e: build ## Run end-to-end tests
	bash scripts/test/run-e2e.sh ./$(BINARY)

coverage: ## Build with coverage and report
	@mkdir -p build
	$(CXX) $(CXXFLAGS) --coverage -I vendor -o build/test_toml src/toml_test.cpp src/toml.cpp
	./build/test_toml
	$(CXX) $(CXXFLAGS) --coverage -I src -o build/test_checks src/checks_test.cpp src/io/filesystem.cpp
	./build/test_checks
	@echo ""
	@echo "Coverage (src/ only):"
	@gcov build/*.gcda 2>/dev/null | grep -B1 "^Lines" | grep -A1 "^File 'src/" | \
		grep "Lines" | sed 's/Lines executed:/  /' | sort -t'%' -k1 -n
	@echo ""
	@gcov build/*.gcda 2>/dev/null | grep -A1 "^File 'src/" | grep "Lines" | \
		awk -F'[:%]' '{pct+=$$2; n++} END {printf "  Total: %.1f%% (%d files)\n", pct/n, n}'

smoke: build ## Run smoke test (quick sanity check)
	bash scripts/smoke-test.sh ./$(BINARY)

##@ Release

version: ## Show current version
	@bash scripts/release.sh version

bump: ## Show next version (from conventional commits)
	@bash scripts/release.sh bump

package: build ## Create local tarball
	@mkdir -p release
	@tar czf release/cpm-$$(uname -s | tr A-Z a-z)-$$(uname -m).tar.gz cpm
	@echo "Created: release/cpm-$$(uname -s | tr A-Z a-z)-$$(uname -m).tar.gz"

##@ GitHub

pr: pr-create ## Alias for pr-create

pr-create: ## Create PR from current branch to main
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	TITLE=$$(git log -1 --pretty=%B | head -1); \
	BODY=$$(git log --pretty=format:"- %s" main..$$BRANCH | head -10); \
	gh pr create --draft --title "$$TITLE" --body "## Changes$$(printf '\n')\n$$BODY$$(printf '\n')\n\n## Testing\n\n- \`make check\` passes locally" --base main --head $$BRANCH

pr-ready: ## Mark draft PR as ready for review
	@gh pr ready

pr-merge: ## Merge current PR to main
	@gh pr merge --delete-branch --admin

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
