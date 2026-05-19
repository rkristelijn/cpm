CXX      = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -O2
BINARY   = cpm
BUILD    = build

# Source files
SRCS     = src/main.cpp src/commands.cpp src/cmd_ops.cpp src/checks.cpp src/ui.cpp src/toml.cpp src/runner.cpp src/setup.cpp src/scan.cpp src/scan_checks.cpp src/io/drawio.cpp
OBJS     = $(patsubst src/%.cpp,$(BUILD)/%.o,$(SRCS))

# Test files
TEST_TOML_SRCS   = src/toml_test.cpp src/toml.cpp
TEST_CHECKS_SRCS = src/checks_test.cpp src/io/filesystem.cpp

.DEFAULT_GOAL := help

.PHONY: all build clean install help test test-unit test-fast e2e smoke version bump package pr pr-create pr-merge pr-ready

##@ Build

build: $(BINARY) ## Build cpm

$(BINARY): $(SRCS) $(wildcard src/*.h src/**/*.h)
	$(CXX) $(CXXFLAGS) -I src -o $@ $(SRCS)

##@ Test (tiered: fast < unit < e2e < all)

test: build test-lint test-unit e2e ## Run all tests (lint + unit + e2e)

test-lint: ## Enforce test architecture (ADR-130) — runs before tests
	@bash checks/universal/quality/check-test-architecture.sh || \
		(echo ""; echo "  ⚠ Test architecture violations — fix before running tests"; echo "  @see docs/adrs/adr-130-test-architecture.md"; exit 1)

test-fast: $(BUILD)/test_toml ## Run fastest tests only (<2s)
	./$(BUILD)/test_toml

test-unit: $(BUILD)/test_toml $(BUILD)/test_checks ## Run unit tests
	./$(BUILD)/test_toml
	./$(BUILD)/test_checks

e2e: build ## Run end-to-end tests
	bash scripts/test/run-e2e.sh ./$(BINARY)

# Compiled test binaries (only rebuild when sources change)
$(BUILD)/test_toml: src/toml_test.cpp src/toml.cpp src/toml.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I vendor -o $@ src/toml_test.cpp src/toml.cpp

$(BUILD)/test_checks: src/checks_test.cpp src/io/filesystem.cpp $(wildcard src/checks/*.cpp src/checks/*.h) | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -o $@ src/checks_test.cpp src/io/filesystem.cpp

$(BUILD):
	@mkdir -p $(BUILD)

##@ Quality

smoke: build ## Run smoke test (quick sanity check)
	bash scripts/smoke-test.sh ./$(BINARY)

coverage: ## Build with coverage and report
	@mkdir -p .tmp/cov
	$(CXX) $(CXXFLAGS) --coverage -I vendor -o .tmp/cov/test_toml src/toml_test.cpp src/toml.cpp
	cd .tmp/cov && ./test_toml
	$(CXX) $(CXXFLAGS) --coverage -I src -o .tmp/cov/test_checks src/checks_test.cpp src/io/filesystem.cpp
	cd .tmp/cov && ./test_checks
	@echo ""
	@echo "Coverage (src/ only):"
	@cd .tmp/cov && gcov *.gcda 2>/dev/null | grep -B1 "^Lines" | grep -A1 "^File '.*src/" | \
		grep "Lines" | sed 's/Lines executed:/  /' | sort -t'%' -k1 -n
	@echo ""
	@cd .tmp/cov && gcov *.gcda 2>/dev/null | grep -A1 "^File '.*src/" | grep "Lines" | \
		awk -F'[:%]' '{pct+=$$2; n++} END {printf "  Total: %.1f%% (%d files)\n", pct/n, n}'
	@rm -f .tmp/cov/*.gcda .tmp/cov/*.gcno .tmp/cov/*.gcov .tmp/cov/test_*

clean: ## Remove build artifacts
	rm -f $(BINARY) $(BUILD)/test_*

install: build ## Install to /usr/local/bin
	cp $(BINARY) /usr/local/bin/$(BINARY)
	@echo "Installed cpm to /usr/local/bin/cpm"

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

wait: ## Wait for pipeline to complete (polls every 15s)
t@bash scripts/gh/wait-pipeline.sh

status: ## Show CI pipeline status for current branch
	@bash scripts/gh/pr-status.sh

pipeline: ## Show latest pipeline run status
	@bash scripts/gh/pipeline-status.sh

feedback: ## Download CodeRabbit review feedback
	@bash scripts/gh/pr-feedback.sh

resolve: ## Interactive: resolve PR review threads
	@bash scripts/gh/pr-resolve.sh

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
