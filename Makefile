CXX      = g++
VERSION  = $(shell grep '^version = ' cpm.toml | sed 's/.*"\(.*\)".*/\1/')
CXXFLAGS = -Wall -Wextra -std=c++20 -O2 -I src/common -DCPM_VERSION='"$(VERSION)"' $(EXTRA_CXXFLAGS)
BINARY   = cpm
BUILD    = build

# Platform source selection — @see ADR-170
# PLATFORM_CORE = platform abstraction only (executable_path, now_sec, is_symlink...)
# PLATFORM_SRC  = PLATFORM_CORE + the per-OS parallel execution engine (runner_*)
ifeq ($(OS),Windows_NT)
  PLATFORM_CORE = src/common/platform_win32.cpp
  PLATFORM_SRC  = $(PLATFORM_CORE) src/common/runner_win32.cpp
else
  PLATFORM_CORE = src/common/platform_posix.cpp
  PLATFORM_SRC  = $(PLATFORM_CORE) src/common/runner_posix.cpp
endif

# RE2 dependency (Homebrew on macOS, system paths on Linux, vcpkg on Windows)
# Set CPM_NO_RE2=1 to build without rule engine (Windows/embedded)
RE2_PREFIX  ?= $(shell brew --prefix re2 2>/dev/null || echo /usr)
ABSL_PREFIX ?= $(shell brew --prefix abseil 2>/dev/null || echo /usr)
ifndef CPM_NO_RE2
RE2_CFLAGS  = -I$(RE2_PREFIX)/include -I$(ABSL_PREFIX)/include
RE2_LDFLAGS = -L$(RE2_PREFIX)/lib -L$(ABSL_PREFIX)/lib -lre2
RE2_SRCS    = src/rules/rule_engine.cpp
else
RE2_CFLAGS  = -DCPM_NO_RE2
RE2_LDFLAGS =
RE2_SRCS    =
endif

# Source files
SRCS     = src/main.cpp src/commands/commands.cpp src/commands/cmd_ops.cpp src/commands/cmd_sort.cpp src/commands/cmd_docs.cpp src/checks.cpp src/common/ui.cpp src/common/toml.cpp src/common/runner.cpp src/common/setup.cpp src/scan/scan.cpp src/scan/scan_checks.cpp src/scan/scan_classify.cpp src/scan/scan_lang.cpp src/scan/scan_ci.cpp src/scan/scan_universal.cpp src/analysis/tokenizer.cpp src/analysis/dup_symbols.cpp $(PLATFORM_SRC) $(RE2_SRCS)
OBJS     = $(patsubst src/%.cpp,$(BUILD)/%.o,$(SRCS))

# Test files
TEST_TOML_SRCS   = src/toml_test.cpp src/common/toml.cpp
TEST_CHECKS_SRCS = src/checks_test.cpp src/io/filesystem.cpp
TEST_SORT_SRCS   = src/sort_test.cpp src/commands/cmd_sort.cpp

.DEFAULT_GOAL := help

.PHONY: all build clean install help test test-unit test-fast e2e smoke version bump package pr pr-create pr-merge pr-ready

##@ Build

build: $(BINARY) ## Build cpm

$(BINARY): $(SRCS) $(wildcard src/*.h src/**/*.h)
	@rm -f $@
	$(CXX) $(CXXFLAGS) -I src $(RE2_CFLAGS) -o $@ $(SRCS) $(RE2_LDFLAGS)

$(BUILD)/rule-scan: src/rules/cmd_rule_scan.cpp src/rules/rule_engine.cpp src/rules/rule_engine.h src/analysis/tokenizer.cpp src/analysis/tokenizer.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src $(RE2_CFLAGS) -o $@ src/rules/cmd_rule_scan.cpp src/rules/rule_engine.cpp src/analysis/tokenizer.cpp $(RE2_LDFLAGS)

##@ Test (tiered: fast < unit < e2e < all)

test: build test-lint test-unit e2e ## Run all tests (lint + unit + e2e)

test-lint: ## Enforce test architecture (ADR-130) — runs before tests
	@bash checks/universal/quality/check-test-architecture.sh || \
		(echo ""; echo "  ⚠ Test architecture violations — fix before running tests"; echo "  @see docs/adrs/adr-130-test-architecture.md"; exit 1)

test-fast: $(BUILD)/test_toml ## Run fastest tests only (<2s)
	./$(BUILD)/test_toml

test-unit: $(BUILD)/test_toml $(BUILD)/test_checks $(BUILD)/test_version $(BUILD)/test_rules $(BUILD)/test_sort $(BUILD)/test_commands $(BUILD)/test_tokenizer $(BUILD)/test_import_graph $(BUILD)/test_dup_symbols $(BUILD)/test_platform $(BUILD)/test_runner ## Run unit tests
	./$(BUILD)/test_toml
	./$(BUILD)/test_checks
	./$(BUILD)/test_version
	./$(BUILD)/test_rules
	./$(BUILD)/test_sort
	./$(BUILD)/test_commands
	./$(BUILD)/test_tokenizer
	./$(BUILD)/test_import_graph
	./$(BUILD)/test_dup_symbols
	./$(BUILD)/test_platform
	./$(BUILD)/test_runner

e2e: build ## Run end-to-end tests
	bash scripts/test/run-e2e.sh ./$(BINARY)

# Compiled test binaries (only rebuild when sources change)
$(BUILD)/test_toml: src/toml_test.cpp src/common/toml.cpp src/common/toml.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I vendor -o $@ src/toml_test.cpp src/common/toml.cpp

$(BUILD)/test_checks: src/checks_test.cpp src/io/filesystem.cpp $(wildcard src/checks/*.cpp src/checks/*.h) | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -o $@ src/checks_test.cpp src/io/filesystem.cpp

$(BUILD)/test_version: src/version_test.cpp src/common/version.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ src/version_test.cpp

$(BUILD)/test_rules: src/rules_test.cpp src/rules/rule_engine.cpp src/rules/rule_engine.h src/analysis/tokenizer.cpp src/analysis/tokenizer.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor $(RE2_CFLAGS) -o $@ src/rules_test.cpp src/rules/rule_engine.cpp src/analysis/tokenizer.cpp $(RE2_LDFLAGS)

$(BUILD)/test_sort: $(TEST_SORT_SRCS) src/commands/commands.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ $(TEST_SORT_SRCS)

$(BUILD)/test_commands: src/commands/commands_test.cpp src/commands/cmd_docs.cpp src/commands/cmd_sort.cpp src/commands/commands.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ src/commands/commands_test.cpp src/commands/cmd_docs.cpp src/commands/cmd_sort.cpp

$(BUILD)/test_tokenizer: src/analysis/tokenizer_test.cpp src/analysis/tokenizer.cpp src/analysis/tokenizer.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ src/analysis/tokenizer_test.cpp src/analysis/tokenizer.cpp

$(BUILD)/test_import_graph: src/analysis/import_graph_test.cpp src/analysis/import_graph.cpp src/analysis/import_graph.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ src/analysis/import_graph_test.cpp src/analysis/import_graph.cpp

$(BUILD)/test_dup_symbols: src/analysis/dup_symbols_test.cpp src/analysis/dup_symbols.cpp src/analysis/dup_symbols.h src/analysis/tokenizer.cpp src/analysis/tokenizer.h $(PLATFORM_CORE) vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ src/analysis/dup_symbols_test.cpp src/analysis/dup_symbols.cpp src/analysis/tokenizer.cpp $(PLATFORM_CORE)

$(BUILD)/test_platform: src/common/platform_test.cpp $(PLATFORM_CORE) src/common/platform.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ src/common/platform_test.cpp $(PLATFORM_CORE)

$(BUILD)/test_runner: src/common/runner_test.cpp $(PLATFORM_SRC) src/common/runner.cpp src/common/runner.h src/common/runner_internal.h vendor/doctest.h | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I src/common -I vendor -o $@ src/common/runner_test.cpp src/common/runner.cpp $(PLATFORM_SRC)

$(BUILD):
	@mkdir -p $(BUILD)

##@ Quality

smoke: build ## Run smoke test (quick sanity check)
	bash scripts/smoke-test.sh ./$(BINARY)

coverage: ## Build with coverage and report
	@mkdir -p .tmp/cov
	$(CXX) $(CXXFLAGS) --coverage -I vendor -o .tmp/cov/test_toml src/toml_test.cpp src/common/toml.cpp
	cd .tmp/cov && ./test_toml
	$(CXX) $(CXXFLAGS) --coverage -I src -o .tmp/cov/test_checks src/checks_test.cpp src/io/filesystem.cpp
	cd .tmp/cov && ./test_checks
	$(CXX) $(CXXFLAGS) --coverage -I vendor -I src -o .tmp/cov/test_commands src/commands/commands_test.cpp src/commands/cmd_docs.cpp src/commands/cmd_sort.cpp
	cd .tmp/cov && ./test_commands
	$(CXX) $(CXXFLAGS) --coverage -I vendor -I src -o .tmp/cov/test_sort src/sort_test.cpp src/commands/cmd_sort.cpp
	cd .tmp/cov && ./test_sort
	$(CXX) $(CXXFLAGS) --coverage -I src -I vendor -o .tmp/cov/test_tokenizer src/analysis/tokenizer_test.cpp src/analysis/tokenizer.cpp
	cd .tmp/cov && ./test_tokenizer
	$(CXX) $(CXXFLAGS) --coverage -I src -I vendor -o .tmp/cov/test_import_graph src/analysis/import_graph_test.cpp src/analysis/import_graph.cpp
	cd .tmp/cov && ./test_import_graph
	$(CXX) $(CXXFLAGS) --coverage -I src -I vendor $(RE2_CFLAGS) -o .tmp/cov/test_rules src/rules_test.cpp src/rules/rule_engine.cpp src/analysis/tokenizer.cpp $(RE2_LDFLAGS)
	.tmp/cov/test_rules
	$(CXX) $(CXXFLAGS) --coverage -I src -I vendor -o .tmp/cov/test_platform src/common/platform_test.cpp $(PLATFORM_CORE)
	cd .tmp/cov && ./test_platform
	$(CXX) $(CXXFLAGS) --coverage -I src -I src/common -I vendor -o .tmp/cov/test_runner src/common/runner_test.cpp src/common/runner.cpp $(PLATFORM_SRC)
	cd .tmp/cov && ./test_runner
	$(CXX) $(CXXFLAGS) --coverage -I src -I vendor -o .tmp/cov/test_tool_runner src/runners/tool_runner_test.cpp src/runners/tool_runner.cpp $(PLATFORM_CORE)
	cd .tmp/cov && ./test_tool_runner
	@echo ""
	@echo "Coverage (src/ only):"
	@cd .tmp/cov && gcov *.gcda 2>/dev/null | grep -B1 "^Lines" | grep -A1 "^File '.*src/" | \
		grep "Lines" | sed 's/Lines executed:/  /' | sort -t'%' -k1 -n
	@echo ""
	@cd .tmp/cov && gcov *.gcda 2>/dev/null | grep -A1 "^File '.*src/" | grep "Lines" | \
		awk -F'[:%]' '{pct+=$$2; n++} END {printf "  Total: %.1f%% (%d files)\n", pct/n, n}'

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
	@bash scripts/gh/wait-pipeline.sh

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
# check-dutch: new universal check
