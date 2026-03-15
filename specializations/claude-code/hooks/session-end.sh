#!/usr/bin/env bash
# Meridian session-end hook
# Runs incremental conversation indexing with journal export after each session.
# Extracted decisions get written to the journal directory so they sync via git
# and the container's journal indexer picks them up.

set -euo pipefail

# Skip export for worker agents in multi-agent swarms.
# Set MERIDIAN_SKIP_EXPORT=1 when spawning worker agents so only the
# orchestrator's decisions flow into the journal.
if [ "${MERIDIAN_SKIP_EXPORT:-}" = "1" ]; then
  exit 0
fi

# Find meridian binary
MERIDIAN="$(command -v meridian 2>/dev/null || echo "")"
if [ -z "$MERIDIAN" ]; then
  # Try npx
  if command -v npx &>/dev/null; then
    MERIDIAN="npx --yes meridian-dev"
  else
    exit 0
  fi
fi

# Run incremental reindex (conversations only — journals are handled by the journal write itself)
# --conversations-only: skip journals (just written by the session, no need to re-index)
# --export: write extracted decisions as journal entries for git sync
# --detect-shifts: auto-update state files when significant context shifts are detected
# --write-stats: write session stats JSON for status line display
$MERIDIAN reindex --conversations-only --export --detect-shifts --write-stats 2>/dev/null || true

# Sync authored journals to team-context repo (commit + push)
# This makes local journals available to the container and other team members
$MERIDIAN journal sync 2>/dev/null || true
