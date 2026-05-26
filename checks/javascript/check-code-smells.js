#!/usr/bin/env node
// checks/check-code-smells.js — Detect common code smells flagged by SonarCloud.
//
// Usage:
//   node checks/check-code-smells.js          # detect only
//   node checks/check-code-smells.js --fix    # auto-fix where safe
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const FIX = process.argv.includes("--fix");
// Load config from cpm.toml
function loadConfig() {
  const tomlPath = path.join(ROOT, "cpm.toml");
  if (!fs.existsSync(tomlPath)) return { exclude: new Set(), allow: new Set() };
  const content = fs.readFileSync(tomlPath, "utf8");

  const exclude = new Set();
  const exclMatch = content.match(/\[code-smells\]\n([\s\S]*?)(?:\n\[|$)/);
  if (exclMatch) {
    const m = exclMatch[1].match(/exclude\s*=\s*\[([^\]]*)\]/);
    if (m) m[1].replace(/"([^"]+)"/g, (_, v) => exclude.add(v));
  }

  const allow = new Set();
  const allowMatch = content.match(/\[code-smells\.allow\]\n([\s\S]*?)(?:\n\[|$)/);
  if (allowMatch) {
    for (const line of allowMatch[1].split("\n")) {
      const m = line.match(/^"([^"]+)"\s*=/);
      if (m) allow.add(m[1]);
    }
  }

  return { exclude, allow };
}

const { exclude: EXCLUDE, allow: ALLOW } = loadConfig();

const pkgs = fs.readdirSync(path.join(ROOT, "packages"))
  .filter((d) => !EXCLUDE.has(d) && fs.existsSync(path.join(ROOT, "packages", d, "src/index.js")));

let totalIssues = 0;
let totalFixed = 0;

const rules = [
  {
    id: "S7781",
    name: "replaceAll over replace with /g",
    detect: (line) => /\.replace\(\/([^/]+)\/g\s*,/.test(line) && !/\.replace\(\/.*[\\[(|*+?{^$]/.test(line),
    fix: (line) => {
      const m = line.match(/\.replace\(\/([^/]+)\/g\s*,\s*(.+)\)/);
      if (!m || /[\\[(|*+?{^$]/.test(m[1])) return line;
      return line.replace(`.replace(/${m[1]}/g, ${m[2]})`, `.replaceAll("${m[1]}", ${m[2]})`);
    },
  },
  {
    id: "S6582",
    name: "optional chaining",
    detect: (line) => {
      // Match: `x && x.y` or `x && x.y()` pattern (same variable on both sides)
      const m = line.match(/(\w+)\s*&&\s*\1\.(\w+)/);
      if (!m) return false;
      if (/\|\|/.test(line)) return false;
      return true;
    },
    fix: null, // too risky for auto-fix
  },
  {
    id: "S7748",
    name: "zero fraction in number",
    detect: (line) => /\b\d+\.0\b/.test(line),
    fix: (line) => line.replace(/\b(\d+)\.0\b/g, "$1"),
  },
  {
    id: "S7735",
    name: "negated condition with else",
    detect: (line, lines, i) => {
      if (!/^(\s*)if\s*\(!/.test(line)) return false;
      // Check if there's a matching else
      let depth = 0;
      for (let j = i; j < lines.length; j++) {
        depth += (lines[j].match(/\{/g) || []).length - (lines[j].match(/\}/g) || []).length;
        if (depth === 0 && j > i && /^\s*}\s*else\s*\{/.test(lines[j + 1] || "")) return true;
        if (depth === 0 && j > i) return false;
      }
      return false;
    },
    fix: null, // needs AST
  },
  {
    id: "S4138",
    name: "for-of instead of indexed for",
    detect: (line, lines, i) => {
      const m = line.match(/for\s*\(\s*let\s+(\w+)\s*=\s*0\s*;\s*\1\s*<\s*(\w+)\.length\s*;\s*\1\+\+\s*\)/);
      if (!m) return false;
      // Check if index is only used as arr[i]
      const idx = m[1], arr = m[2];
      const body = lines.slice(i + 1, i + 20).join("\n");
      const usesIdx = new RegExp(`\\b${idx}\\b(?!\\s*[<+=])`, "g");
      const matches = body.match(usesIdx) || [];
      const arrAccess = new RegExp(`${arr}\\[${idx}\\]`, "g");
      const arrMatches = body.match(arrAccess) || [];
      return matches.length === arrMatches.length && arrMatches.length > 0;
    },
    fix: null, // needs multi-line rewrite
  },
  {
    id: "S4138b",
    name: "forEach instead of for-of",
    detect: (line) => /\.\s*forEach\s*\(\((\w+)\)\s*=>/.test(line),
    fix: (line, lines, i) => {
      // Single-line: arr.forEach((x) => { body });  or  arr.forEach((x) => expr);
      const singleLine = line.match(/^(\s*)(.+)\.forEach\(\((\w+)\)\s*=>\s*(.+)\);\s*$/);
      if (singleLine) {
        const [, indent, arr, param, body] = singleLine;
        const cleanBody = body.endsWith(")") ? body.slice(0, -1) : body;
        return `${indent}for (const ${param} of ${arr}) ${cleanBody.startsWith("{") ? cleanBody : `{ ${cleanBody}; }`}`;
      }
      // Multi-line: arr.forEach((x) => {\n...\n});
      const multiStart = line.match(/^(\s*)(.+)\.forEach\(\((\w+)\)\s*=>\s*\{\s*$/);
      if (multiStart) {
        const [, indent, arr, param] = multiStart;
        // Find closing });
        let depth = 1, end = i + 1;
        while (end < lines.length && depth > 0) {
          depth += (lines[end].match(/\{/g) || []).length - (lines[end].match(/\}/g) || []).length;
          end++;
        }
        // Replace opening and closing
        lines[i] = `${indent}for (const ${param} of ${arr}) {`;
        lines[end - 1] = lines[end - 1].replace(/\}\);?\s*$/, "}");
        return lines[i];
      }
      return line;
    },
  },
];

for (const pkg of pkgs) {
  const file = path.join(ROOT, "packages", pkg, "src/index.js");
  const content = fs.readFileSync(file, "utf8");
  const lines = content.split("\n");
  let modified = false;
  const issues = [];

  for (let i = 0; i < lines.length; i++) {
    for (const rule of rules) {
      if (rule.detect(lines[i], lines, i)) {
        const key = `${pkg}/src/index.js:${i + 1}:${rule.id}`;
        if (ALLOW.has(key)) continue;
        issues.push({ rule: rule.id, name: rule.name, line: i + 1, text: lines[i].trim() });
        if (FIX && rule.fix) {
          const fixed = rule.fix(lines[i], lines, i);
          if (fixed !== lines[i]) { lines[i] = fixed; modified = true; totalFixed++; }
        }
      }
    }
  }

  if (issues.length) {
    totalIssues += issues.length;
    if (!FIX) {
      for (const issue of issues) {
        console.log(`${pkg}/src/index.js:${issue.line} [${issue.rule}] ${issue.name}`);
      }
    }
  }

  if (modified) fs.writeFileSync(file, lines.join("\n"));
}

if (FIX) {
  console.log(`Fixed ${totalFixed} issues across ${pkgs.length} packages.`);
  if (totalIssues - totalFixed > 0) console.log(`${totalIssues - totalFixed} issues require manual fix.`);
} else {
  console.log(`\n${totalIssues} code smells detected. Run with --fix to auto-fix safe ones.`);
}

process.exit(totalIssues > 0 && !FIX ? 1 : 0);
