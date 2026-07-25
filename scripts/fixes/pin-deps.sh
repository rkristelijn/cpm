#!/usr/bin/env bash
# fixes/pin-deps.sh — Pin dependency versions (remove ^ ~ and replace 'latest')
# Replaces ^/~ with exact installed versions from node_modules
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"

[ -f "$PKG" ] || {
  echo "  ✗ No package.json"
  exit 1
}

# Check if there's anything to pin
if ! grep -qE '"\^|"~|"latest"|"\*"' "$PKG"; then
  echo "  ✓ Dependencies already pinned"
  exit 0
fi

# Use npm to get actual installed versions and pin them
if [ -d "$REPO/node_modules" ]; then
  # Get installed versions for all deps
  TMPFILE=$(mktemp)
  (cd "$REPO" && node -e "
    const fs = require('fs'), path = require('path');
    const pkg = JSON.parse(fs.readFileSync('./package.json','utf8'));
    const sections = ['dependencies', 'devDependencies'];
    let changed = 0;
    for (const section of sections) {
      if (!pkg[section]) continue;
      for (const [name, ver] of Object.entries(pkg[section])) {
        if (ver === 'latest' || ver === '*' || ver.startsWith('^') || ver.startsWith('~')) {
          try {
            const p = path.join('./node_modules', name, 'package.json');
            const installed = JSON.parse(fs.readFileSync(p,'utf8')).version;
            pkg[section][name] = installed;
            changed++;
          } catch(e) {}
        }
      }
    }
    if (changed > 0) {
      fs.writeFileSync('./package.json', JSON.stringify(pkg, null, 2) + '\n');
      console.log(changed);
    } else {
      console.log('0');
    }
  ") >"$TMPFILE"
  COUNT=$(cat "$TMPFILE")
  rm -f "$TMPFILE"

  if [ "$COUNT" = "0" ]; then
    echo "  ✓ Dependencies already pinned"
  else
    echo "  ✓ Pinned $COUNT dependencies to exact versions"
  fi
else
  # Fallback: just strip ^ and ~ (less precise but works without node_modules)
  sed -i.bak 's/"\^/"/g; s/"~/"/g; s/"latest"/"*"/g' "$PKG"
  rm -f "${PKG}.bak"
  echo "  ✓ Stripped ^ and ~ prefixes (install to get exact versions)"
fi
