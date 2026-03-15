#!/usr/bin/env bash
# Meridian status line for Claude Code
# Shows Meridian-specific data: decision quality from last session.
# Installed by: meridian init / meridian update

input=$(cat)

STATS_FILE="$HOME/.claude/meridian/session-stats.json"

if [ -f "$STATS_FILE" ] && command -v jq &>/dev/null; then
  DECISIONS=$(jq -r '.decisions // 0' "$STATS_FILE" 2>/dev/null)
  RICH=$(jq -r '.rich // 0' "$STATS_FILE" 2>/dev/null)
  THIN=$(jq -r '.thin // 0' "$STATS_FILE" 2>/dev/null)
  DATE=$(jq -r '.session_date // ""' "$STATS_FILE" 2>/dev/null)
  if [ "$DECISIONS" -gt 0 ] 2>/dev/null; then
    echo "Meridian | last: ${DECISIONS} decisions (${RICH} rich, ${THIN} thin) ${DATE}"
  else
    echo "Meridian"
  fi
else
  echo "Meridian"
fi
