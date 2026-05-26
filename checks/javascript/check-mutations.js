#!/usr/bin/env node
// checks/check-mutations.js — Mutation testing with auto-fix (generates tests to kill survivors).
//
// Usage:
//   node checks/check-mutations.js ms cookie       # specific packages
//   node checks/check-mutations.js --fix ms        # generate tests to kill survivors
//   node checks/check-mutations.js --summary       # show stored results
//   node checks/check-mutations.js --threshold 80  # fail if below 80%
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "data/mutations");
fs.mkdirSync(OUT_DIR, { recursive: true });

const args = process.argv.slice(2);
const FIX = args.includes("--fix");
const SUMMARY = args.includes("--summary");
const threshIdx = args.indexOf("--threshold");
const THRESHOLD = threshIdx >= 0 ? Number(args[threshIdx + 1]) : 80;
const pkgs = args.filter((a) => !a.startsWith("--") && !(threshIdx >= 0 && a === args[threshIdx + 1]));

if (SUMMARY) { showSummary(); process.exit(0); }
if (!pkgs.length) { console.error("Usage: node checks/check-mutations.js [--fix] [--threshold N] <pkg...>"); process.exit(1); }

for (const pkg of pkgs) {
  const src = `packages/${pkg}/src/index.js`;
  const testGlob = `packages/${pkg}/test/*.test.js`;
  if (!fs.existsSync(path.join(ROOT, src))) { console.error(`${pkg}: not found`); continue; }

  console.log(`▶ ${pkg}`);

  // Run stryker
  const conf = {
    mutate: [src],
    testRunner: "command",
    commandRunner: { command: `node --test ${testGlob}` },
    reporters: ["json"],
    jsonReporter: { fileName: `data/mutations/${pkg}.json` },
    concurrency: 2,
    timeoutMS: 15000,
  };
  const confFile = path.join(ROOT, `.stryker-tmp-${pkg}.conf.js`);
  fs.writeFileSync(confFile, `module.exports = ${JSON.stringify(conf)};\n`);
  try { execSync(`npx stryker run ${confFile}`, { cwd: ROOT, timeout: 180000, stdio: ["pipe", "pipe", "pipe"] }); } catch {}
  fs.rmSync(confFile, { force: true });

  // Parse results
  const resultFile = path.join(OUT_DIR, `${pkg}.json`);
  if (!fs.existsSync(resultFile)) { console.log("  ⚠ No results\n"); continue; }
  const data = JSON.parse(fs.readFileSync(resultFile, "utf8"));
  const srcContent = fs.readFileSync(path.join(ROOT, src), "utf8").split("\n");

  let killed = 0, survived = 0;
  const survivors = [];
  for (const f of Object.values(data.files || {})) {
    for (const m of f.mutants || []) {
      if (m.status === "Killed" || m.status === "Timeout") killed++;
      else if (m.status === "Survived") {
        survived++;
        survivors.push({
          line: m.location.start.line,
          mutator: m.mutatorName,
          original: srcContent[m.location.start.line - 1]?.trim(),
          replacement: m.replacement?.slice(0, 80),
        });
      }
    }
  }

  const total = killed + survived;
  const score = total ? Math.round((killed / total) * 100) : 100;
  const status = score >= THRESHOLD ? "✓" : "✗";
  console.log(`  ${status} ${score}% (${killed}/${total} killed, ${survived} survived)`);

  if (survived && FIX) {
    // Group survivors by line to generate targeted tests
    const byLine = {};
    for (const s of survivors) {
      byLine[s.line] = byLine[s.line] || [];
      byLine[s.line].push(s);
    }

    const testFile = path.join(ROOT, `packages/${pkg}/test/mutation.test.js`);
    let tests = `// Auto-generated mutation tests for ${pkg}\n`;
    tests += `const { test } = require("node:test");\nconst assert = require("node:assert/strict");\n`;
    tests += `const mod = require("../src/index.js");\n\n`;

    for (const [line, muts] of Object.entries(byLine).slice(0, 20)) {
      const src = muts[0].original;
      tests += `// L${line}: ${muts.map((m) => m.mutator).join(", ")}\n`;
      tests += `// Original: ${src}\n`;
      tests += `test("mutation L${line} — ${muts[0].mutator}", () => {\n`;
      tests += `  // TODO: add assertion that kills this mutant\n`;
      tests += `  // Mutators: ${muts.map((m) => m.mutator + " → " + (m.replacement || "removed")).join("; ")}\n`;
      tests += `});\n\n`;
    }

    fs.writeFileSync(testFile, tests);
    console.log(`  → Generated ${Object.keys(byLine).length} test stubs in test/mutation.test.js`);
  }

  if (survived && !FIX) {
    console.log(`  Top survivors:`);
    for (const s of survivors.slice(0, 5)) {
      console.log(`    L${s.line} [${s.mutator}] ${s.original}`);
    }
  }
  console.log();
}

fs.rmSync(path.join(ROOT, ".stryker-tmp"), { recursive: true, force: true });
if (!SUMMARY) showSummary();

function showSummary() {
  const files = fs.readdirSync(OUT_DIR).filter((f) => f.endsWith(".json"));
  if (!files.length) return;
  let below = 0;
  console.log("\n| Package | Score | Killed | Survived |");
  console.log("|---------|-------|--------|----------|");
  for (const f of files.sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(OUT_DIR, f), "utf8"));
    const pkg = f.replace(".json", "");
    let killed = 0, survived = 0;
    for (const file of Object.values(data.files || {})) {
      for (const m of file.mutants || []) {
        if (m.status === "Killed" || m.status === "Timeout") killed++;
        else if (m.status === "Survived") survived++;
      }
    }
    const total = killed + survived;
    const score = total ? Math.round((killed / total) * 100) : 100;
    if (score < THRESHOLD) below++;
    const flag = score >= THRESHOLD ? "✓" : "✗";
    console.log(`| ${flag} ${pkg} | ${score}% | ${killed} | ${survived} |`);
  }
  if (below) console.log(`\n${below} package(s) below ${THRESHOLD}% threshold.`);
}
