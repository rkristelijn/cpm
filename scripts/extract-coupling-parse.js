#!/usr/bin/env node
// extract-coupling-parse.js — Parse files for package usage (called by extract-coupling.sh)
// Usage: echo "file1\nfile2" | node extract-coupling-parse.js <package-name>
const fs = require('fs');
const pkg = process.argv[2];
if (!pkg) { console.error('Usage: ... | node extract-coupling-parse.js <pkg>'); process.exit(1); }

const lines = fs.readFileSync('/dev/stdin', 'utf8').trim().split('\n');
const results = [];

for (const file of lines) {
  if (!file) continue;
  let content;
  try { content = fs.readFileSync(file, 'utf8'); } catch { continue; }
  results.push(...extractUsage(content, pkg, file));
}

// Deduplicate
const seen = new Set();
const unique = results.filter(r => {
  const key = r.type + '|' + r.member + '|' + r.signature;
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
});

process.stderr.write('Unique call signatures: ' + unique.length + '\n');
console.log(JSON.stringify(unique, null, 2));

function extractUsage(content, pkg, file) {
  const hits = [];
  const srcLines = content.split('\n');
  const esc = pkg.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  let varName = null;
  let destructured = [];

  for (let i = 0; i < srcLines.length; i++) {
    const ln = srcLines[i];

    // const x = require("pkg")
    let m = ln.match(new RegExp(`(?:const|let|var)\\s+(\\w+)\\s*=\\s*require\\(['"]${esc}['"]\\)`));
    if (m) { varName = m[1]; continue; }

    // const { a, b } = require("pkg")
    m = ln.match(new RegExp(`(?:const|let|var)\\s*\\{([^}]+)\\}\\s*=\\s*require\\(['"]${esc}['"]\\)`));
    if (m) { destructured = m[1].split(',').map(s => s.trim().split(/\s+as\s+|:/)[0].trim()); continue; }

    // import x from "pkg"
    m = ln.match(new RegExp(`import\\s+(\\w+)\\s+from\\s+['"]${esc}['"]`));
    if (m) { varName = m[1]; continue; }

    // import { a, b } from "pkg"
    m = ln.match(new RegExp(`import\\s*\\{([^}]+)\\}\\s*from\\s+['"]${esc}['"]`));
    if (m) { destructured = m[1].split(',').map(s => s.trim().split(/\s+as\s+/)[0].trim()); continue; }

    // require("pkg")("arg") — immediate invocation
    m = ln.match(new RegExp(`require\\(['"]${esc}['"]\\)\\s*\\(([^)]*)\\)`));
    if (m) {
      hits.push({ type: 'call', member: null, signature: `require("${pkg}")( ${summarize(m[1])})`, args: m[1].trim(), file, line: i + 1 });
      continue;
    }
  }

  // Second pass: find usage of varName and destructured names
  for (let i = 0; i < srcLines.length; i++) {
    const ln = srcLines[i];

    if (varName) {
      // varName(args)
      const callRe = new RegExp(`(?<![.\\w])${varName}\\s*\\(([^)]*?)\\)`, 'g');
      let cm;
      while ((cm = callRe.exec(ln)) !== null) {
        // Skip the require line itself
        if (ln.includes(`require(`)) continue;
        hits.push({ type: 'call', member: null, signature: `${pkg}(${summarize(cm[1])})`, args: cm[1].trim(), file, line: i + 1 });
      }

      // varName.method(args)
      const methodRe = new RegExp(`${varName}\\.(\\w+)\\s*\\(([^)]*?)\\)`, 'g');
      while ((cm = methodRe.exec(ln)) !== null) {
        hits.push({ type: 'method', member: cm[1], signature: `${pkg}.${cm[1]}(${summarize(cm[2])})`, args: cm[2].trim(), file, line: i + 1 });
      }

      // varName.prop (no call, full word)
      const propRe = new RegExp(`${varName}\\.(\\w+)\\b(?!\\s*\\()`, 'g');
      while ((cm = propRe.exec(ln)) !== null) {
        // Skip if this is a substring of a method call already found
        if (!hits.some(h => h.line === i + 1 && h.member === cm[1]) && cm[1].length > 2) {
          hits.push({ type: 'property', member: cm[1], signature: `${pkg}.${cm[1]}`, args: null, file, line: i + 1 });
        }
      }
    }

    for (const fn of destructured) {
      const fnRe = new RegExp(`(?<![.\\w])${fn}\\s*\\(([^)]*?)\\)`, 'g');
      let cm;
      while ((cm = fnRe.exec(ln)) !== null) {
        if (ln.includes(`require(`)) continue;
        hits.push({ type: 'call', member: fn, signature: `${pkg}.${fn}(${summarize(cm[1])})`, args: cm[1].trim(), file, line: i + 1 });
      }
    }
  }

  return hits;
}

function summarize(args) {
  if (!args || !args.trim()) return '';
  return args.split(',').map(a => {
    a = a.trim();
    if (!a) return '';
    if (/^['"`]/.test(a)) return JSON.stringify(a.slice(1, -1));
    if (/^\d/.test(a)) return a;
    if (/^(true|false)$/.test(a)) return a;
    if (/^\{/.test(a)) return 'object';
    if (/^\[/.test(a)) return 'array';
    if (/^(null|undefined)$/.test(a)) return a;
    return 'expr';
  }).join(', ');
}
