#!/usr/bin/env node
// checks/check-perf.js — Detect performance anti-patterns in flupke packages.
//
// Usage:
//   node checks/check-perf.js          # detect only
//   node checks/check-perf.js --fix    # auto-fix where safe
const fs = require("fs");
const path = require("path");
const { loadConfig, getPackages } = require("./check-helpers");

const ROOT = path.resolve(__dirname, "..");
const FIX = process.argv.includes("--fix");

const { exclude: EXCLUDE, allow: ALLOW } = loadConfig(ROOT, "perf");
const pkgs = getPackages(ROOT, EXCLUDE);

let totalIssues = 0;
let totalFixed = 0;

const rules = [
  {
    id: "P001",
    name: "JSON.parse(JSON.stringify()) — use structuredClone",
    detect: (line) => /JSON\.parse\s*\(\s*JSON\.stringify/.test(line),
    fix: (line) => line.replace(/JSON\.parse\s*\(\s*JSON\.stringify\s*\(([^)]+)\)\s*\)/, "structuredClone($1)"),
  },
  {
    id: "P002",
    name: "delete operator — causes hidden class transition",
    detect: (line) => /\bdelete\s+\w+[\[.]/.test(line) && !/\/\//.test(line.split("delete")[0]),
    fix: null,
  },
  {
    id: "P003",
    name: "await in loop — consider Promise.all",
    detect: (line, lines, i) => {
      if (!/\bawait\b/.test(line)) return false;
      // Check if we're inside a for/while loop
      for (let j = i - 1; j >= Math.max(0, i - 10); j--) {
        if (/^\s*(for|while)\s*\(/.test(lines[j])) return true;
      }
      return false;
    },
    fix: null,
  },
  {
    id: "P004",
    name: "Array.includes in loop — use Set for O(1) lookup",
    detect: (line, lines, i) => {
      if (!/\.includes\(/.test(line)) return false;
      for (let j = i - 1; j >= Math.max(0, i - 5); j--) {
        if (/^\s*(for|while)\s*\(/.test(lines[j])) return true;
      }
      return false;
    },
    fix: null,
  },
  {
    id: "P005",
    name: "new Object/Array in loop — hoist allocation",
    detect: (line, lines, i) => {
      if (!/\bnew\s+(Object|Array|Map|Set)\b/.test(line) && !/\{\s*\}/.test(line)) return false;
      // Only flag if inside a for/while
      for (let j = i - 1; j >= Math.max(0, i - 5); j--) {
        if (/^\s*(for|while)\s*\(/.test(lines[j])) {
          // Ignore if it's a result accumulator pattern
          if (/\b(push|result|out|arr)\b/.test(line)) return false;
          return /\bnew\s+(Object|Array|Map|Set)\b/.test(line);
        }
      }
      return false;
    },
    fix: null,
  },
  {
    id: "P006",
    name: "arguments object — use rest params",
    detect: (line) => /\barguments\b/.test(line) && !/\/\//.test(line.split("arguments")[0]),
    fix: null,
  },
  {
    id: "P007",
    name: "Array.from + map — use Array.from(x, mapFn)",
    detect: (line) => /Array\.from\([^)]+\)\.map\(/.test(line),
    fix: (line) => {
      const m = line.match(/Array\.from\(([^)]+)\)\.map\(([^)]+)\)/);
      if (!m) return line;
      return line.replace(`Array.from(${m[1]}).map(${m[2]})`, `Array.from(${m[1]}, ${m[2]})`);
    },
  },
  {
    id: "P008",
    name: "Object.keys().forEach/map — use Object.entries or for...in",
    detect: (line) => /Object\.keys\([^)]+\)\.(forEach|map)\(/.test(line),
    fix: null,
  },
  {
    id: "P009",
    name: "spread in loop — causes repeated allocation",
    detect: (line, lines, i) => {
      if (!/\.\.\./.test(line)) return false;
      if (!/=\s*\[/.test(line) && !/=\s*\{/.test(line)) return false;
      for (let j = i - 1; j >= Math.max(0, i - 5); j--) {
        if (/^\s*(for|while)\s*\(/.test(lines[j])) return true;
      }
      return false;
    },
    fix: null,
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
        issues.push({ rule: rule.id, name: rule.name, line: i + 1 });
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
  console.log(`Fixed ${totalFixed} issues. ${totalIssues - totalFixed} require manual fix.`);
} else {
  console.log(`\n${totalIssues} perf issues detected.${totalIssues ? " Run with --fix to auto-fix safe ones." : ""}`);
}

process.exit(totalIssues > 0 && !FIX ? 1 : 0);
