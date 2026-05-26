#!/usr/bin/env node
// scripts/check-staleness.js — Check how old/stale the original npm packages are that flupke replaces.
//
// Usage:
//   node scripts/check-staleness.js           # all packages, table output
//   node scripts/check-staleness.js --json    # JSON output to data/staleness.json
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const PKG_DIR = path.join(ROOT, "packages");
const OUT_FILE = path.join(ROOT, "data/staleness.json");

const pkgs = fs.readdirSync(PKG_DIR)
  .filter((d) => d !== "cli" && fs.existsSync(path.join(PKG_DIR, d, "package.json")));

const jsonMode = process.argv.includes("--json");
const results = [];
const now = new Date();

console.error(`Checking ${pkgs.length} packages...`);

for (const pkg of pkgs) {
  try {
    const raw = execSync(`npm view "${pkg}" time --json 2>/dev/null`, { encoding: "utf8", timeout: 10000 });
    const time = JSON.parse(raw);
    const lastPublish = time.modified?.split("T")[0] || "unknown";
    const created = time.created?.split("T")[0] || "unknown";
    const versions = Object.keys(time).filter((k) => k !== "created" && k !== "modified");
    const latest = versions[versions.length - 1];
    const ageDays = Math.round((now - new Date(lastPublish)) / 86400000);
    results.push({ pkg, lastPublish, created, latest, ageDays });
  } catch {
    results.push({ pkg, lastPublish: "not-found", created: "not-found", latest: "n/a", ageDays: -1 });
  }
}

results.sort((a, b) => b.ageDays - a.ageDays);

if (jsonMode) {
  const output = { generated: now.toISOString().split("T")[0], packages: results };
  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, JSON.stringify(output, null, 2) + "\n");
  console.error(`Written to ${OUT_FILE}`);
} else {
  const stale3y = results.filter((r) => r.ageDays > 1095);
  const stale1y = results.filter((r) => r.ageDays > 365 && r.ageDays <= 1095);
  const active = results.filter((r) => r.ageDays >= 0 && r.ageDays <= 365);

  console.log(`\n🪦 Abandoned (>3 years): ${stale3y.length}`);
  console.log(`⚠️  Stale (1-3 years):    ${stale1y.length}`);
  console.log(`✓  Active (<1 year):     ${active.length}\n`);

  console.log("| Package | Last publish | Age | Latest |");
  console.log("|---------|-------------|-----|--------|");
  for (const r of results) {
    if (r.ageDays < 0) continue;
    const years = (r.ageDays / 365.25).toFixed(1);
    const flag = r.ageDays > 1095 ? "🪦" : r.ageDays > 365 ? "⚠️ " : "  ";
    console.log(`| ${flag} ${r.pkg} | ${r.lastPublish} | ${years}y | ${r.latest} |`);
  }
}
