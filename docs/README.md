# Meridian Documentation

This folder contains documentation for Meridian — the team context layer for AI-assisted engineering.

---

## Architecture

**How Meridian works.** Design principles, signal ingestion, content storage, data flow.

| Doc | What it covers | Read if you're... |
|-----|---------------|-------------------|
| [data-flow.md](architecture/data-flow.md) | End-to-end data flow: capture (journals, transcripts, signals), index (unified content store), deliver (digests, bot, CLI). Includes diagrams and deployment topologies. | Understanding how data moves through Meridian, onboarding, or debugging data issues. |
| [architecture-principles.md](architecture/architecture-principles.md) | Eight principles that constrain every design decision: integration platform, data portability, design for forwarding, local-first hosted path. | Building features, designing connectors, or making architectural choices. |
| [architecture-signal-channels.md](architecture/architecture-signal-channels.md) | How signal ingestion works: CLI-first polling, hybrid architecture, cost model, MVP channels, connector interface. | Building or extending signal connectors. |
| [content-store.md](architecture/content-store.md) | Content store architecture: indexing (full-text + semantic), searching, CLI reference, storage schema. | Working on the content store, search, or bot features. |

---

## Operations & Guides

**Setting up and using Meridian.** State repo setup, running pilots.

| Doc | What it covers | Read if you're... |
|-----|---------------|-------------------|
| [state-repo-setup.md](operations/state-repo-setup.md) | Personal backup repos, team context repos, journal aggregation, privacy boundaries. | Setting up Meridian for the first time, onboarding a new machine, or adding team members. |
| [pilot-guide.md](operations/pilot-guide.md) | Practical playbook for piloting Meridian with a team. Phases, success criteria, measurement. | Running a Meridian pilot with a real team. |

---

## Reference

| Doc | What it covers | Read if you're... |
|-----|---------------|-------------------|
| [FAQ.md](FAQ.md) | Setup, configuration, known issues, troubleshooting. | Getting started, hitting a snag, or looking for quick answers. |
| [BOOTSTRAP_PROMPT.md](../../BOOTSTRAP_PROMPT.md) | Copy-paste prompt to set up Meridian in a new Claude Code session. | Setting up Meridian for the first time. |

---

## Quick Reference

### For New Contributors

1. Start with [data-flow.md](architecture/data-flow.md) to understand how data moves through the system
2. Read [architecture-principles.md](architecture/architecture-principles.md) to understand design constraints
3. Check [state-repo-setup.md](operations/state-repo-setup.md) for setup instructions
4. Browse the [FAQ](FAQ.md) for common questions
