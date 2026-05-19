#!/usr/bin/env bash
# changelog.sh — Generate changelog from conventional commits since last tag.
# @see ADR-129
set -o nounset
set -o pipefail

SINCE=$(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)
VERSION="${1:-Unreleased}"

echo "## [$VERSION] — $(date +%Y-%m-%d)"
echo ""

feats=$(git log --oneline "$SINCE"..HEAD --grep="^feat" | sed 's/^[a-f0-9]* /- /')
fixes=$(git log --oneline "$SINCE"..HEAD --grep="^fix" | sed 's/^[a-f0-9]* /- /')
refactors=$(git log --oneline "$SINCE"..HEAD --grep="^refactor" | sed 's/^[a-f0-9]* /- /')
docs=$(git log --oneline "$SINCE"..HEAD --grep="^docs" | sed 's/^[a-f0-9]* /- /')
ci=$(git log --oneline "$SINCE"..HEAD --grep="^ci" | sed 's/^[a-f0-9]* /- /')

[[ -n "$feats" ]] && echo "### Added" && echo "$feats" && echo ""
[[ -n "$fixes" ]] && echo "### Fixed" && echo "$fixes" && echo ""
[[ -n "$refactors" ]] && echo "### Changed" && echo "$refactors" && echo ""
[[ -n "$docs" ]] && echo "### Docs" && echo "$docs" && echo ""
[[ -n "$ci" ]] && echo "### CI" && echo "$ci" && echo ""
