#!/usr/bin/env bash
# scripts/sonar-download.sh — download SonarCloud feedback for any public project
set -o errexit -o nounset -o pipefail

BASE_URL="https://sonarcloud.io/api"

# --- Resolve project key ---

resolve_project_key() {
  # 1. Explicit argument
  if [ -n "${1:-}" ]; then echo "$1"; return; fi

  # 2. sonar-project.properties in current repo
  local props="sonar-project.properties"
  if [ -f "$props" ]; then
    grep -m1 '^sonar.projectKey=' "$props" | cut -d= -f2
    return
  fi

  # 3. Derive from git remote (org_repo)
  local remote
  remote=$(git remote get-url origin 2>/dev/null || true)
  if [ -n "$remote" ]; then
    echo "$remote" | sed -E 's#.*/([^/]+)/([^/.]+)(\.git)?$#\1_\2#'
    return
  fi

  echo "Error: cannot determine project key. Pass it as argument." >&2
  exit 1
}

PROJECT_KEY=$(resolve_project_key "${1:-}")
OUTPUT_DIR="${2:-.tmp/sonar}"
mkdir -p "$OUTPUT_DIR"

echo "=== SonarCloud Report: $PROJECT_KEY ==="
echo "Output: $OUTPUT_DIR"
echo

# --- Fetch functions ---

fetch() {
  curl -sf "$BASE_URL/$1" || { echo "Error fetching $1" >&2; return 1; }
}

# --- Measures ---

echo "Fetching measures..."
fetch "measures/component?component=$PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,ncloc,reliability_rating,security_rating,sqale_rating,alert_status,cognitive_complexity,sqale_debt_ratio,security_hotspots" \
  > "$OUTPUT_DIR/measures.json"

# --- Quality Gate ---

echo "Fetching quality gate..."
fetch "qualitygates/project_status?projectKey=$PROJECT_KEY" \
  > "$OUTPUT_DIR/quality-gate.json"

# --- Issues (paginated) ---

echo "Fetching issues..."
page=1
total=1
fetched=0
> "$OUTPUT_DIR/issues.json"

while [ "$fetched" -lt "$total" ]; do
  response=$(fetch "issues/search?componentKeys=$PROJECT_KEY&ps=500&p=$page&types=CODE_SMELL,BUG,VULNERABILITY")
  if [ $page -eq 1 ]; then
    total=$(echo "$response" | python3 -c "import json,sys;print(json.load(sys.stdin)['total'])")
    echo "  Total issues: $total"
  fi
  echo "$response" >> "$OUTPUT_DIR/issues-page-$page.json"
  count=$(echo "$response" | python3 -c "import json,sys;print(len(json.load(sys.stdin)['issues']))")
  fetched=$((fetched + count))
  page=$((page + 1))
  [ "$fetched" -ge "$total" ] && break
  [ $page -gt 20 ] && break  # safety limit
done

# --- Security Hotspots ---

echo "Fetching security hotspots..."
fetch "hotspots/search?projectKey=$PROJECT_KEY&ps=500&status=TO_REVIEW" \
  > "$OUTPUT_DIR/hotspots.json"

# --- Generate summary ---

echo "Generating summary..."
python3 - "$OUTPUT_DIR" <<'PYTHON'
import json, sys, os

d = sys.argv[1]

def load(name):
    path = os.path.join(d, name)
    if not os.path.exists(path): return {}
    with open(path) as f: return json.load(f)

# Measures
measures = {}
for m in load("measures.json").get("component", {}).get("measures", []):
    measures[m["metric"]] = m["value"]

# Quality gate
qg = load("quality-gate.json").get("projectStatus", {})

# Issues per severity
issues_by_severity = {}
issues_by_file = {}
page = 1
while True:
    path = os.path.join(d, f"issues-page-{page}.json")
    if not os.path.exists(path): break
    with open(path) as f: data = json.load(f)
    for i in data.get("issues", []):
        sev = i.get("severity", "UNKNOWN")
        issues_by_severity[sev] = issues_by_severity.get(sev, 0) + 1
        comp = i.get("component", "").split(":")[-1]
        issues_by_file.setdefault(comp, []).append(i)
    page += 1

# Hotspots
hotspots = load("hotspots.json").get("hotspots", [])

# Write summary
with open(os.path.join(d, "summary.md"), "w") as out:
    out.write(f"# SonarCloud Summary\n\n")
    out.write(f"## Quality Gate: {qg.get('status', 'UNKNOWN')}\n\n")

    if qg.get("conditions"):
        out.write("| Condition | Status | Value | Threshold |\n")
        out.write("|-----------|--------|-------|----------|\n")
        for c in qg["conditions"]:
            out.write(f"| {c['metricKey']} | {c['status']} | {c.get('actualValue','-')} | {c.get('errorThreshold','-')} |\n")
        out.write("\n")

    out.write("## Measures\n\n")
    out.write("| Metric | Value |\n|--------|-------|\n")
    for k, v in sorted(measures.items()):
        out.write(f"| {k} | {v} |\n")
    out.write("\n")

    out.write("## Issues by Severity\n\n")
    out.write("| Severity | Count |\n|----------|-------|\n")
    for sev in ["BLOCKER","CRITICAL","MAJOR","MINOR","INFO"]:
        if sev in issues_by_severity:
            out.write(f"| {sev} | {issues_by_severity[sev]} |\n")
    out.write(f"\n**Total: {sum(issues_by_severity.values())}**\n\n")

    out.write("## Top Files by Issue Count\n\n")
    out.write("| File | Issues |\n|------|--------|\n")
    for f, issues in sorted(issues_by_file.items(), key=lambda x: -len(x[1]))[:20]:
        out.write(f"| {f} | {len(issues)} |\n")
    out.write("\n")

    if hotspots:
        out.write(f"## Security Hotspots (TO_REVIEW): {len(hotspots)}\n\n")
        out.write("| File | Message | Line |\n|------|---------|------|\n")
        for h in hotspots:
            comp = h.get("component", "").split(":")[-1]
            out.write(f"| {comp} | {h.get('message','')} | {h.get('line','')} |\n")
        out.write("\n")

print(f"  Written: {os.path.join(d, 'summary.md')}")
PYTHON

echo
echo "Done. Files in $OUTPUT_DIR:"
ls -1 "$OUTPUT_DIR"
