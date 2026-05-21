/**
// @see ADR-139
 * @file mock_boundary.cpp
 * @brief Detects mock-boundary violations — mockable functions used for filesystem ops.
 *
 * When a project uses a mockable execution wrapper (cpm_exec, exec_cmd, run_command),
 * filesystem mutations (mkdir, sed, rm, cp, mv, chmod) should use system() directly
 * to avoid tests accidentally disabling real side-effects.
 */
#include "../check.h"

struct MockBoundaryCheck : Check {
  MockBoundaryCheck() {
    name = "mock-boundary";
    category = "architecture";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py)$");

    /* Patterns: mockable wrappers calling filesystem ops */
    static const char* mock_wrappers[] = {"cpm_exec", "exec_cmd", "run_command", "shell_exec", nullptr};
    static const char* fs_ops[] = {"mkdir", "sed -i", "rm -f", "rm -rf", "cp ", "mv ", "chmod ", nullptr};

    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;

      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        for (int w = 0; mock_wrappers[w]; w++) {
          if (ln.find(mock_wrappers[w]) != std::string::npos) {
            for (int op = 0; fs_ops[op]; op++) {
              if (ln.find(fs_ops[op]) != std::string::npos) {
                findings.push_back({name, "warning", file, line, "mock-boundary-violation",
                                    std::string("Filesystem op '") + fs_ops[op] + "' via mockable wrapper '" + mock_wrappers[w] +
                                        "' — use system() to avoid test mock leaks",
                                    ""});
                break;
              }
            }
          }
        }
        pos = eol + 1;
      }
    }
    return findings;
  }
};
