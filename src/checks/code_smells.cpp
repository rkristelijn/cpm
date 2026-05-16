/**
 * @file code_smells.cpp
 * @brief Miscellaneous code smells — race conditions, timezone, coupling, Docker.
 */
#include "check.h"

struct CodeSmellsCheck : Check {
  CodeSmellsCheck() { name = "code-smells"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|js|tsx|jsx|py|java|go)$");

    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;

      /* Track import style consistency */
      int star_imports = 0, named_imports = 0;

      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* Date without timezone */
        if (ln.find("new Date()") != std::string::npos && content.find("timezone") == std::string::npos &&
            content.find("utc") == std::string::npos && content.find("UTC") == std::string::npos &&
            content.find("tz") == std::string::npos)
          findings.push_back({name, "info", file, line, "date-no-timezone",
              "new Date() without timezone — ambiguous in distributed systems",
              "Use UTC explicitly or date-fns-tz", ""});

        /* Backend generating HTML (mixing concerns) */
        if ((ln.find("res.send(\"<") != std::string::npos || ln.find("res.send('<") != std::string::npos ||
             ln.find("res.send(`<") != std::string::npos || ln.find("innerHTML =") != std::string::npos) &&
            file.find("controller") != std::string::npos || file.find("route") != std::string::npos ||
            file.find("handler") != std::string::npos)
          if (ln.find("<html") != std::string::npos || ln.find("<div") != std::string::npos)
            findings.push_back({name, "warning", file, line, "backend-html",
                "Backend generating HTML — separation of concerns violation",
                "Use template engine or return JSON for frontend", ""});

        /* Race condition patterns */
        if (ln.find("if (") != std::string::npos && (ln.find("exists") != std::string::npos ||
            ln.find("length") != std::string::npos) &&
            content.find("lock") == std::string::npos && content.find("mutex") == std::string::npos &&
            content.find("atomic") == std::string::npos) {
          /* Check-then-act without synchronization (TOCTOU) */
          size_t next = content.find("delete", eol);
          if (next == std::string::npos) next = content.find("remove", eol);
          if (next != std::string::npos && next - eol < 200)
            findings.push_back({name, "info", file, line, "race-condition",
                "Check-then-act pattern (TOCTOU) — potential race condition",
                "Use atomic operations or locks", ""});
        }

        /* Import style inconsistency */
        if (ln.find("import *") != std::string::npos || ln.find("import * as") != std::string::npos)
          star_imports++;
        if (ln.find("import {") != std::string::npos)
          named_imports++;

        pos = eol + 1;
      }

      /* Flag inconsistent import style */
      if (star_imports > 2 && named_imports > 2)
        findings.push_back({name, "info", file, 0, "inconsistent-imports",
            "Mixed import styles (* and named) — pick one convention",
            "Prefer named imports for tree-shaking", ""});
    }

    /* === Dockerfile checks === */
    if (fs.exists("Dockerfile")) {
      std::string df = fs.read("Dockerfile");
      int run_count = 0;
      size_t p = 0;
      while ((p = df.find("RUN ", p)) != std::string::npos) { run_count++; p += 4; }
      if (run_count > 10)
        findings.push_back({name, "warning", "Dockerfile", 0, "docker-too-many-layers",
            std::to_string(run_count) + " RUN instructions — combine with &&",
            "Merge RUN commands to reduce image layers", ""});

      if (df.find("apt-get install") != std::string::npos && df.find("rm -rf /var/lib/apt") == std::string::npos)
        findings.push_back({name, "info", "Dockerfile", 0, "docker-no-cleanup",
            "apt-get install without cleanup — bloats image",
            "Add && rm -rf /var/lib/apt/lists/*", ""});

      if (df.find("COPY . .") != std::string::npos && df.find(".dockerignore") == std::string::npos &&
          !fs.exists(".dockerignore"))
        findings.push_back({name, "warning", "Dockerfile", 0, "docker-no-ignore",
            "COPY . . without .dockerignore — copies everything",
            "Create .dockerignore (node_modules, .git, etc.)", ""});
    }

    return findings;
  }
};
