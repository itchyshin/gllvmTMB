# Recovery checkpoint -- LV dashboard post-merge refresh (2026-06-30 16:16 MDT)

## Current branch and status

- Checkout: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
- Branch: `codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion`
- The checkout is still broadly dirty from earlier mission-control/article/Psi
  work. Do not reset or stage unrelated files.
- Directly touched in this slice: `docs/dev-log/dashboard/index.html`,
  `docs/dev-log/dashboard/status.json`, `docs/dev-log/dashboard/sweep.json`,
  `docs/dev-log/dashboard/version.txt`, `docs/dev-log/check-log.md`, this
  checkpoint, and
  `docs/dev-log/after-task/2026-06-30-lv-mission-control-postmerge-refresh.md`.

## What changed

- Mission Control build is `r60`.
- Live widget at `http://127.0.0.1:8770/` shows
  `17 covered`, `3 partial`, `0 ready`, `0 active`, `4 blocked`, `24 total`.
- The widget records PR #581 merged to `main` at `12526a15`, post-merge
  R-CMD-check `28476941515` green, pkgdown `28477809749` green, public
  `extract_lv_effects` reference page updated, and @Ayumi-495 notified with the
  main install route.
- The remaining LV caveat is GLLVM.jl phylo Model A, parked/blocked at
  `591/720 = 0.821` with optimistic bound `671/800 = 0.839`.
- GLLVM.jl PR #127 is now closed/parked; its title/body are public parked state:
  `[BLOCKED] phylo Model A X_lv interval gate -- parked pending redesign`.

## Commands already run

- `jq empty docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json`
  -> passed.
- `git diff --check -- docs/dev-log/dashboard/index.html docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json docs/dev-log/dashboard/version.txt`
  -> passed.
- stale scan:
  `rg -n 'PR #539|Issue #340|2026-06-23|514/640|206/320|still running|ready #581|1 ready|PR #581 review queue|not yet main|open, ready|4847853283|can be posted|r59|const BUILD = "r59"' ...`
  -> no hits.
- `sh tools/start-mission-control.sh --background` -> synced live dashboard.
- Browser DOM check -> served widget clean at `r60`, no stale ready/June-23
  text.
- Posted @Ayumi-495 comment:
  https://github.com/Ayumi-495/urbanisation_map/issues/8#issuecomment-4848347523
- Posted GLLVM.jl PR #127 blocked-evidence comment:
  https://github.com/itchyshin/GLLVM.jl/pull/127#issuecomment-4848385172
- Edited GLLVM.jl PR #127 title/body to parked blocked state.
- Closed GLLVM.jl PR #127 as parked blocked evidence:
  https://github.com/itchyshin/GLLVM.jl/pull/127#issuecomment-4848418863
- Inspected GLLVM.jl PR #127 and local `/private/tmp/gllvmjl-phylo-xlv` state.

## Next safest action

Do not launch more same-route phylo bootstrap jobs. For the LV arc, the next
meaningful action is a future maintainer decision on the phylo Model A route:
either redesign the interval target in a new route or leave the closed #127
route retired. No code push to GLLVM.jl without explicit maintainer
instruction.

## Blocking question

Should the local GLLVM.jl diagnostic closeout branch ever be pushed, or should
the closed #127 route remain retired until a redesigned interval target exists?
