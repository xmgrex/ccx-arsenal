#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Swift Guardian: Pre-Commit Build Check
#
# Intercepts `git commit` and runs `swift build` to catch compile errors.
# Supports both Swift Package Manager and XcodeGen projects.
#
# Triggered by: PreToolUse on Bash tool
# =============================================================================

input=$(cat)

command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only act on git commit commands
if ! echo "$command" | grep -qE '^\s*git\s+commit'; then
  exit 0
fi

# Check if we're in a Swift project
if [[ ! -f "Package.swift" ]] && [[ ! -f "project.yml" ]]; then
  exit 0
fi

# Try swift build for SPM projects
if [[ -f "Package.swift" ]]; then
  build_output=$(swift build 2>&1) || true
  error_count=$(echo "$build_output" | grep -c 'error:' 2>/dev/null || echo "0")

  if [[ "$error_count" -gt 0 ]]; then
    msg="⚠ swift build found ${error_count} error(s) before commit:"$'\n'
    msg+="$(echo "$build_output" | grep 'error:' | head -10)"$'\n'
    msg+=$'\n'"Fix build errors before committing."

    jq -n --arg msg "$msg" '{ "continue": true, "systemMessage": $msg }'
    exit 0
  fi
fi

# For XcodeGen projects, check if xcodegen is needed
if [[ -f "project.yml" ]]; then
  # Check if .xcodeproj exists and is up to date
  xcodeproj=$(find . -maxdepth 1 -name "*.xcodeproj" -print -quit 2>/dev/null || true)
  if [[ -z "$xcodeproj" ]]; then
    msg="⚠ project.yml exists but no .xcodeproj found. Run 'xcodegen' before committing."
    jq -n --arg msg "$msg" '{ "continue": true, "systemMessage": $msg }'
    exit 0
  fi
fi

exit 0
