# After-task — SDM day close-out (rare-species article, 0.7.0, deploys)

Date: 2026-08-16 · Platform: Claude · Closes the day's SDM programme.
Prior after-tasks: `2026-08-16-isdm-main-merge-sdm-collection.md` (merge + collection),
`2026-08-16-sdm-collection-audit.md` (audit + repeated-visits + Paper × Items re-aim).

## What landed after the audit after-task

- **[#1049](https://github.com/itchyshin/gllvmTMB/pull/1049)** — `DESCRIPTION`
  0.6.0 → 0.7.0 (the live navbar contradicted NEWS's "0.7.0 (development)"
  header; maintainer-spotted) + the audit-arc Melissa reconciliation
  (`docs/dev-log/plan-actual/2026-08-16-sdm-collection-audit.md`). Its first
  CI run failed 3 assertions in `test-va-all-family-light-fits.R` at the
  `delta_lognormal_log` cell; the rerun on identical code passed. **Flake
  record for the VA lane** is on the PR: the "deterministic" H7 light fit is
  environment-sensitive at that cell's tolerance boundary.
- **[#1054](https://github.com/itchyshin/gllvmTMB/pull/1054)** — new SDM
  article *When a rare species breaks the JSDM*
  (`vignettes/articles/rare-species-jsdm.Rmd`), the species-facing MSPL door,
  probe-verified: screen certificate with `infinite_terms`; plain ML fails
  outright on the draw; opt-in experimental MSPL finite point + occurrence
  curve; live negative demonstration that `loading_ridge` does not repair
  separation (conv 1, slope still runaway). Registered second in the SDM
  menu, after joint-sdm.
- **Two manual pkgdown deploys** (`workflow_dispatch`) — verified live:
  six-article SDM menu, corrected labels, rewritten Paper × Items page,
  navbar 0.7.0.

## Maintainer decisions recorded today (for rehydration)

1. **Remedy division across articles**: MSPL demonstrated for rare *species*
   under SDM; the ridge demonstrated for runaway loadings in the Paper ×
   Items article under Model Guides; each cross-links the other; both show
   the remedies do not substitute (ridge on a separated response: still
   runaway; ridge + MSPL: refused by design). A Site × Species duplicate of
   the full MSPL article was declined ("too similar").
2. **Paper × Items article is final as re-aimed** — no further touch wanted.
3. **First release version line**: `DESCRIPTION` now matches NEWS at 0.7.0.

## Open flags (owners, not this lane)

- MSPL SE/interval calibration (MSPL lanes) — when promoted, the fence
  paragraphs in `rare-species-jsdm.Rmd` and `mspl-binary-jsdm.Rmd` update.
- VA `delta_lognormal_log` flake (VA lanes) — PR #1049 comment has the record.
- MSPL source-pin test red on main (MSPL lanes) — flagged in #1031 and the
  check-log.
- Two-paper figure prototypes: preserved (branch `codex/two-paper-global-analysis`
  pushed; results copied to the Dropbox checkout's `dev/isdm-package-recovery/results/`).
  P1-F1 fixes and P2-F1 redraw remain that lane's work.

Nothing is CARRIED-OVER; every branch this platform opened today is merged.
