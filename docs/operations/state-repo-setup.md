# State Repository Setup

Meridian stores all context in plain markdown files under `~/.claude/` and `<repo>/.claude/`. These files are local by default — they live on your machine. This document covers how to back them up, share them across machines, and aggregate them for team digests.

---

## The Two Repo Pattern

Meridian state uses two git repos beyond the project repos themselves:

1. **Personal state backup repo** (private) — backs up your `~/.claude/` directory to a private git repo. Gives you: disaster recovery, multi-machine sync, and version history of your own context.

2. **Team context repo** (org-level, shared) — aggregates journal entries and team state from all contributors. Gives you: digest generation from the full team's sessions, shared context that persists across contributor turnover, and the raw material for cross-persona digests.

These are separate because personal state includes settings, credentials references, and working notes that should never be shared. Team context includes only the journals and team-state files that feed digests.

---

## Personal State Backup Repo

### What it backs up

| File | Description |
|------|-------------|
| `~/.claude/global-state.md` | Project index, preferences, memory file manifest |
| `~/.claude/state.md` | Admin/non-repo working state |
| `~/.claude/settings.json` | Claude Code settings (hooks, permissions) |
| `~/.claude/settings.local.json` | Local overrides (gitignored in Claude but backed up here) |
| `~/.claude/memory/` | All topic memory files + daily journals |
| `~/.claude/commands/` | Custom slash commands |
| `~/.claude/hooks/` | Session hooks (bash scripts) |
| `<repo>/.claude/state.md` | Per-repo state files (gitignored in their repos) |

### Setup

**Automated:** Meridian ships a setup script that handles cloning, initial sync, hook installation, and hook registration in one command:

```bash
# 1. Create a private repo on GitHub (MANUAL — you do this yourself)
#    e.g., github.com/youruser/claude-state (private)

# 2. Run the Meridian backup setup (AUTOMATED — does steps 2-4 for you)
bash backup/setup.sh git@github.com:youruser/claude-state.git
```

This clones the repo to `~/.claude-backup/`, runs an initial sync, installs session hooks, and registers them in `~/.claude/settings.json`.

The manual steps below show what the setup script does under the hood, for reference.

### Sync script (reference)

> **Note:** This is a reference implementation showing the sync logic. Meridian ships its own hook scripts in `backup/hooks/` (`session-start.sh` and `session-end.sh`) that are installed automatically by `backup/setup.sh`. You do not need to create this script manually.

The sync script copies files between `~/.claude/` and the backup repo. Two modes: `backup` (local → repo) and `restore` (repo → local).

```bash
#!/usr/bin/env bash
# sync.sh — backup or restore ~/.claude/ state
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

backup() {
    # Core state files
    cp "$CLAUDE_DIR/global-state.md" "$REPO_DIR/global-state.md"
    cp "$CLAUDE_DIR/state.md" "$REPO_DIR/state.md"
    cp "$CLAUDE_DIR/settings.json" "$REPO_DIR/settings.json"
    cp "$CLAUDE_DIR/settings.local.json" "$REPO_DIR/settings.local.json"

    # Memory files (full sync)
    rsync -av --delete "$CLAUDE_DIR/memory/" "$REPO_DIR/memory/"

    # Custom commands
    rsync -av "$CLAUDE_DIR/commands/" "$REPO_DIR/commands/"

    # Hooks
    rsync -av "$CLAUDE_DIR/hooks/" "$REPO_DIR/hooks/"

    # Per-repo state files (gitignored in their repos, backed up here)
    mkdir -p "$REPO_DIR/repo-state"
    for state_file in $(find "$HOME/repos" -path '*/.claude/state.md' \
        -not -path "*/claude-state/*" 2>/dev/null); do
        rel_path="${state_file#$HOME/repos/}"
        dir_path="$REPO_DIR/repo-state/$(dirname "$rel_path")"
        mkdir -p "$dir_path"
        cp "$state_file" "$dir_path/state.md"
    done

    echo "Backup complete."
}

restore() {
    # Core state files
    cp "$REPO_DIR/global-state.md" "$CLAUDE_DIR/global-state.md"
    cp "$REPO_DIR/state.md" "$CLAUDE_DIR/state.md"
    cp "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    cp "$REPO_DIR/settings.local.json" "$CLAUDE_DIR/settings.local.json"

    # Memory files
    mkdir -p "$CLAUDE_DIR/memory/journal"
    rsync -av "$REPO_DIR/memory/" "$CLAUDE_DIR/memory/"

    # Custom commands
    mkdir -p "$CLAUDE_DIR/commands"
    rsync -av "$REPO_DIR/commands/" "$CLAUDE_DIR/commands/"

    # Hooks
    mkdir -p "$CLAUDE_DIR/hooks"
    rsync -av "$REPO_DIR/hooks/" "$CLAUDE_DIR/hooks/"
    chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true

    # Per-repo state files
    if [ -d "$REPO_DIR/repo-state" ]; then
        for state_file in $(find "$REPO_DIR/repo-state" -name 'state.md' 2>/dev/null); do
            rel_path="${state_file#$REPO_DIR/repo-state/}"
            target="$HOME/repos/$(dirname "$rel_path")/state.md"
            if [ -d "$(dirname "$(dirname "$target")")" ]; then
                mkdir -p "$(dirname "$target")"
                cp "$state_file" "$target"
            fi
        done
    fi

    echo "Restore complete."
}

case "${1:-}" in
    backup)  backup ;;
    restore) restore ;;
    *)       echo "Usage: $0 {backup|restore}"; exit 1 ;;
esac
```

### Automating backup via session hooks

> **Note:** If you ran `backup/setup.sh`, the hooks below are already installed and registered. This section shows the hook configuration for reference — no manual editing needed.

Add to `~/.claude/settings.json` under `hooks`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "cd ~/repos/personal/claude-state && git pull --quiet && ./sync.sh restore"}
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "cd ~/repos/personal/claude-state && ./sync.sh backup && git add -A && git commit -m 'auto-backup' --quiet && git push --quiet"}
        ]
      }
    ]
  }
}
```

With this setup, every Claude Code session automatically pulls the latest backup at start and pushes any changes at end. State survives machine failures, OS reinstalls, and multi-machine workflows.

### New machine restore

> **Manual step:** Clone the repo, then re-run the setup script. It detects the existing backup and restores from it.

```bash
# If using backup/setup.sh:
bash backup/setup.sh git@github.com:youruser/claude-state.git

# If using the reference sync script:
git clone git@github.com:youruser/claude-state.git ~/repos/personal/claude-state
cd ~/repos/personal/claude-state && ./sync.sh restore
```

One command after clone. All state, memory, hooks, commands, and per-repo state files are restored.

---

## Team Context Repo

### What it contains

The team context repo aggregates the context that feeds cross-team digests:

| Content | Source | Purpose |
|---------|--------|---------|
| Session journals | Each contributor's `~/.claude/memory/journal/` | Raw material for digest generation |
| Team state files | Each project repo's `.claude/team-state.md` | Architecture decisions, conventions, sprint context |
| Signal data | `~/.claude/meridian/signals/` | GitHub, Linear, Intercom signal files |
| Digest output | `~/.claude/meridian/digests/` | Generated persona digests |

### Setup

> **Manual:** The team context repo requires manual creation and structuring. Meridian's `meridian context init` command can register an existing team context repo, but the repo itself and its directory structure are created by you.

```bash
# 1. Create an org-level repo (MANUAL — you do this on GitHub)
#    e.g., github.com/yourorg/team-context

# 2. Structure (MANUAL — create these directories yourself)
team-context/
  journals/
    greg/          # Each contributor gets a directory
      2026-03-01.md
    sarah/
      2026-03-01.md
  signals/
    github/        # Aggregated signal files
    intercom/
  digests/
    engineering/   # Generated digests by persona
    product/
  team-state/
    meridian.md    # Copies of team-state.md from each project
    api-service.md
```

### How journals flow into the team repo

> **Automated:** `meridian journal sync` handles copying authored journals to the team context repo. The snippet below shows the underlying logic for reference.

Each contributor's session-end hook pushes their journal entries to the team repo. The simplest approach:

```bash
# In each contributor's session-end hook:
# 1. Copy today's journal to the team repo
cp ~/.claude/memory/journal/$(date +%Y-%m-%d).md \
   ~/repos/yourorg/team-context/journals/$USER/$(date +%Y-%m-%d).md

# 2. Commit and push
cd ~/repos/yourorg/team-context
git add -A && git commit -m "journal: $USER $(date +%Y-%m-%d)" --quiet && git push --quiet
```

### Digest generation from team context

The digest engine reads journals and signals from the team context repo instead of (or in addition to) local files:

```bash
# Pull latest team context
cd ~/repos/yourorg/team-context && git pull

# Generate digests from aggregated journals + signals
meridian digest --journal-dir ~/repos/yourorg/team-context/journals \
                --signal-dir ~/repos/yourorg/team-context/signals
```

This produces digests that reflect the entire team's work, not just one contributor's sessions.

### Access control

- **Journals**: Contributors can only push to their own directory. Use GitHub CODEOWNERS or branch protection.
- **Signals**: Signal data is typically non-sensitive (issue titles, PR summaries). If it contains customer data (Intercom), use a private repo.
- **Digests**: Read access for the whole team. Write access for whoever runs digest generation (typically a cron job or CI).

---

## Privacy Boundaries

| Data | Where it lives | Who sees it |
|------|---------------|-------------|
| Personal state (`global-state.md`, `state.md`, `settings.local.json`) | Personal backup repo (private) | Only you |
| Per-repo state (`<repo>/.claude/state.md`) | Gitignored locally, backed up to personal repo | Only you |
| Personal working notes (`<repo>/.claude/personal-state.md`) | Gitignored, never backed up to team repo | Only you |
| Session journals | Personal backup repo + team context repo | You + team |
| Team state (`<repo>/.claude/team-state.md`) | Committed to each project repo | Everyone with repo access |
| Signal data | Team context repo | Team members |
| Generated digests | Team context repo + Slack | Team + Slack channel members |

The key principle: personal state never leaves your private repo. Journals and signals flow to the team repo because they're the raw material for digests. Team state is committed directly to project repos because it's shared context by definition.

---

## Solo Contributor Simplification

For a solo contributor (or early-stage team), the two repos can be collapsed into one. Your personal backup repo also serves as the team context repo — journals, signals, and digests all live alongside your personal state. Split them when a second contributor joins and you need the privacy boundary.
