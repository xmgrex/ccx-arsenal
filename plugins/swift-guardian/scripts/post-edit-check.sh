#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Swift Guardian: Post-Edit Convention Check
#
# After file edits, checks for:
#   1. UIKit usage where SwiftUI alternatives exist
#   2. Deprecated iOS API usage (below iOS 17 minimum)
#   3. Non-Swift 6 concurrency patterns
#
# Triggered by: PostToolUse on Edit|Write
# =============================================================================

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Guard: only .swift files
[[ -z "$file_path" ]]            && exit 0
[[ "$file_path" != *.swift ]]    && exit 0
[[ ! -f "$file_path" ]]         && exit 0

WARNINGS=()

# ---------------------------------------------------------------------------
# UIKit usage where SwiftUI alternatives exist
# ---------------------------------------------------------------------------
check_uikit() {
  local pattern="$1" swiftui_alt="$2"
  if grep -qE "$pattern" "$file_path" 2>/dev/null; then
    WARNINGS+=("UIKit '$pattern' detected — consider SwiftUI '$swiftui_alt' instead")
  fi
}

check_uikit 'UIViewController'    'View + NavigationStack'
check_uikit 'UITableView'         'List'
check_uikit 'UICollectionView'    'LazyVGrid / LazyHGrid'
check_uikit 'UINavigationController' 'NavigationStack'
check_uikit 'UITabBarController'  'TabView'
check_uikit 'UIAlertController'   '.alert() modifier'
check_uikit 'UIImagePickerController' 'PhotosPicker'
check_uikit 'UIActivityIndicatorView' 'ProgressView'

# ---------------------------------------------------------------------------
# Deprecated / pre-iOS 17 patterns
# ---------------------------------------------------------------------------
check_deprecated() {
  local pattern="$1" suggestion="$2"
  if grep -qE "$pattern" "$file_path" 2>/dev/null; then
    WARNINGS+=("$suggestion")
  fi
}

check_deprecated 'NavigationView'    'NavigationView is deprecated — use NavigationStack (iOS 16+)'
check_deprecated '\.onChange\(of:.*perform:' '.onChange(of:) with perform: is deprecated — use .onChange(of:) { oldValue, newValue in } (iOS 17+)'
check_deprecated '\.task\s*\{' ''  # .task is fine, skip
check_deprecated '@UIApplicationDelegateAdaptor' 'Consider pure SwiftUI lifecycle unless UIKit integration is required'

# ---------------------------------------------------------------------------
# Concurrency patterns (Swift 6 readiness)
# ---------------------------------------------------------------------------
if grep -qE 'DispatchQueue\.(main|global)' "$file_path" 2>/dev/null; then
  WARNINGS+=("DispatchQueue usage detected — prefer async/await and @MainActor for Swift 6 concurrency")
fi

if grep -qE '@objc\s+func' "$file_path" 2>/dev/null; then
  # Only warn in SwiftUI files, not intentional UIKit wrappers
  if grep -q 'import SwiftUI' "$file_path" 2>/dev/null; then
    WARNINGS+=("@objc func in SwiftUI file — consider Swift-native patterns")
  fi
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
[[ ${#WARNINGS[@]} -eq 0 ]] && exit 0

msg="Swift Convention Suggestion:"$'\n'
for w in "${WARNINGS[@]}"; do
  [[ -z "$w" ]] && continue
  msg+="  - ${w}"$'\n'
done
msg+=$'\n'"These are suggestions for SwiftUI-first, iOS 17+, Swift 6 conventions."

jq -n --arg msg "$msg" '{ "continue": true, "systemMessage": $msg }'
