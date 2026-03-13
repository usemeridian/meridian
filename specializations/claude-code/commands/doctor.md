---
description: Run Meridian health check — validates hooks, state files, backup status, and memory file sizes.
---

# Meridian — Doctor

Run a health check on the memory system.

## Step 1: Check if doctor.sh is available

Look for `~/.claude/meridian/doctor.sh`. If found, run it:
```bash
bash ~/.claude/meridian/doctor.sh
```

If not found, perform the checks manually:

## Step 2: Manual checks

1. **Hook registered?** — Does `~/.claude/settings.json` contain "check-global-state"?
2. **Global state current?** — Read `~/.claude/global-state.md`. When was it last updated?
3. **Backup status** — Check `~/.claude/.backup-last-push` and `~/.claude/.backup-last-error`
4. **Repos** — Scan `~/repos`, `~/code`, `~/dev` for `.claude/state.md` files
5. **Memory files** — List files in `~/.claude/memory/`, flag any over 8KB

## Step 3: Report findings

Report in this format:
- ✓ items that are working correctly
- ⚠ items that need attention (not broken, but worth knowing)
- ✗ items that are broken (with how to fix)
