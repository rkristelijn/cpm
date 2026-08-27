#!/usr/bin/env bash
# checks/universal/quality/check-readme-structure.sh
# @see ADR-129
# Check README.md for completeness: existence, structure, setup, testing, deploy info
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "readme-structure" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
README="$REPO/README.md"

# Rule 1: readme-missing — No README.md at all
if [ ! -f "$README" ]; then
  findings_add "error" "$README" "readme-missing" \
    "No README.md in project root" \
    "Create a README.md with project description, setup, and usage instructions" \
    "https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes"
  # No point checking further
  exit 0
fi

CONTENT=$(cat "$README")
LINE_COUNT=$(wc -l < "$README" | tr -d ' ')

# Rule 7: readme-too-short — Under 10 lines
if [ "$LINE_COUNT" -lt 10 ]; then
  findings_add "warning" "$README" "readme-too-short" \
    "README.md has only $LINE_COUNT lines (minimum 10)" \
    "Add project description, setup instructions, and usage examples" \
    ""
fi

# Rule 2: readme-template — Still a default template (GitHub/GitLab boilerplate)
TEMPLATE_PATTERNS="Getting Started with Create React App|This project was bootstrapped|# Getting started.*To make it easy|## Add your files|## Getting started.*These instructions will get you a copy|This README.md file is auto-generated|## Description.*Provide a short|An awesome README template|# Welcome to your new project"
if echo "$CONTENT" | head -30 | grep -qiE "$TEMPLATE_PATTERNS" 2>/dev/null; then
  findings_add "warning" "$README" "readme-template" \
    "README.md appears to be a default template — customize it for your project" \
    "Replace boilerplate with actual project description, setup, and usage" \
    ""
fi

# Rule 3: readme-no-context — First 20 lines lack a project description
# A good README has descriptive text (not just a title or badges) in the first 20 lines
HEAD_20=$(head -20 "$README")
# Count non-empty, non-heading, non-badge, non-link-only lines in first 20 lines
DESCRIPTION_LINES=$(echo "$HEAD_20" | grep -cvE '^\s*$|^#|^\[!\[|^!\[|^\|' 2>/dev/null || echo "0")
if [ "$DESCRIPTION_LINES" -lt 1 ]; then
  findings_add "warning" "$README" "readme-no-context" \
    "First 20 lines have no project description — readers don't know what this does" \
    "Add a one-liner or short paragraph describing what the project does and why" \
    ""
fi

# Rule 4: readme-no-setup — No install/setup/run/start instructions
SETUP_PATTERN="[Ii]nstall|[Ss]etup|[Gg]etting [Ss]tarted|[Qq]uick [Ss]tart|[Hh]ow to [Rr]un|[Hh]ow to [Uu]se|npm install|pip install|brew install|cargo install|make install|apt install|yarn add|go get|gem install|composer install|## Usage|## Run"
if ! echo "$CONTENT" | grep -qE "$SETUP_PATTERN" 2>/dev/null; then
  findings_add "warning" "$README" "readme-no-setup" \
    "No install/setup/run instructions found in README" \
    "Add a section explaining how to install and run the project" \
    ""
fi

# Rule 5: readme-no-testing — No test/validate/lint/build instructions
TESTING_PATTERN="[Tt]est|[Vv]alidat|[Ll]int|[Bb]uild|make test|npm test|pytest|cargo test|go test|mvn test|gradle test|jest|mocha|rspec"
if ! echo "$CONTENT" | grep -qE "$TESTING_PATTERN" 2>/dev/null; then
  findings_add "warning" "$README" "readme-no-testing" \
    "No test/build/lint instructions found in README" \
    "Add a section explaining how to test and validate the project" \
    ""
fi

# Rule 6: readme-no-deploy — No release/deploy/publish information
DEPLOY_PATTERN="[Dd]eploy|[Rr]elease|[Pp]ublish|[Cc][ID]/[Cc][Dd]|[Pp]ipeline|[Pp]roduction|docker push|npm publish|cargo publish|make deploy|make release|## Deploy|## Release"
if ! echo "$CONTENT" | grep -qE "$DEPLOY_PATTERN" 2>/dev/null; then
  findings_add "info" "$README" "readme-no-deploy" \
    "No deploy/release/publish information found in README" \
    "Add a section about deployment or release process" \
    ""
fi
