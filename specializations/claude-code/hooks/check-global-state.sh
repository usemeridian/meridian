#!/usr/bin/env bash
# Meridian — Rebuild Active Projects + version check on session start.
# Rebuilds the Active Projects table from per-repo state files (idempotent,
# concurrent-safe), then checks if the installed version meets the team
# minimum configured in the team-context repo's meridian.json.
#
# Install: copy to ~/.claude/hooks/check-global-state.sh
# Register: add to ~/.claude/settings.json (see settings.json in this directory)

set -euo pipefail

# Use local meridian checkout if available, otherwise try npx
MERIDIAN_BIN="$HOME/repos/greg/meridian/bin/meridian.js"
if [ -f "$MERIDIAN_BIN" ]; then
    node "$MERIDIAN_BIN" status --write --quiet 2>/dev/null || true
    node "$MERIDIAN_BIN" check-version 2>/dev/null || true
elif command -v meridian >/dev/null 2>&1; then
    meridian status --write --quiet 2>/dev/null || true
    meridian check-version 2>/dev/null || true
fi
