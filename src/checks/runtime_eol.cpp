/**
 * @file runtime_eol.cpp
 * @brief Native runtime EOL check — detects end-of-life Node/Python/Java.
 */
#include "check.h"

#include <cstdlib>
#include <regex>

struct RuntimeEolCheck : Check {
  RuntimeEolCheck() { name = "runtime-eol"; category = "deps"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    /* Node.js — minimum supported LTS */
    int node_min = 20;
    int node_ver = 0;
    if (fs.exists(".nvmrc")) {
      std::string content = fs.read(".nvmrc");
      node_ver = atoi(content.c_str());
    } else if (fs.exists("package.json")) {
      std::string content = fs.read("package.json");
      std::regex re("\"node\":\\s*\"[^0-9]*([0-9]+)");
      std::smatch m;
      if (std::regex_search(content, m, re)) node_ver = atoi(m[1].str().c_str());
    }
    if (node_ver > 0 && node_ver < node_min)
      findings.push_back({name, "error", ".nvmrc", 0, "node-eol",
          "Node.js " + std::to_string(node_ver) + " is EOL",
          "Upgrade to Node " + std::to_string(node_min) + "+"});

    /* Python */
    int py_min = 311; /* 3.11 as int */
    if (fs.exists(".python-version")) {
      std::string content = fs.read(".python-version");
      std::regex re("([0-9]+)\\.([0-9]+)");
      std::smatch m;
      if (std::regex_search(content, m, re)) {
        int ver = atoi(m[1].str().c_str()) * 100 + atoi(m[2].str().c_str());
        if (ver < py_min)
          findings.push_back({name, "warning", ".python-version", 0, "python-eol",
              "Python " + m[0].str() + " approaching EOL", "Upgrade to 3.11+"});
      }
    }

    /* Java */
    if (fs.exists("pom.xml")) {
      std::string content = fs.read("pom.xml");
      std::regex re("<java\\.version>([0-9]+)</java\\.version>");
      std::smatch m;
      if (std::regex_search(content, m, re)) {
        int ver = atoi(m[1].str().c_str());
        if (ver < 17)
          findings.push_back({name, "error", "pom.xml", 0, "java-eol",
              "Java " + m[1].str() + " is EOL", "Upgrade to Java 17+"});
      }
    }

    return findings;
  }
};
