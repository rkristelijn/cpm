CXX      = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -O2
BINARY   = cpm
SRCS     = src/main.cpp src/toml.cpp src/runner.cpp src/setup.cpp

.DEFAULT_GOAL := help

.PHONY: all build clean install help test

build: $(BINARY) ## Build cpm

$(BINARY): $(SRCS) src/toml.h src/runner.h src/setup.h
	$(CXX) $(CXXFLAGS) -o $@ $(SRCS)

clean: ## Remove build artifacts
	rm -f $(BINARY)

install: build ## Install to /usr/local/bin
	cp $(BINARY) /usr/local/bin/$(BINARY)
	@echo "Installed cpm to /usr/local/bin/cpm"

test: build ## Run self-test
	./$(BINARY) check

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
