# Meridian (Public Repo)

Team context layer for AI-assisted engineering. Apache 2.0.

## This is the public repo

This is `usemeridian/meridian` — the open-source repo. A separate private repo (`leizerowicz/meridian`) holds strategy docs, competitive intel, and internal backlog.

**Rules for this repo:**
- No proprietary content: pricing, competitive analysis, business strategy, internal team names, or customer-specific config
- No references to `leizerowicz/meridian` issues (use `usemeridian/meridian` issue numbers)
- Code changes here are public — review before committing

## Testing

Run `npm test` before committing. Tests are bash scripts in `tests/`.

## Commit Rules

- Always push after committing
- Bump version + `npm publish` when changes affect shipped code (bin/, templates/, specializations/, package.json, setup.sh, etc.)
