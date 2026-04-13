#!/usr/bin/env bash
# Cold-start threshold check: determines if tier classification should be active or frozen to T2
# Usage: !`${CLAUDE_PLUGIN_ROOT}/scripts/cold-start-check.sh`
#
# Rule: cold-start protection is ACTIVE (force T2) until BOTH thresholds are exceeded:
#   - .agent-core/sprints/*.json count >= 20
#   - .agent-core/gotchas/archive/ entry count >= 10 (post-mortem accumulation)
# Either-or: once EITHER is met, cold-start ends (first-to-hit wins)
#
# Output: key=value lines for context injection

SPRINTS_DIR=".agent-core/sprints"
GOTCHAS_ARCHIVE=".agent-core/gotchas/archive"

sprint_count=0
if [ -d "$SPRINTS_DIR" ]; then
  sprint_count=$(find "$SPRINTS_DIR" -maxdepth 1 -name 'S-*.json' -type f 2>/dev/null | wc -l | tr -d ' ')
fi

gotcha_count=0
if [ -d "$GOTCHAS_ARCHIVE" ]; then
  gotcha_count=$(find "$GOTCHAS_ARCHIVE" -maxdepth 2 -name '*.md' -type f 2>/dev/null -exec grep -l '^\- \[' {} \; 2>/dev/null | wc -l | tr -d ' ')
fi

SPRINT_THRESHOLD=20
GOTCHA_THRESHOLD=10

COLD_START_ACTIVE="true"
REASON="neither threshold met"

if [ "$sprint_count" -ge "$SPRINT_THRESHOLD" ]; then
  COLD_START_ACTIVE="false"
  REASON="sprint_count=$sprint_count >= threshold=$SPRINT_THRESHOLD"
elif [ "$gotcha_count" -ge "$GOTCHA_THRESHOLD" ]; then
  COLD_START_ACTIVE="false"
  REASON="gotcha_count=$gotcha_count >= threshold=$GOTCHA_THRESHOLD"
fi

echo "COLD_START_ACTIVE=$COLD_START_ACTIVE"
echo "REASON=$REASON"
echo "SPRINT_COUNT=$sprint_count"
echo "SPRINT_THRESHOLD=$SPRINT_THRESHOLD"
echo "GOTCHA_COUNT=$gotcha_count"
echo "GOTCHA_THRESHOLD=$GOTCHA_THRESHOLD"

if [ "$COLD_START_ACTIVE" = "true" ]; then
  echo "FORCED_TIER=T2"
  echo "NOTE=cold-start protection: all sprints run as T2 until thresholds met"
else
  echo "FORCED_TIER="
  echo "NOTE=tier classification is active (cold-start ended)"
fi
