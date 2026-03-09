#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Flutter Guardian: Pre-Commit Lint Hook
#
# Intercepts `git commit` commands and runs `dart analyze` first.
# If analysis finds issues, warns Claude via systemMessage.
#
# Triggered by: PreToolUse on Bash tool
# =============================================================================

input=$(cat)

# Extract the command being run
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only act on git commit commands
if ! echo "$command" | grep -qE '^\s*git\s+commit'; then
  exit 0
fi

# Check if we're in a Flutter/Dart project
if [[ ! -f "pubspec.yaml" ]]; then
  exit 0
fi

# Run dart analyze
analyze_output=$(dart analyze --no-fatal-warnings 2>&1) || true

# Count issues (errors and warnings)
error_count=$(echo "$analyze_output" | grep -cE '^\s*(error|warning)\s+' 2>/dev/null || echo "0")

if [[ "$error_count" -gt 0 ]]; then
  msg="⚠ dart analyze found ${error_count} issue(s) before commit:"$'\n'
  msg+="$(echo "$analyze_output" | grep -E '^\s*(error|warning)\s+' | head -10)"$'\n'
  msg+=$'\n'"Fix these issues before committing, or acknowledge them explicitly."

  jq -n --arg msg "$msg" '{ "continue": true, "systemMessage": $msg }'
else
  exit 0
fi
