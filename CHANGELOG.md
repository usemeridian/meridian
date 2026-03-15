# Changelog

All notable changes to Meridian are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [1.8.41] - 2026-03-15

### Added
- **SQLite storage backend** — content store now uses SQLite (via `better-sqlite3`) as primary storage with automatic JSON file fallback
- Storage abstraction layer (`bin/storage/`) with pluggable backends
- Auto-migration from JSON files to SQLite on first run (idempotent, preserves originals)
- `MERIDIAN_STORAGE_BACKEND` env var to force `sqlite` or `json`
- `meridian doctor` reports active storage backend
- 21 new backend-specific tests (migration, rollback, dual-backend comparison)

### Changed
- Content store queries use indexed SQLite columns instead of full-file JSON deserialization
- `better-sqlite3` added as optional dependency (install succeeds without it)
- Dockerfile includes build tools for native compilation on Alpine

## [1.8.32] - 2026-03-13

### Added
- Per-member version tracking with team `min_version` enforcement

### Fixed
- Context shift detection false positives

## [1.8.31] - 2026-03-13

### Fixed
- Hook format corrected to match Claude Code settings schema (`{matcher, hooks}` groups)
- Doctor validation for hook structure

## [1.8.30] - 2026-03-12

### Changed
- Hook merge logic improvements in setup

## [1.8.27] - 2026-03-10

### Added
- Per-team journal routing for multi-team support
- `meridian journal split` command for migrating existing journals to multi-team format

## [1.8.25] - 2026-03-08

### Added
- Multi-team support: `meridian context add`, `meridian context bind`, `meridian context list`
- Register multiple teams and route journals/context to the correct team repo

## [1.8.24] - 2026-03-07

### Added
- Automatic context shift detection at session end
- LLM-based classification of significant decisions

## [1.8.22] - 2026-03-05

### Fixed
- Natural language date parsing in Slack bot ("March 3", "between March 3 and March 6", "last week")

## [1.8.21] - 2026-03-04

### Added
- `MERIDIAN_SKIP_EXPORT=1` env var to suppress journal export in worker agents

## [1.8.20] - 2026-03-03

### Fixed
- Journal dedup: each decision individually deduped (was only checking first entry)

### Changed
- Removed `package-lock.json` from tracking

## [1.8.0] - 2026-02-24

### Added
- Content store with full-text and semantic search
- Signal connectors: GitHub (issues, PRs, Actions), Intercom (conversations, tags), Notion (pages, databases)
- Conversation transcript indexing with LLM extraction
- Slack bot for decision trail queries (Socket Mode)
- Digest generation with persona-targeted views
- Docker deployment (`meridian deploy init`)
- `meridian insights` for aggregate metrics
