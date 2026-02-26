#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Flutter Riverpod Clean Architecture Compliance Checker
#
# Each layer has strict dependency rules:
#   Domain       -> No external dependencies (pure Dart only)
#   Data         -> Domain only (no Flutter, no Riverpod)
#   Application  -> Domain + Data (flutter_riverpod allowed, no Flutter UI)
#   Presentation -> Application + Domain (no direct Data access)
#
# Usage:
#   Hook mode:  Called automatically via Claude Code PostToolUse hook
#   Scan mode:  ./check-architecture.sh --scan <lib_directory>
# =============================================================================

VIOLATIONS=()

# ---------------------------------------------------------------------------
# Pattern checker
# ---------------------------------------------------------------------------
check_pattern() {
  local file="$1" pattern="$2" message="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    VIOLATIONS+=("$message")
  fi
}

# ---------------------------------------------------------------------------
# Layer-specific checks for a single file
# ---------------------------------------------------------------------------
check_file() {
  local file_path="$1"
  local display_name="${2:-$(basename "$file_path")}"

  # Guard: only .dart, skip generated, skip missing
  [[ "$file_path" != *.dart ]]          && return 0
  [[ "$file_path" == *.freezed.dart ]]  && return 0
  [[ "$file_path" == *.g.dart ]]        && return 0
  [[ ! -f "$file_path" ]]              && return 0

  # Determine layer
  local layer=""
  case "$file_path" in
    */domain/*)       layer="domain" ;;
    */data/*)         layer="data" ;;
    */application/*)  layer="application" ;;
    */presentation/*) layer="presentation" ;;
    *) return 0 ;;
  esac

  # --- Domain Layer: pure Dart only -------------------------------------------
  if [[ "$layer" == "domain" ]]; then
    check_pattern "$file_path" "^import.*package:flutter/" \
      "[${display_name}] Domain: package:flutter/ import prohibited"
    check_pattern "$file_path" "^import.*package:flutter_riverpod/" \
      "[${display_name}] Domain: flutter_riverpod import prohibited"
    check_pattern "$file_path" "^import.*package:riverpod" \
      "[${display_name}] Domain: riverpod import prohibited"
    check_pattern "$file_path" "^import.*package:cloud_firestore/" \
      "[${display_name}] Domain: cloud_firestore import prohibited"
    check_pattern "$file_path" "^import.*package:firebase_" \
      "[${display_name}] Domain: firebase package import prohibited"
    check_pattern "$file_path" "^import.*package:http/" \
      "[${display_name}] Domain: http package import prohibited"
    check_pattern "$file_path" "^import.*package:dio/" \
      "[${display_name}] Domain: dio package import prohibited"
  fi

  # --- Data Layer: no Flutter, no Riverpod, no platform constants -------------
  if [[ "$layer" == "data" ]]; then
    check_pattern "$file_path" "^import.*package:flutter/" \
      "[${display_name}] Data: package:flutter/ import prohibited"
    check_pattern "$file_path" "^import.*package:flutter_riverpod/" \
      "[${display_name}] Data: flutter_riverpod import prohibited"
    check_pattern "$file_path" "^import.*package:riverpod" \
      "[${display_name}] Data: riverpod import prohibited"
    check_pattern "$file_path" "\bkIsWeb\b" \
      "[${display_name}] Data: kIsWeb direct use prohibited (inject via constructor)"
    check_pattern "$file_path" "\bBuildContext\b" \
      "[${display_name}] Data: BuildContext use prohibited"
  fi

  # --- Application Layer: flutter_riverpod OK, no Flutter UI ------------------
  if [[ "$layer" == "application" ]]; then
    check_pattern "$file_path" "^import.*package:flutter/" \
      "[${display_name}] Application: package:flutter/ import prohibited (use package:flutter_riverpod/ instead)"
    check_pattern "$file_path" "\bBuildContext\b" \
      "[${display_name}] Application: BuildContext use prohibited"
    check_pattern "$file_path" "\bNavigator\b" \
      "[${display_name}] Application: Navigator use prohibited"
    check_pattern "$file_path" "\bshowDialog\b" \
      "[${display_name}] Application: showDialog use prohibited"
    check_pattern "$file_path" "\bScaffoldMessenger\b" \
      "[${display_name}] Application: ScaffoldMessenger use prohibited"
  fi

  # --- Presentation Layer: no direct Data access, no widget methods -----------
  if [[ "$layer" == "presentation" ]]; then
    check_pattern "$file_path" "^import.*\/data\/.*_repository" \
      "[${display_name}] Presentation: direct repository import prohibited (use Application providers)"
    check_pattern "$file_path" "^[[:space:]]*Widget[[:space:]]+_build" \
      "[${display_name}] Presentation: _buildXxx() methods prohibited (extract to Widget classes)"
  fi
}

# ---------------------------------------------------------------------------
# Hook mode: triggered by Claude Code PostToolUse
# ---------------------------------------------------------------------------
hook_mode() {
  local input file_path
  input=$(cat)
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

  [[ -z "$file_path" ]] && exit 0

  check_file "$file_path"

  [[ ${#VIOLATIONS[@]} -eq 0 ]] && exit 0

  # Build feedback message for Claude
  local msg
  msg="Architecture Violation Detected:"$'\n'
  for v in "${VIOLATIONS[@]}"; do
    msg+="  - ${v}"$'\n'
  done
  msg+=$'\n'"Fix these violations to maintain clean architecture compliance."

  jq -n --arg msg "$msg" '{ "continue": true, "systemMessage": $msg }'
}

# ---------------------------------------------------------------------------
# Scan mode: check entire directory
# ---------------------------------------------------------------------------
scan_mode() {
  local target_dir="$1"
  local checked=0

  if [[ ! -d "$target_dir" ]]; then
    echo "Error: directory not found: $target_dir" >&2
    exit 1
  fi

  echo "Scanning: $target_dir"
  echo "========================================="

  while IFS= read -r -d '' file; do
    local rel_path="${file#"$target_dir"/}"
    check_file "$file" "$rel_path"
    ((checked++)) || true
  done < <(find "$target_dir" -name "*.dart" \
    ! -name "*.freezed.dart" \
    ! -name "*.g.dart" \
    -print0 2>/dev/null)

  echo ""
  echo "Results: ${checked} files checked, ${#VIOLATIONS[@]} violations"
  echo ""

  if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
    echo "All clean architecture rules satisfied."
    exit 0
  fi

  echo "Violations:"
  for v in "${VIOLATIONS[@]}"; do
    echo "  - $v"
  done
  exit 1
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--scan" ]]; then
  scan_mode "${2:?Usage: $0 --scan <lib_directory>}"
else
  hook_mode
fi
