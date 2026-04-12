#!/usr/bin/env bash
# Get git diff (latest commit or staged)
# Usage: !`${CLAUDE_PLUGIN_ROOT}/scripts/git-diff.sh`

echo "=== DIFF ==="
git diff HEAD~1 2>/dev/null || git diff --cached 2>/dev/null || echo "No diff available"

echo ""
echo "=== STATUS ==="
git status --short 2>/dev/null
