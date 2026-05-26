#!/usr/bin/env node
// generate-contracts.js — Generate contract tests from extracted coupling data.
//
// Usage:
//   ./scripts/extract-coupling.sh debug /tmp/express | node scripts/generate-contracts.js
//   node scripts/generate-contracts.js < coupling.json --pkg debug --out packages/debug/test/
//
// Reads JSON from stdin (output of extract-coupling.sh), generates test file.
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const pkgFlag = args.indexOf('--pkg');
const outFlag = args.indexOf('--out');
const pkgName = pkgFlag >= 0 ? args[pkgFlag + 1] : null;
const outDir = outFlag >= 0 ? args[outFlag + 1] : null;

const input = fs.readFileSync('/dev/stdin', 'utf8');
let data;
try { data = JSON.parse(input); } catch { console.error('Invalid JSON input'); process.exit(1); }

if (!data.length) { console.error('No call signatures to generate tests for'); process.exit(0); }

// Infer package name from signatures
const pkg = pkgName || inferPkg(data);
if (!pkg) { console.error('Cannot infer package name. Use --pkg <name>'); process.exit(1); }

const tests = generateTests(data, pkg);
const output = `// Contract tests — auto-generated from framework usage analysis
// Source: extract-coupling.sh
// DO NOT EDIT — regenerate with: ./scripts/extract-coupling.sh ${pkg} <framework> | node scripts/generate-contracts.js --pkg ${pkg}
const { test } = require('node:test');
const assert = require('node:assert/strict');
const pkg = require('../src/index.js');

${tests.join('\n\n')}
`;

if (outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'contract.test.js');
  fs.writeFileSync(outPath, output);
  console.error(`Written: ${outPath} (${tests.length} tests)`);
} else {
  process.stdout.write(output);
  console.error(`Generated ${tests.length} contract tests for ${pkg}`);
}

function generateTests(data, pkg) {
  const tests = [];

  for (const entry of data) {
    if (entry.type === 'call' && !entry.member) {
      // Direct invocation: pkg(args)
      tests.push(genDirectCallTest(entry, pkg));
    } else if (entry.type === 'method') {
      tests.push(genMethodTest(entry, pkg));
    } else if (entry.type === 'property') {
      tests.push(genPropertyTest(entry, pkg));
    }
  }

  return tests;
}

function genDirectCallTest(entry, pkg) {
  const source = entry.file.split('/').slice(-3).join('/');
  const desc = `${pkg}() called as: ${entry.signature} (${source}:${entry.line})`;
  return `test("contract: ${esc(desc)}", () => {
  // Verify ${pkg} is callable (framework calls it directly)
  assert.equal(typeof pkg, 'function', '${pkg} must be a function');
});`;
}

function genMethodTest(entry, pkg) {
  const source = entry.file.split('/').slice(-3).join('/');
  const desc = `${pkg}.${entry.member}() exists (${source}:${entry.line})`;
  return `test("contract: ${esc(desc)}", () => {
  assert.equal(typeof pkg.${entry.member}, 'function', '${pkg}.${entry.member} must be a function');
});`;
}

function genPropertyTest(entry, pkg) {
  const source = entry.file.split('/').slice(-3).join('/');
  const desc = `${pkg}.${entry.member} exists (${source}:${entry.line})`;
  return `test("contract: ${esc(desc)}", () => {
  assert.ok('${entry.member}' in pkg || typeof pkg.${entry.member} !== 'undefined', '${pkg}.${entry.member} must exist');
});`;
}

function inferPkg(data) {
  if (!data[0]) return null;
  const sig = data[0].signature;
  const m = sig.match(/^([\w-]+)/);
  return m ? m[1] : null;
}

function esc(s) { return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' '); }
