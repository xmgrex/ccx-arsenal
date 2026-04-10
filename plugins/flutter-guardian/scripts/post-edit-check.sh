#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Flutter Guardian: Post-Edit Check
#
# After file edits, checks for:
#   1. Custom widget implementations that could use enn design system components
#   2. Direct Material widget usage where enn alternatives exist
#
# Triggered by: PostToolUse on Edit|Write
# =============================================================================

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Guard: only .dart files in a Flutter project
[[ -z "$file_path" ]]            && exit 0
[[ "$file_path" != *.dart ]]     && exit 0
[[ ! -f "pubspec.yaml" ]]       && exit 0
[[ ! -f "$file_path" ]]         && exit 0

# Skip generated files
[[ "$file_path" == *.freezed.dart ]] && exit 0
[[ "$file_path" == *.g.dart ]]      && exit 0

# --- Auto-format ---
dart format "$file_path" 2>/dev/null || true

# Check if enn is a dependency
if ! grep -q 'enn:' pubspec.yaml 2>/dev/null; then
  exit 0
fi

SUGGESTIONS=()

# --- Check for Material widgets that have enn alternatives ---

check_enn_alternative() {
  local pattern="$1" enn_name="$2"
  if grep -qE "$pattern" "$file_path" 2>/dev/null; then
    # Don't flag if it's inside the enn package itself
    if [[ "$file_path" != *"/enn/"* ]]; then
      SUGGESTIONS+=("Consider using $enn_name instead of Material $pattern")
    fi
  fi
}

check_enn_alternative '\bBottomSheet\b'        'EnnBottomSheet'
check_enn_alternative '\bAlertDialog\b'        'EnnDialog'
check_enn_alternative '\bElevatedButton\b'     'EnnButton'
check_enn_alternative '\bOutlinedButton\b'     'EnnButton'
check_enn_alternative '\bTextButton\b'         'EnnButton / EnnTextButton'
check_enn_alternative '\bPopupMenuButton\b'    'EnnMenu'
check_enn_alternative '\bDropdownButton\b'     'EnnDropdown'
check_enn_alternative '\bListTile\b'           'EnnSettingsItem / EnnListItem'
check_enn_alternative '\bSnackBar\b'           'EnnToast'
check_enn_alternative '\bCircularProgressIndicator\b' 'EnnLoading'

[[ ${#SUGGESTIONS[@]} -eq 0 ]] && exit 0

msg="enn Design System Suggestion:"$'\n'
for s in "${SUGGESTIONS[@]}"; do
  msg+="  - ${s}"$'\n'
done
msg+=$'\n'"These are suggestions, not violations. Use enn components for visual consistency."

jq -n --arg msg "$msg" '{ "continue": true, "systemMessage": $msg }'
