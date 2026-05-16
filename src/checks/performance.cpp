/**
 * @file performance.cpp
 * @brief Native performance smell detection — finds likely O(n²), N+1, sync IO.
 *
 * Detects patterns that are statically visible and almost always problematic:
 * - Async/DB/fetch inside loops (N+1)
 * - Nested collection lookups (O(n²))
 * - Sequential awaits (should be Promise.all)
 * - Sync IO (readFileSync in servers)
 * - JSON.parse(JSON.stringify()) cloning
 * - Regex catastrophic backtracking
 * - Unbounded caches (no eviction)
 */
#include "check.h"

struct PerformanceCheck : Check {
  PerformanceCheck() { name = "performance"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|js|tsx|jsx|py|java|cpp)$");

    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      bool in_loop = false;
      int sequential_awaits = 0;
      size_t pos = 0;

      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* Track loop context */
        if (ln.find("for ") != std::string::npos || ln.find("for(") != std::string::npos ||
            ln.find(".map(") != std::string::npos || ln.find(".forEach(") != std::string::npos ||
            ln.find("while ") != std::string::npos)
          in_loop = true;
        if (in_loop && ln.find("}") != std::string::npos && ln.find("{") == std::string::npos)
          in_loop = false;

        /* N+1: async/fetch/db inside loop */
        if (in_loop) {
          if (ln.find("await ") != std::string::npos || ln.find("fetch(") != std::string::npos)
            findings.push_back({name, "warning", file, line, "n-plus-one",
                "Async/fetch inside loop (potential N+1)", "Batch queries or use Promise.all", ""});
          if (ln.find(".find(") != std::string::npos || ln.find(".filter(") != std::string::npos)
            findings.push_back({name, "info", file, line, "nested-lookup",
                "Collection lookup inside loop (potential O(n²))", "Use Map/Set for O(1) lookup", ""});
        }

        /* Sequential awaits (3+ in a row) */
        if (ln.find("await ") != std::string::npos) {
          sequential_awaits++;
          if (sequential_awaits >= 3)
            findings.push_back({name, "info", file, line, "sequential-await",
                "3+ sequential awaits — consider Promise.all()", "Parallelize independent calls", ""});
        } else if (ln.find_first_not_of(" \t") != std::string::npos) {
          sequential_awaits = 0;
        }

        /* Sync IO */
        if (ln.find("readFileSync") != std::string::npos || ln.find("writeFileSync") != std::string::npos)
          findings.push_back({name, "warning", file, line, "sync-io",
              "Synchronous file I/O (blocks event loop)", "Use async fs.readFile()", ""});

        /* JSON clone anti-pattern */
        if (ln.find("JSON.parse(JSON.stringify(") != std::string::npos)
          findings.push_back({name, "info", file, line, "json-clone",
              "JSON.parse(JSON.stringify()) is slow for cloning", "Use structuredClone() or spread", ""});

        /* Catastrophic regex: nested quantifiers */
        if ((ln.find("(.*)*") != std::string::npos || ln.find("(a+)+") != std::string::npos ||
             ln.find("(.+)+") != std::string::npos))
          findings.push_back({name, "error", file, line, "regex-catastrophic",
              "Regex with nested quantifiers (catastrophic backtracking)", "Rewrite regex or add timeout", ""});

        /* Unbounded cache */
        if ((ln.find("cache[") != std::string::npos || ln.find("cache.set(") != std::string::npos) &&
            content.find("maxSize") == std::string::npos && content.find("ttl") == std::string::npos &&
            content.find("evict") == std::string::npos)
          findings.push_back({name, "info", file, line, "unbounded-cache",
              "Cache without size limit or TTL", "Add maxSize/TTL to prevent memory growth", ""});

        pos = eol + 1;
      }
    }
    return findings;
  }
};
