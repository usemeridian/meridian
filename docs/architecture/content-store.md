# Content Store

Searchable index of session journal insights. Index locally, search by text or semantic similarity, filter by metadata, extract trends.

## Quick start

```bash
# Index your journals (auto-detects journal directory)
meridian index-journals

# Full-text search (no API key needed)
meridian search-journals "authentication" --text

# Semantic search (requires OPENAI_API_KEY)
export OPENAI_API_KEY=sk-...
meridian search-journals "how did we handle auth?"

# View insights
meridian insights
meridian insights --json
```

## How it works

### Indexing

`meridian index-journals` parses your session journals (`~/.claude/memory/journal/*.md`) and builds a local index at `~/.claude/meridian/content-store/`.

The index is **incremental** — it hashes each entry's content and only re-processes entries that changed. Running it twice on the same journals produces zero new/updated entries.

Two files are written:
- `index.json` — entry metadata (date, repo, title, tags, drift status, content hash)
- `embeddings.json` — embedding vectors keyed by entry ID (only if OPENAI_API_KEY is set)

Both files are written with `0600` permissions (owner-only read/write).

### Searching

**Full-text search** (`--text` flag or automatic when no embeddings exist):
- Matches query words against title, repo, date, and tags
- No API key required — works on day zero
- Scored by proportion of matching query words

**Semantic search** (default when embeddings exist):
- Generates a query embedding, computes cosine similarity against all entries
- Requires `OPENAI_API_KEY` for the embedding API (text-embedding-3-small)
- Falls back to full-text search if embedding generation fails

Both modes support filters: `--repo`, `--since`, `--until`, `--drifted`.

### Metadata queries

`meridian insights` computes aggregate metrics from the index:
- **Total sessions** — how many journal entries are indexed
- **Drift rate** — percentage of sessions that drifted from stated goal
- **Repo activity** — session count per repo/project
- **Tag frequency** — most common tags across all entries
- **Timeline** — sessions per date

## CLI reference

```
meridian index-journals [--dir <path>] [--store <path>] [--no-embeddings]
meridian reindex [--journals-only] [--conversations-only] [--export]
meridian index-conversations [--dir <path>] [--store <path>] [--since YYYY-MM-DD]
meridian search-journals <query> [--text] [--limit N] [--repo <name>] [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--drifted]
meridian insights [--json] [--store <path>]
```

### index-journals

| Flag | Description |
|------|-------------|
| `--dir <path>` | Journal directory (default: `~/.claude/memory/journal`) |
| `--store <path>` | Store directory (default: `~/.claude/meridian/content-store`) |
| `--no-embeddings` | Skip embedding generation even if OPENAI_API_KEY is set |

### search-journals

| Flag | Description |
|------|-------------|
| `--text` | Force full-text search (skip semantic) |
| `--limit N` | Max results (default: 10) |
| `--repo <name>` | Filter by repo/project name |
| `--since YYYY-MM-DD` | Only entries on or after this date |
| `--until YYYY-MM-DD` | Only entries on or before this date |
| `--drifted` | Only entries where drift was detected |

### insights

| Flag | Description |
|------|-------------|
| `--json` | Output raw JSON instead of formatted text |
| `--store <path>` | Store directory (default: `~/.claude/meridian/content-store`) |

## Conversation indexing

`indexConversations()` scans Claude Code transcript files (`.jsonl` in `~/.claude/projects/`) and extracts decision points via LLM. Each extracted decision becomes a content store entry with `source: 'conversation'`. The LLM model is controlled by `MERIDIAN_EXTRACTION_MODEL` (defaults to `claude-sonnet-4-5-20250929`).

A separate `conversation-index.json` tracks which transcripts have been processed and their content hashes, so re-runs skip unchanged files. The `indexConversationsWithExport()` variant additionally exports extracted decisions as journal entries for git sync — this is what runs at session end via the Stop hook.

## Signal indexing

`indexSignals()` indexes markdown files from `~/.claude/meridian/signals/` (or `MERIDIAN_SIGNALS_DIR`). Signals are organized by channel subdirectory (e.g., `github/`, `intercom/`). Each signal file becomes a content store entry with `source: 'signal'`, tagged with the channel name and section headings.

Signal data is pulled from GitHub (`MERIDIAN_GITHUB_REPOS`) and Intercom (`INTERCOM_TOKEN` + optional `MERIDIAN_INTERCOM_TAGS`) by the transport connectors, then indexed into the store.

## Digest feedback

The content store tracks digest delivery and team reactions in `digest-feedback.json`:

- `recordDigestDelivery()` — stores channel + message timestamp after posting a digest via bot token
- `recordDigestReaction()` — records emoji reactions on digest messages (+1/-1 delta)
- `recordDigestFeedbackText()` — captures threaded text replies on digest messages
- `getDigestFeedback()` — retrieves feedback summaries, filterable by date and limit

This data feeds back into digest quality measurement.

## Onboarding pack generation

`generateOnboardingPack(repoQuery)` synthesizes a context pack for new team members. It searches the content store for entries matching the repo query from the last 90 days, fetches full content for the top 30 entries, and sends them to the LLM (`MERIDIAN_LLM_MODEL`) for synthesis into an onboarding summary. Accessible via the bot's `onboard <repo>` command.

## Repo exclusion

`MERIDIAN_EXCLUDE_REPOS` (comma-separated, case-insensitive) filters repos from indexing, digests, and bot queries. Supports both `repo` and `org/repo` formats. Useful when engineers work on repos belonging to different teams.

## Multi-source entry types

Entries have a `source` field indicating their origin:
- **journal** — parsed from session journal markdown files (default, no explicit source field)
- **conversation** — extracted from Claude Code transcripts via LLM
- **signal** — indexed from GitHub/Intercom signal files

Entries also carry an `author` field parsed from journal file naming (`YYYY-MM-DD-<author>.md`) or set to empty for non-journal sources.

## Embedding support

Embeddings work with both OpenAI (`OPENAI_API_KEY`) and Azure OpenAI (`AZURE_OPENAI_EMBEDDING_ENDPOINT` + `AZURE_OPENAI_EMBEDDING_KEY` + `AZURE_OPENAI_EMBEDDING_DEPLOYMENT`). Provider is auto-detected from env vars. Re-indexing backfills embeddings for entries that were previously indexed without them.

## Storage schema (v2)

```json
{
  "version": "2.0.0",
  "lastUpdated": 1709337600000,
  "entryCount": 42,
  "entries": {
    "<id>": {
      "date": "2026-02-24",
      "repo": "meridian",
      "title": "Implement signal connectors",
      "user": "",
      "source": "journal",
      "author": "greg",
      "drifted": false,
      "contentHash": "a1b2c3d4e5f67890",
      "contentLength": 512,
      "tags": ["meridian", "signal", "implement", "connectors"],
      "hasEmbedding": true
    }
  }
}
```

Additional storage files alongside `index.json` and `embeddings.json`:
- `conversation-index.json` — tracks processed transcript files and their content hashes
- `digest-feedback.json` — stores delivery records, reactions, and text feedback per digest

## What hosted adds

The local content store is fully functional for individual use. A hosted version adds team-scale capabilities:

- **Team aggregation** — search across your entire team's journals, not just yours. See cross-team patterns, shared lessons, recurring blockers.
- **Hosted embeddings** — semantic search without managing your own API key. Processing billed via usage credits.
- **Automated indexing** — journals indexed continuously without running CLI. Webhook-triggered on session end.
- **Web dashboard** — visual drift trends, repo activity charts, tag clouds, timeline views. Replaces CLI text output with interactive exploration.

**Scaling:** As the content store grows, periodic cleanup of older journal entries is planned. The current approach indexes all journals without pruning. Future versions may archive older entries to vector storage (PGVector) while keeping recent entries in the flat-file index for fast access.

See [architecture-principles.md](architecture-principles.md) for the architectural approach.
