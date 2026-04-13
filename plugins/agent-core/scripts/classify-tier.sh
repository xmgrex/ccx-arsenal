#!/usr/bin/env bash
# Tier classification: Sprint Contract metadata → T1/T2/T3
# Usage: !`${CLAUDE_PLUGIN_ROOT}/scripts/classify-tier.sh --verifiability=<exec|manual> --risk=<layer> --surface=<int>`
#
# Rules (deterministic, LLM must NOT override this output):
#   T3 高: risk ∈ {auth, db, migration, api, security} OR surface >= 10
#   T1 低: verifiability=exec AND risk ∈ {doc, rename, config} AND surface <= 3
#   T2 中: 上記以外のすべて
#
# Output: key=value lines for context injection

verifiability=""
risk=""
surface=""

for arg in "$@"; do
  case "$arg" in
    --verifiability=*) verifiability="${arg#*=}" ;;
    --risk=*)          risk="${arg#*=}" ;;
    --surface=*)       surface="${arg#*=}" ;;
    *)
      echo "ERROR=unknown_argument: $arg" >&2
      echo "USAGE=--verifiability=<exec|manual> --risk=<doc|rename|config|logic|ui|api|auth|db|migration|security> --surface=<int>" >&2
      exit 2
      ;;
  esac
done

if [ -z "$verifiability" ] || [ -z "$risk" ] || [ -z "$surface" ]; then
  echo "ERROR=missing_required_argument" >&2
  echo "USAGE=--verifiability=<exec|manual> --risk=<layer> --surface=<int>" >&2
  exit 2
fi

case "$verifiability" in
  exec|manual) ;;
  *)
    echo "ERROR=invalid_verifiability: $verifiability" >&2
    echo "EXPECTED=exec|manual" >&2
    exit 2
    ;;
esac

case "$risk" in
  doc|rename|config|logic|ui|api|auth|db|migration|security) ;;
  *)
    echo "ERROR=invalid_risk_layer: $risk" >&2
    echo "EXPECTED=doc|rename|config|logic|ui|api|auth|db|migration|security" >&2
    exit 2
    ;;
esac

if ! [[ "$surface" =~ ^[0-9]+$ ]]; then
  echo "ERROR=invalid_surface: $surface (must be non-negative integer)" >&2
  exit 2
fi

# Tier decision (deterministic)
TIER="T2"
REASON="default middle tier"

# T3: high-risk layer OR large surface
case "$risk" in
  auth|db|migration|api|security)
    TIER="T3"
    REASON="risk_layer=$risk is high-risk"
    ;;
esac

if [ "$surface" -ge 10 ] && [ "$TIER" = "T2" ]; then
  TIER="T3"
  REASON="surface=$surface exceeds threshold 10"
fi

# T1: low-risk AND small surface AND exec verifiable (only if not already bumped to T3)
if [ "$TIER" = "T2" ] && [ "$verifiability" = "exec" ] && [ "$surface" -le 3 ]; then
  case "$risk" in
    doc|rename|config)
      TIER="T1"
      REASON="exec + low-risk layer + surface<=3"
      ;;
  esac
fi

echo "TIER=$TIER"
echo "REASON=$REASON"
echo "VERIFIABILITY=$verifiability"
echo "RISK_LAYER=$risk"
echo "SURFACE=$surface"
