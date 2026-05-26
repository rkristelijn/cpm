/**
 * @file check-helpers.js
 * @brief Shared utilities for cpm JavaScript quality checks.
 */
const fs = require("fs");
const path = require("path");

/**
 * Load exclude/allow config from cpm.toml for a given section.
 * @param {string} root - Project root directory.
 * @param {string} section - TOML section name (e.g. "code-smells", "perf").
 */
function loadConfig(root, section) {
  const tomlPath = path.join(root, "cpm.toml");
  if (!fs.existsSync(tomlPath)) return { exclude: new Set(), allow: new Set() };
  const content = fs.readFileSync(tomlPath, "utf8");

  const exclude = new Set();
  const exclRe = new RegExp(`\\[${section.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\]\\n([\\s\\S]*?)(?:\\n\\[|$)`);
  const exclMatch = content.match(exclRe);
  if (exclMatch) {
    const m = exclMatch[1].match(/exclude\s*=\s*\[([^\]]*)\]/);
    if (m) m[1].replace(/"([^"]+)"/g, (_, v) => exclude.add(v));
  }

  const allow = new Set();
  const allowRe = new RegExp(`\\[${section.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\.allow\\]\\n([\\s\\S]*?)(?:\\n\\[|$)`);
  const allowMatch = content.match(allowRe);
  if (allowMatch) {
    for (const line of allowMatch[1].split("\n")) {
      const m = line.match(/^"([^"]+)"\s*=/);
      if (m) allow.add(m[1]);
    }
  }

  return { exclude, allow };
}

/**
 * Get list of packages to check.
 * @param {string} root - Project root directory.
 * @param {Set} exclude - Package names to skip.
 */
function getPackages(root, exclude) {
  const pkgDir = path.join(root, "packages");
  if (!fs.existsSync(pkgDir)) return [];
  return fs.readdirSync(pkgDir)
    .filter((d) => !exclude.has(d) && d !== "cli" && fs.existsSync(path.join(pkgDir, d, "src/index.js")));
}

module.exports = { loadConfig, getPackages };
