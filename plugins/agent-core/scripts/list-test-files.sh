#!/usr/bin/env bash
# List test files (stack-agnostic)
# Usage: !`${CLAUDE_PLUGIN_ROOT}/scripts/list-test-files.sh`

find . \( \
  -name "*_test.*" \
  -o -name "*.test.*" \
  -o -name "*.spec.*" \
  -o -name "test_*" \
\) \
  -not -path "*/node_modules/*" \
  -not -path "*/.build/*" \
  -not -path "*/build/*" \
  -not -path "*/.dart_tool/*" \
  -not -path "*/Pods/*" \
  -not -path "*/.gradle/*" \
  -not -path "*/target/*" \
  2>/dev/null | head -30
