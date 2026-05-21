#!/usr/bin/env bash
# fixes/package-json.sh — Fix package.json best practices
# Adds: repository (from git remote), engines, description, .nvmrc
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"

[ -f "$PKG" ] || { echo "  ✗ No package.json"; exit 1; }

cd "$REPO"

node -e "
const fs = require('fs');
const { execSync } = require('child_process');
const pkg = JSON.parse(fs.readFileSync('./package.json', 'utf8'));
let changed = 0;

// 1. Repository from git remote
if (!pkg.repository) {
  try {
    const remote = execSync('git remote get-url origin 2>/dev/null', { encoding: 'utf8' }).trim();
    if (remote) {
      // Normalize: git@github.com:user/repo.git → https://github.com/user/repo
      let url = remote
        .replace(/^git@([^:]+):/, 'https://\$1/')
        .replace(/\.git$/, '');
      pkg.repository = { type: 'git', url: url };
      console.log('  ✓ Added repository: ' + url);
      changed++;
    }
  } catch(e) {}
}
if (!pkg.repository) {
  // Fallback: use package name as placeholder
  pkg.repository = { type: 'git', url: 'https://github.com/OWNER/' + pkg.name };
  console.log('  ✓ Added repository placeholder (update with real URL)');
  changed++;
}

// 2. Description
if (!pkg.description) {
  pkg.description = pkg.name + ' — generated with create-next-app';
  console.log('  ✓ Added description (update with real description)');
  changed++;
}

// 3. Engines (pin node version)
if (!pkg.engines) {
  let nodeVer = '22';
  // Try to detect from .nvmrc or current node
  try {
    const nv = execSync('node --version', { encoding: 'utf8' }).trim().replace('v','');
    nodeVer = nv.split('.')[0];
  } catch(e) {}
  pkg.engines = { node: '>=' + nodeVer };
  console.log('  ✓ Added engines.node: >=' + nodeVer);
  changed++;
}

// 4. Create .nvmrc if missing
if (!fs.existsSync('.nvmrc') && !fs.existsSync('.node-version')) {
  let nodeVer = '22';
  try {
    const nv = execSync('node --version', { encoding: 'utf8' }).trim().replace('v','');
    nodeVer = nv.split('.')[0];
  } catch(e) {}
  fs.writeFileSync('.nvmrc', nodeVer + '\n');
  console.log('  ✓ Created .nvmrc (' + nodeVer + ')');
  changed++;
}

if (changed > 0) {
  fs.writeFileSync('./package.json', JSON.stringify(pkg, null, 2) + '\n');
} else {
  console.log('  ✓ package.json already has best practices');
}
"
