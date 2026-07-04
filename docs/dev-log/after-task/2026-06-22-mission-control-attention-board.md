# After-task: mission-control attention board

Date: 2026-06-22
Agent: Codex / Ada

## Scope

Reorganised the local `gllvmTMB` mission-control dashboard so the first screen is
closer to the easier-to-read `drmTMB` mission-control board.

## Files changed

- `docs/dev-log/dashboard/index.html`
- `docs/dev-log/dashboard/version.txt`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-mission-control-attention-board.md`

## What changed

Added a top **Attention Board** with four compact sections:

- Current Work
- Serial Gates
- CI And Issues
- Claim Boundary

The board is derived from existing `status.json` and `sweep.json` fields. No
status metrics, validation claims, release claims, PR state, or capability rows
were promoted.

## Validation

- Compared the DRM dashboard (`http://127.0.0.1:8765/`) and the GLLVM dashboard
  (`http://127.0.0.1:8770/`) with local `curl`.
- Source smoke confirmed `const BUILD = "r57"`, the Attention Board mount point,
  and `version.txt` agree.
- `sh tools/start-mission-control.sh --background` synced the live copy to
  `/tmp/gllvm-dashboard`.
- In-app browser render check found 4 Attention Board sections, starting with
  `Current Work`.
- Browser console warnings/errors were empty.

## Not Run

No R package tests, pkgdown, or `devtools::check()` were run because this was a
static local dashboard UI reorganisation.

## Review Notes

Pat/Darwin: the first screen now answers "what should I look at first?"

Rose/Grace: the change is presentation-only; claim boundaries remain explicit,
and no source-of-truth metric was changed.
