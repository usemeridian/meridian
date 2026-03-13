# Signal Source Integration Roadmap

**Purpose:** Integration roadmap and contributor guide for Meridian signal source connectors — covering technical details, prioritization rationale, and implementation patterns.

> **Shipped connectors:** GitHub, Intercom, Notion. All integrations below are planned — not yet available. Community contributions welcome for any planned connector.

> **Want to contribute a connector?** Check the [Connector Interface](#2-connector-interface-stability) section for the contract every connector implements, review the [Decision Framework](#decision-framework) for prioritization guidance, and open a PR.

Last updated: 2026-03-12

---

## Overview

This document prioritizes signal source integrations across four adoption phases, covering both internal tools (engineering workflow) and external signals (market intelligence). Priorities are based on:

1. **Persona value alignment** — Which personas need this signal most
2. **Digest quality impact** — How much this improves the daily digest
3. **Technical feasibility** — API quality, rate limits, connector complexity
4. **Adoption timing** — When this integration unlocks the most value

**Current state (v1.8.16):**
- **Shipped:** GitHub (engineering), Intercom (support), Notion (documentation)
- **Early Adoption:** Linear (small team PM), Asana (PM alternative), DORA metrics (derived from GitHub)
- **Growth:** Sentry, Slack-as-signal, Market Intel (HN + News + Bluesky), Meeting Transcripts (Fathom + Fireflies), Vercel/Netlify, PostHog, Google Drive
- **Scale:** Figma, Copilot/Claude Code metrics, Calendar health, GitLab, Datadog, LaunchDarkly
- **Enterprise:** Zendesk, PagerDuty, ChartMogul/HubSpot (revenue), SonarQube

---

## Integration Phases

### Shipped (Current State)

**Status:** Live in production. All three connectors follow the same interface pattern and write daily signal files to `~/.claude/meridian/signals/<connector>/<date>.md`.

| Signal Source | Personas | What it Pulls | Connector Status |
|---------------|----------|---------------|------------------|
| **GitHub** | Engineering, Product | PRs (state, author, age, review status), issues (labels, state, age), CI/CD runs (status, conclusion, duration). Per-repo files + cross-repo summary. Flags blocked PRs (open >5 days) and CI failures. | Shipped (v1.4+) |
| **Intercom** | Product, Strategy | Conversations with tag analysis, topic clustering (keyword extraction from titles), daily volume trends, first-response time, open conversation tracking. Privacy-safe: titles and tags only, never raw message body. | Shipped (v1.5+) |
| **Notion** | Product, Strategy, Engineering | Recently updated pages, database entry status, comments on pages, top contributors. Auto-discovers shared databases. Resolves user names via `/users` API. Privacy: metadata only, no raw page content. | Shipped (v1.8.13) |

**Connector interface (all three implement this contract):**

```javascript
module.exports = {
  configure()                         // Interactive setup (prompts for tokens, repos, etc.)
    → returns config object           // Caller writes to ~/.claude/meridian/connectors.json

  pull(config, since)                 // Fetches signals since date
    → { files: [string],             // Paths to written signal markdown files
        summary: string,             // Human-readable summary text
        counts: {...} }              // Source-specific counts

  summarize(filePath)                 // Extracts ## Summary section from a signal file
    → string | null
}
```

**How signals flow to digests:** `meridian pull <connector>` writes signal markdown files. `meridian reindex` (or the container's hourly cron) indexes them into the content store. `meridian digest` reads indexed signals and injects them into the LLM prompt alongside journal entries. The digest generator uses `collectSignals()` to read signal files directly when the content store hasn't indexed them yet (fallback path).

**Validation needed:**
- Does GitHub signal improve digest quality for engineering users?
- Does Intercom signal surface actionable customer patterns for product managers?
- Does Notion signal help with contradiction detection (what was decided vs. what shipped)?

**Decision gate:** If shipped signal sources show no measurable value in early digests (quality NPS <6), pause new integrations and fix digest prompt engineering first.

**Known gotchas:**
- GitHub and Intercom `today()` functions use `toISOString().slice(0,10)` (UTC). Notion connector was fixed to use local date. This matters after midnight UTC — signal filenames may not match test expectations.
- Content store `indexSignals` only scans one level deep. GitHub per-repo signals in subdirectories require the `collectSignals` fallback.

---

### Early Adoption

**Goal:** Close the "what's planned vs. what shipped" loop. Validate with pilot teams.

#### Linear (Project Management)

**Why this matters:**
- Small technical teams (3-10 people) overwhelmingly prefer Linear over Jira
- Excellent GraphQL API with complexity-based rate limiting (1,500 req/hr)
- Webhook support for real-time issue and cycle updates
- Signal quality: Issue velocity, blocked items, cycle progress, label patterns, triage queue health

**Digest impact:**
```
Engineering Digest — Week of March 3

Sprint Health:
- 12/15 issues completed (80% velocity vs. 65% last sprint)
- 2 issues blocked >3 days (authentication module, payment integration)
- 3 issues moved to backlog mid-sprint (scope creep signal)
- Triage queue: 8 untriaged issues, oldest 4 days (bottleneck?)
```

**Target personas:** Engineering (primary), Product (secondary)

**Technical notes:**
- GraphQL API — fetch cycles + issues + projects in one query
- Track complexity points per query, back off on 429s
- Output: `signals/linear/<date>.md`
- Unique: Linear has first-class "project update" concept (leads post status updates) — high signal

---

#### Asana (Project Management)

**Why this matters:**
- Good REST API with Events endpoint designed for "what changed since last pull" — a natural fit for Meridian's polling model
- Stories API returns full activity feed per task (assignments, status changes, comments, due date changes)
- Strong adoption among mid-size teams

**Digest impact:**
```
Engineering Digest — Week of March 3

Project Activity:
- 14 tasks completed across 3 projects
- 2 tasks overdue by >3 days (API migration, security audit)
- Project "Q2 Launch": status updated to "At Risk" by PM

Task Patterns:
- "Authentication" section had 8 task updates (highest activity)
- 3 tasks reassigned mid-sprint (possible scope confusion)
```

**Target personas:** Engineering (primary), Product (secondary)

**Technical notes:**
- Events API returns only changes since a sync token (efficient polling)
- Stories API gives richest activity signal (every action generates a story)
- Custom fields provide structured metadata (Priority, Task Progress)
- Rate limits: per-minute windows with `Retry-After` header on 429
- Webhooks available (heartbeat every 8 hours, event propagation from comments to parent tasks)

---

#### DORA Metrics (Derived) — Engineering Health Signal

**Why this matters:**
- Derivable from existing GitHub data — zero new connectors needed
- Universal applicability — every team using GitHub gets DORA metrics
- High digest value — "Your deployment frequency increased 40% this month" is a headline

**The four metrics and how to derive them:**

| Metric | GitHub Data Source | Derivation |
|--------|-------------------|------------|
| Deployment Frequency | Actions workflow runs on `main` (deploy/release workflows) | Successful runs per week |
| Lead Time for Changes | PR `created_at` → `merged_at` → deployment workflow completion | Median time from first commit to production |
| Change Failure Rate | Workflow failures on `main` after merge, or `bug`/`incident` issues opened within N hours of deploy | Failed deploys / total deploys |
| MTTR | Time between incident issue creation and closure | Median recovery time |

**Implementation:** Add `computeDORAMetrics()` function in the digest generation pipeline. Processes existing GitHub signal data. No new connector — this is a computed signal layer.

**Decision gate:** Build immediately. Free, high-value, differentiator.

---

#### Jira (Project Management)

**Why later (not now):**
- Jira signals larger enterprise teams, not the primary audience for early adoption
- API quality is deteriorating — v3 search endpoint has reports of pagination bugs (`isLast` never returning true, infinite `nextPageToken` chains)
- OAuth 2.0 (3LO) setup is substantially more complex than Linear/Asana
- Small teams are migrating from Jira to Linear

**Decision gate:** Build when multiple teams explicitly request it.

---

### Growth

**Goal:** Expand signal diversity across all four personas. Prove Meridian surfaces insights humans would miss.

#### Sentry (Error Tracking) — Production Reality Signal

**Why this matters:**
- 71% of Sentry customers have fewer than 50 employees — widely adopted among small teams
- Release Health API uniquely answers "did our last deploy make things worse?" — crash-free session rate per release
- Free tier (5K errors/mo) accessible for small teams
- Complements GitHub (code changes) with production signal

**Digest impact:**
```
Engineering Digest — Week of March 3

Production Health:
- 42 new error events (up 180% vs. last week)
- Top error: "AuthenticationError: Token expired" (28 occurrences)
- Release v2.3.1: crash-free sessions dropped from 99.2% to 97.1% (deploy quality alert)
- 3 new issues created, 2 resolved, 1 regressed
```

**Target personas:** Engineering (primary), Product (secondary)

**Technical notes:**
- Issues API, Events API, Releases API, Release Health/Sessions API
- Release health is the high-value unique signal — no other tool provides this
- Rate limits: 100 req/min for org events, generous for daily polling
- Output: `signals/sentry/<date>.md`

---

#### Slack (Team Communication) — Decision Evaporation Signal

**Why this matters:**
- Decisions made in Slack threads are the #1 source of evaporated context
- **Can detect "decision threads" via metadata only** — `conversations.history` returns `reply_count`, `reply_users_count`, `thread_ts` on parent messages. Heuristic: `reply_count > 10 AND reply_users_count >= 3` = high-signal thread. No message content needed.
- Internal custom-built apps are exempt from May 2025 rate limit restrictions (50+ req/min)

**Digest impact:**
```
Strategy Digest — Week of March 3

High-signal threads (>10 replies, 3+ participants):
- #engineering: 2 decision-weight threads (15 and 12 replies)
- #product: 1 decision-weight thread (18 replies, 5 participants)

Communication patterns:
- Cross-functional threads: 8 (up from 3 last week)
- Threads with checkmark reactions: 4 (consensus signal)
- Channel activity spike: #architecture had 3x normal volume
```

**Target personas:** Strategy (primary), Product (secondary)

**Privacy:** Metadata only by default (thread shape, participant count, channel, timestamps). Optional content-reading mode behind explicit opt-in flag. No DM access ever.

**Technical notes:**
- Conversations.history is Tier 3 (~50 req/min for internal apps)
- Reaction signals available via `reactions.list` — checkmark/eyes/+1 = consensus indicators
- Canvas API detects when canvases are created/updated/shared (distilled decisions/specs)

---

#### Market Intel (HN + News + Bluesky) — Strategy Persona Signal

**Why this matters:**
- Strategy persona currently gets zero external context — no competitor moves, market shifts, or community sentiment
- All three APIs are **completely free, no authentication required**
- Trivial implementation, massive Strategy persona value

**Three sources bundled as one "market-intel" connector:**

**Hacker News** (Firebase + Algolia APIs):
- Firebase API: real-time top/new/best stories, no auth, no documented rate limit
- Algolia Search: full-text search across all HN content, no auth, free
- Signal: top stories mentioning company/competitors/tech stack, point counts, comment counts

**Google News RSS**:
- Free RSS feeds for any search query (`news.google.com/rss/search?q=QUERY`)
- No API key, no rate limits
- Signal: news mentions of company, competitor funding rounds, industry trends

**Bluesky** (AT Protocol):
- Public API at `public.api.bsky.app/xrpc`, no auth for reads
- `app.bsky.feed.searchPosts` for keyword search across all public posts
- Signal: developer community mentions, competitor activity, tech sentiment

**Digest impact:**
```
Strategy Digest — Week of March 3

Market Pulse:
- [Competitor] raises $25M Series B (TechCrunch, via Google News)
- "AI coding assistants" trending on HN: 3 front-page posts this week
- Your product mentioned in 2 Bluesky posts (up from 0 last week)

Ecosystem:
- meridian-dev: 342 npm downloads this week (+18% WoW)
- React Server Components hit HN #2 (891 points) — relevant to your stack
```

**Configuration:** Enter company name, competitor names, tech stack keywords, npm packages. One `pull()` produces `signals/market-intel/<date>.md` with sections for each source.

**Technical notes:**
- npm download trends API also free, no auth (`api.npmjs.org/downloads/`)
- GitHub Trending derivable from existing GitHub connector (Search API for high-star-velocity repos)
- RSS parsing via standard Node.js libraries (`rss-parser`)

---

#### Vercel/Netlify (Deployment Signals) — Shipping Velocity Signal

**Why this matters:**
- Many small teams (especially Next.js/React) deploy exclusively on Vercel or Netlify
- Deploy frequency is a signal unavailable from any other source
- Both have clean REST APIs with bearer auth
- Low implementation complexity

**Digest impact:**
```
Engineering Digest — Week of March 3

Shipping Velocity:
- 12 deploys this week (up from 7 last week)
- 2 failed builds on Tuesday (both resolved same day)
- Average build time: 47s (stable, no regression)
- Preview deployments: 18 (active PR review)
```

**Target personas:** Engineering (primary), Strategy (secondary — shipping velocity is a team health metric)

**Technical notes:**
- Vercel: `GET /v6/deployments` with project/date filters, bearer auth
- Netlify: REST API at `api.netlify.com/api/v1/`, OAuth or PAT
- Build one connector with adapters for both platforms, or two lightweight connectors
- Output: `signals/vercel/<date>.md` or `signals/netlify/<date>.md`

---

#### PostHog (Product Analytics) — Product Persona Validation

**Why this matters:**
- Product personas need quantitative signal to justify Meridian adoption
- Self-hosted option aligns with privacy-first positioning
- Free tier (1M events/mo) accessible for small teams
- Feature flags + analytics + error tracking in one platform

**Digest impact:**
```
Product Digest — Week of March 3

Feature Adoption:
- New checkout flow: 42% adoption (340 users), +12% vs. legacy
- Feature flag "dark-mode-v2": 85% rollout, 2.1x engagement vs. control

Friction:
- Funnel drop-off at payment step: 23% (up from 18%)
```

**Technical notes:**
- Query API (HogQL), Insights API, Feature Flags API
- Approach: pull saved insights (user configures dashboards in PostHog, connector pulls those)
- Rate limits: 240 req/min, 1,200 req/hr
- Privacy: aggregate metrics only, no PII

---

#### Meeting Transcripts (Decision Capture) — Context Evaporation Signal

**Why this matters:**
- Decisions made in meetings are the single largest source of evaporated context — rationale discussed verbally, never written down
- Third-party transcription tools (Fireflies, Fathom) pre-extract summaries and action items — Meridian doesn't need to process raw transcripts
- "Decided in sprint planning but never tracked" is a gap no other signal source fills
- Cross-reference action items from meetings with PM tool (Linear/Asana) to detect "promised but not tracked" drift

**Two-tool approach (one connector, two adapters):**

**Fathom** (REST API, high adoption among small teams):
- Generous free tier (unlimited recordings, 5 AI summaries/mo) means teams likely already use it
- REST API with `X-Api-Key` auth, 60 req/min — more than enough for daily polling
- Pulls: AI summaries (template-based markdown), action items (with assignees, completion status), meeting metadata
- CRM integration data available (HubSpot contacts/deals matched to meetings)

**Fireflies.ai** (GraphQL API, richest structured data):
- GraphQL endpoint with selective field fetching
- Rate limits: 50 req/day on Free/Pro (unusable), 60 req/min on Business ($19/user/mo)
- Pulls: AI summaries, structured action items (`analytics.categories.action_items`), sentiment analysis, topic categorization, speaker attribution
- Best structured data quality of any transcription tool

**Digest impact:**
```
Engineering Digest — Week of March 10

Meeting Decisions & Action Items:
- [Sprint Planning] Decided: API migration will use strangler fig pattern (not big-bang)
  Rationale: Risk mitigation, ship incrementally
  Action: Engineer to create migration backlog by Thursday

- [Architecture Review] Decided: Move from REST to gRPC for inter-service calls
  3 alternatives evaluated, gRPC chosen for type safety + performance
  Action: Tech lead to prototype by next Friday

Meeting Health:
- 6 meetings this week (down from 9 last week)
- Average duration: 32 min (healthy range)
- 2 meetings ran over by >15 min
```

**Target personas:** Engineering (primary — decisions and action items), Product (secondary — tracks what was decided vs. what was planned)

**Privacy model (critical):**
- **Default: summary-only mode.** Pull pre-generated AI summaries and structured action items. Never pull raw transcripts.
- **Meeting type filtering.** Configuration specifies which meeting categories feed the digest (sprint planning, architecture reviews, retros). Exclude 1:1s, HR, and ad-hoc by default.
- **No transcript storage.** Signal files contain extracted decisions and action items, never verbatim quotes.
- **Explicit opt-in per category.** Users configure which meeting types flow to digests.

**Technical notes:**
- Build one `meeting-transcripts` connector with adapters for Fathom (primary) and Fireflies (secondary)
- Both implement `configure/pull/summarize` — Fathom adapter uses REST, Fireflies adapter uses GraphQL
- Output: `signals/meetings/<date>.md`
- Action item cross-reference: compare meeting action items against Linear/Asana tasks to flag untracked commitments (computed signal, like DORA)

**Decision gate:** Build when multiple pilot users have either Fathom or Fireflies. Fathom first (free tier = higher adoption).

**Planned zero-dependency fallback (not yet implemented):**

Not everyone uses a transcription tool. Solo engineers, early-stage teams, and cost-conscious users need a way to capture meeting decisions without a third-party subscription. Two planned paths:

1. **Paste a transcript.** `meridian ingest meeting` would accept a raw text transcript (pasted, piped from stdin, or pointed at a file). Meridian would run LLM extraction (same Haiku pipeline used for journal extraction) and write a structured signal file with decisions, action items, and summary — identical format to what Fathom/Fireflies adapters produce. Works with any transcript source: Apple Notes copy-paste, Zoom VTT export, Google Meet download, or voice memo transcription.

2. **Interactive meeting debrief.** `meridian meeting` (or a slash command `/meeting` inside an AI session) would start a short structured chat: "What was decided? Any action items? Who owns what? Any blockers raised?" The conversation would be extracted into the same signal format and land in `signals/meetings/<date>.md`. This captures the 80% of meeting value in 2 minutes of typing — no recording needed.

Both paths would produce the same output shape as the Fathom/Fireflies connector, so they flow through the same indexing and digest pipeline. The connector adapters are an upgrade, not a prerequisite. This means meeting signals would work on day one for every user — the third-party integrations just automate what the manual paths already do.

**Planned CLI surface:**
```
meridian ingest meeting              # Paste or pipe a transcript for extraction
meridian ingest meeting notes.txt    # Extract from a file
meridian meeting                     # Interactive debrief chat
/meeting                             # Same thing inside an AI session
```

---

#### Google Drive (Document Collaboration) — Handoff Signal

**Why this matters:**
- Google Workspace is near-universal among small teams
- Drive Activity API v2 provides metadata-only activity stream — purpose-built for this use case
- Detects document sharing (handoff signal), comment activity, collaboration patterns
- Privacy-safe by design — `drive.activity.readonly` scope prohibits file content access

**Digest impact:**
```
Product Digest — Week of March 3

Document Activity:
- "API Design v3" shared with Engineering team (handoff from Product)
- "Q2 Roadmap" edited by 4 people this week (active collaboration)
- 5 unresolved comments on "Checkout Redesign PRD" (open discussion)
```

**Target personas:** Product (primary), Strategy (secondary)

**Technical notes:**
- Drive Activity API v2: structured actions (Create, Edit, Move, Comment, PermissionChange) with actors and timestamps
- Comments API for resolved/unresolved status
- Folder-based signals: activity in "Architecture Decisions" folder carries semantic meaning
- OAuth with `drive.activity.readonly` + `drive.metadata.readonly` scopes

---

### Scale

**Goal:** Expand observability, workflow coverage, and novel signal types.

#### Figma (Design Collaboration) — Handoff Signal

**Why at scale:**
- Design persona is the weakest link in current offering
- **Dev Mode status webhooks** fire when designers mark sections "Ready for Dev" — the literal handoff signal
- Unresolved comments on "Ready for Dev" files = design-engineering friction

**Technical notes:**
- Webhook-driven (push), not polling — `FILE_UPDATE`, `FILE_COMMENT`, `DEV_MODE_STATUS_UPDATE` events
- Comments API returns resolved/unresolved status
- Rate limits: ~15 req/min for Pro seats, ~30 req/min for most endpoints
- Webhooks require team admin access

---

#### Copilot / Claude Code Metrics — AI Usage Signal

**Why at scale (novel signal):**
- Copilot Metrics API went GA February 2026 — org-level AI usage data
- Claude Code Analytics API provides session counts, tool acceptance rates, lines added/removed
- "How is the team using AI" is a genuinely novel digest section

**Digest impact:**
```
Engineering Digest — Week of March 3

AI-Assisted Development:
- Copilot suggestion acceptance rate: 34% (down from 38% — complexity increasing?)
- 12 PRs created with AI assistance this week (up from 8)
- Claude Code: 45 sessions, avg 12 min (healthy usage pattern)
```

**Technical notes:**
- Copilot: REST API for org-level metrics (acceptance rates, PR throughput, lines suggested/accepted)
- Claude Code: Analytics API (session counts, duration, tool acceptance by type)
- Both require org admin tokens — higher setup friction

---

#### Calendar (Meeting Health) — Team Health Signal

**Why at scale:**
- Universal signal (every team has a calendar)
- Computable from metadata alone (no meeting content)
- Meeting-to-work ratio, focus time, after-hours meetings = burnout signals
- Complements Meeting Transcripts — calendar provides the health metrics, transcripts provide the content signal

**Digest impact:**
```
Strategy Digest — Week of March 3

Team Health:
- Average meeting load: 18 hrs/week (healthy range: 15-20)
- Focus time ratio: 52% (above 40% threshold)
- 3 after-hours meetings this week (monitor for burnout)
- Longest uninterrupted block: 2.5 hrs (acceptable)
```

**Technical notes:**
- Google Calendar API: event metadata, focus time events as `eventType`, attendee counts
- Microsoft Graph: similar surface but requires browser OAuth (no CLI support in WSL)
- Build Google Calendar first, M365 when CLI auth is solved
- Filter out sensitive events (1:1, HR, performance) by title pattern

---

#### GitLab — Alternative SCM Signal

**Why at scale:**
- ~37% of developers use GitLab. 9K+ companies in the 20-49 employee bracket.
- Structurally mirrors GitHub connector — MRs → PRs, pipelines → Actions, issues → issues
- Native DORA metrics built in (deployment frequency, lead time, change failure rate, MTTR for free)
- Excellent API: 7,200 req/hr, keyset pagination, well-documented

**Technical notes:**
- Build effort: ~2-3 days — reuses existing connector pattern
- REST API at `gitlab.com/api/v4/`
- Output: `signals/gitlab/<date>.md` (same shape as GitHub signals)

---

#### Datadog (Full Observability) — Engineering Maturity Signal

**Why at scale (not earlier):**
- $15-23/host/mo signals engineering maturity beyond typical small teams
- Build when significant demand materializes

**Technical notes:** Monitors API, SLOs API, Events API. 300 req/hr. Straightforward connector.

---

#### LaunchDarkly (Feature Flags) — Deployment Maturity Signal

**Why at scale:**
- Feature flag adoption signals mature deployment practices
- 10 req/sec rate limit, well-documented REST API v2

**Technical notes:** Feature Flags API, Environments API. Build when demand warrants it.

---

### Enterprise

**Goal:** Enterprise workflow support, governance, advanced signal types.

#### Zendesk (Support at Scale)

Intercom covers small teams. Zendesk for enterprise (100+ tickets/mo, SLA tracking, compliance). Build when demand warrants it.

#### PagerDuty (Incident Intelligence)

Sentry covers error tracking for small teams. PagerDuty for on-call maturity (15+ engineer orgs). Build when demand warrants it.

#### ChartMogul / HubSpot (Revenue & Pipeline Signals)

**Why eventually:**
- Extremely high value for Strategy persona — MRR trends, churn, pipeline health
- ChartMogul free for <$10K MRR. HubSpot free CRM tier. Both have clean APIs.
- **Requires separate security model** — financial data must be encrypted, persona-locked, explicit opt-in

**Digest impact (Strategy-only delivery):**
```
Strategy Digest — Week of March 3

Revenue Health:
- MRR: $42,300 (+3.2% MoM)
- Net churn: -1.8% (expansion > contraction)
- 3 new customers, 1 churned

Pipeline:
- 8 deals in "Proposal" stage ($45K total)
- 1 deal stuck >30 days in "Negotiation" (flag)
```

**Decision gate:** Build after external signals prove value. Needs encrypted storage, persona-locked delivery.

#### SonarQube (Code Quality Trends)

Webhook-driven quality gate results, tech debt trends, test coverage deltas. Build when users run SonarQube and request it. ~1-2 day build effort.

---

## Implementation Principles

### 1. One Integration at a Time

**Do not build multiple connectors in parallel during early adoption.** Each integration must prove value before starting the next.

**Exception:** DORA metrics (derived, not a connector) and Market Intel (trivial free APIs) can be built in parallel with Linear/Asana since they don't compete for testing bandwidth.

### 2. Connector Interface Stability

Every connector implements the same contract (established by GitHub, Intercom, and Notion):

```javascript
module.exports = {
  configure(),                        // Interactive CLI setup — prompts for tokens, config
  pull(config, since),                // Fetch signals since date string (YYYY-MM-DD)
                                      // Returns { files: [...], summary: string, counts: {...} }
  summarize(filePath),                // Extract ## Summary section from signal markdown
                                      // Returns string | null
}
```

**Two patterns emerging from research:**
- **Computed signals** (DORA, dependency health): Not connectors. Processing layers that derive metrics from existing signal data. Live in the digest pipeline, not in `bin/connectors/`.
- **Multi-source connectors** (Market Intel): One connector that aggregates multiple upstream APIs. Still implements `configure/pull/summarize` but queries HN + News + Bluesky in a single `pull()`.

### 3. Privacy-First Signal Design

**Never extract PII.** Signal files contain:
- Aggregate metrics (counts, averages, trends)
- Titles and tags (no raw message content)
- Patterns (keywords, topics, clusters)

**Special handling for:**
- Slack: metadata only by default (thread shape, not message content). Content-reading behind explicit opt-in.
- Google Drive: `drive.activity.readonly` scope — no file content access by design.
- Revenue data (ChartMogul/HubSpot): encrypted, Strategy-persona-only delivery.
- Calendar: filter sensitive events by title pattern (HR, 1:1, performance).

### 4. Rate Limit Discipline

**All connectors must:**
- Handle 429 responses gracefully
- Respect pagination limits
- Fail gracefully — a single connector failure should not block other signals
- Use concurrency limits for parallel requests

---

## Decision Framework

Use this when evaluating whether to build a new connector:

```
1. Is this signal source in the roadmap?
   Yes → Follow roadmap timeline and decision gates
   No  → Continue to step 2

2. Do multiple users or contributors request it?
   No  → Defer to backlog (revisit when demand appears)
   Yes → Continue to step 3

3. Does it serve an under-represented persona (Design, Strategy)?
   Yes → Prioritize (persona coverage gap)
   No  → Continue to step 4

4. Is the API free or cheap, documented, and stable?
   No  → Defer (API risk or cost too high)
   Yes → Continue to step 5

5. Can it be built in <2 weeks following the existing connector pattern?
   No  → Re-scope or defer
   Yes → Add to roadmap
```

---

## Evaluated and Deferred

These sources were researched and deliberately excluded. This section is preserved for contributors considering new integrations — check here before proposing a source that's already been evaluated.

| Source | Why Deferred |
|--------|-------------|
| **Twitter/X** | Free tier is write-only. Read access starts at $200/mo (Basic, barely functional). Bluesky covers developer community for free. |
| **Loom** | No usable API. Atlassian acquisition may eventually expose data via Confluence/Jira APIs. |
| **LogRocket / FullStory** | Session replay APIs are export-oriented, not query-oriented. PostHog + Sentry cover the same signals with better APIs. |
| **Crunchbase** | API requires enterprise licensing. Google News RSS catches 80% of funding announcements at 0% of the cost. |
| **Discord** | Bot must be a member of each server. No cross-server search. Only useful if team runs their own community. |
| **BuiltWith / Wappalyzer / SimilarWeb** | $200-300+/month. Technology adoption and traffic signals are nice-to-have but not daily-actionable. |
| **Stack Overflow** | Question volume down 78% since 2024 due to AI assistants. Platform in structural decline. |
| **Miro / FigJam** | Signals are real but diffuse. Whiteboarding activity hard to interpret without content analysis. Low signal-to-noise for digests. |
| **ArgoCD / Flux** | Small teams don't typically run Kubernetes. Revisit when audience shifts. |
| **Terraform Cloud / Pulumi** | Overlap too small. Drift detection and cost estimate signals are genuinely unique — revisit for platform engineering teams. |
| **CircleCI / Buildkite** | Small teams use GitHub Actions. CI status flows back to GitHub via commit statuses — already captured. |
| **Docker Hub / GHCR** | Image pushes visible as Actions completions. Vulnerability scanning via Dependabot alerts. No standalone connector needed. |
| **Reddit** | Non-commercial use restriction. Pulling data for users is arguably commercial use — would require $12K+/year enterprise tier. Legal risk. |
| **Shortcut / ClickUp** | Smaller market share than Linear among small teams. Build only if specific users request it. |
| **Bitbucket** | Declining market share. Signal surface is a subset of GitHub. Build only for Atlassian-ecosystem users. |
| **G2/Capterra** | No public API for review data. |
| **Otter.ai** | API in closed beta — no public documentation, must contact account manager. Unofficial APIs unmaintained. Revisit when public API launches. |
| **Granola** | API requires Enterprise plan (custom pricing). Data limited to publicly shared workspace notes. Small teams unlikely to be on Enterprise. |
| **Recall.ai** | Infrastructure platform for deploying meeting bots, not a signal source for polling. $0.50/hr per meeting. Bot presence creates consent friction. Architecturally wrong for connector model. |
| **tl;dv** | API is v1alpha1 (alpha status). Requires Business plan ($35/user/mo). Contract may change. Build only if multiple users use tl;dv. |
| **Google Meet transcripts** | Cannot start transcription via API (manual UI click required). Transcripts take 45+ minutes to generate. Too unreliable for automated signal collection. |

---

## Appendix: API Reference Summary

| Tool | Auth | Rate Limits | Cost | Best Persona | Phase |
|------|------|-------------|------|--------------|-------|
| **GitHub** | PAT or `gh` CLI | 5,000 req/hr | Free | Engineering | Shipped |
| **Intercom** | Bearer token | Tiered, 429 on excess | Free API | Product | Shipped |
| **Notion** | Integration token | 3 req/sec | Free API | Product/Strategy | Shipped |
| Linear | OAuth/API key | 1,500 req/hr (complexity) | Free plan | Engineering | Early Adoption |
| Asana | PAT/OAuth | Per-minute windows | Free API | Engineering | Early Adoption |
| DORA | (derived from GitHub) | N/A | Free | Engineering | Early Adoption |
| Sentry | Bearer token | 100 req/min | Free tier (5K/mo) | Engineering | Growth |
| Slack | Bot token | ~50 req/min (internal) | Free API | Strategy | Growth |
| Hacker News | None | No documented limit | Free | Strategy | Growth |
| Google News | None (RSS) | No limit | Free | Strategy | Growth |
| Bluesky | None (public) | No documented limit | Free | Strategy | Growth |
| Vercel | Bearer token | Generous | Free API | Engineering | Growth |
| Netlify | OAuth/PAT | Generous | Free API | Engineering | Growth |
| PostHog | API key | 240 req/min | Free tier (1M/mo) | Product | Growth |
| Google Drive | OAuth | Standard quotas | Free API | Product | Growth |
| Fathom | API key (REST) | 60 req/min | Free tier (5 summaries/mo), Premium $19/mo | Engineering/Product | Growth |
| Fireflies.ai | API key (GraphQL) | 60 req/min (Business+) | Business $19/user/mo | Engineering/Product | Growth |
| Figma | OAuth/PAT | ~15-30 req/min | Free API | Design | Scale |
| Copilot Metrics | Org admin token | Standard | Free API | Engineering | Scale |
| Claude Code | Admin API key | Standard | Free API | Engineering | Scale |
| Google Calendar | OAuth | Standard quotas | Free API | Strategy | Scale |
| Fellow.app | API key (REST) | Not documented | Team $7/user/mo | Engineering/Product | Scale |
| MS Teams Insights | OAuth 2.0 (Graph) | Standard Graph throttling | Copilot $30/user/mo for insights | Engineering/Strategy | Scale |
| Zoom Transcripts | OAuth 2.0 | Standard | Free API (cloud recording req.) | Engineering | Scale |
| GitLab | PAT/OAuth | 7,200 req/hr | Free API | Engineering | Scale |
| Datadog | API + App key | 300 req/hr | Paid only | Engineering | Scale |
| LaunchDarkly | API key | 10 req/sec | Paid only | Engineering | Scale |
| Zendesk | OAuth/API token | 400-700 req/min | Paid only | Product | Enterprise |
| PagerDuty | API token | 900 req/min | Paid only | Engineering | Enterprise |
| ChartMogul | API key | Standard | Free <$10K MRR | Strategy | Enterprise |
| HubSpot | OAuth/API key | 110-190/10s | Free CRM tier | Strategy | Enterprise |
| SonarQube | Token | Generous | Free CE | Engineering | Enterprise |
