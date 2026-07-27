#!/usr/bin/env bash
# coverage-new-code.sh — shift-left SonarCloud coverage gate
# Measures coverage ONLY on new/changed lines vs main branch.
# Run after: make coverage && cpm coverage --sonar (or gcovr)
#
# Usage: ./scripts/coverage-new-code.sh [threshold]
#   threshold: minimum coverage % (default: 80)
set -euo pipefail

THRESHOLD="${1:-80}"
COVERAGE_XML=".tmp/cov/coverage.xml"
BASE_BRANCH="main"

if [ ! -f "$COVERAGE_XML" ]; then
  echo "error: $COVERAGE_XML not found. Run 'make coverage' first, then:"
  echo "  gcovr .tmp/cov --sonarqube $COVERAGE_XML --root . --filter 'src/' --exclude '.*_test\\.cpp' --exclude 'vendor/'"
  exit 1
fi

python3 - "$COVERAGE_XML" "$BASE_BRANCH" "$THRESHOLD" << 'EOF'
import sys, re, subprocess
import xml.etree.ElementTree as ET

coverage_xml, base_branch, threshold = sys.argv[1], sys.argv[2], float(sys.argv[3])

# Get added line numbers per file from git diff
diff = subprocess.run(
    ['git', 'diff', '--unified=0', f'{base_branch}...HEAD', '--', 'src/'],
    capture_output=True, text=True
).stdout

current_file = None
new_lines = {}

for line in diff.split('\n'):
    m = re.match(r'^\+\+\+ b/(.*)', line)
    if m:
        current_file = m.group(1)
        new_lines.setdefault(current_file, set())
        continue
    m = re.match(r'^@@ .* \+(\d+)(?:,(\d+))? @@', line)
    if m:
        start, count = int(m.group(1)), int(m.group(2)) if m.group(2) else 1
        for i in range(start, start + count):
            new_lines[current_file].add(i)

# Check coverage XML for those lines
tree = ET.parse(coverage_xml)
total_new = covered_new = 0
uncovered = []

for f in tree.getroot().findall('.//file'):
    path = f.get('path')
    if path not in new_lines:
        continue
    for l in f.findall('lineToCover'):
        ln = int(l.get('lineNumber'))
        if ln in new_lines[path]:
            total_new += 1
            if l.get('covered') == 'true':
                covered_new += 1
            else:
                uncovered.append(f'{path}:{ln}')

pct = (covered_new * 100 / total_new) if total_new else 100
passed = pct >= threshold

print(f"\n  New Code Coverage (vs {base_branch})")
print(f"  {'─' * 40}")
print(f"  Executable new lines: {total_new}")
print(f"  Covered:              {covered_new}")
print(f"  Uncovered:            {total_new - covered_new}")
print(f"  Coverage:             {pct:.1f}%  (threshold: {threshold:.0f}%)")
print(f"  Status:               {'✅ PASS' if passed else '❌ FAIL'}")

if uncovered:
    print(f"\n  Uncovered new lines:")
    for u in uncovered[:20]:
        print(f"    {u}")
    if len(uncovered) > 20:
        print(f"    ... and {len(uncovered) - 20} more")

sys.exit(0 if passed else 1)
EOF
