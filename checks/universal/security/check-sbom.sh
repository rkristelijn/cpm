#!/usr/bin/env bash
# check-sbom.sh — Generate Software Bill of Materials (CycloneDX).
#
# SBOM is required by EU Cyber Resilience Act (2024) and US EO 14028.
# Uses syft (preferred) or trivy to generate CycloneDX JSON.

source "$(dirname "$0")/../../../lib/shell/check.sh"
OUTPUT=".tmp/sbom.json"
mkdir -p .tmp

if command -v syft >/dev/null 2>&1; then
  syft dir:. -o cyclonedx-json="$OUTPUT" --quiet 2>&1
  count=$(grep -c '"bom-ref"' "$OUTPUT" 2>/dev/null || echo "0")
  echo "  ✓ SBOM generated: $count components ($OUTPUT)"
elif command -v trivy >/dev/null 2>&1; then
  trivy fs --format cyclonedx --output "$OUTPUT" . 2>/dev/null
  count=$(grep -c '"bom-ref"' "$OUTPUT" 2>/dev/null || echo "0")
  echo "  ✓ SBOM generated: $count components ($OUTPUT)"
else
  echo "  [skip] No SBOM tool installed (syft or trivy)"
  echo "    Install: brew install syft"
  exit 0
fi
