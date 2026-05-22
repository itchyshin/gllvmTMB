# Reference/plot readiness audit

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Auditors: Ada with Florence, Pat, Fisher, Grace, Rose, and Shannon lenses

## Verdict

Warn / nearly PR-ready. The branch has a much stronger reference and plotting
surface than the baseline: wide-first public examples, confidence-eye
covariance/correlation displays, no-outline confidence-eye styling,
rotation-honest ordination captions, and refreshed visual-debt ledgers are all
covered by local tests and pkgdown checks. The remaining blockers before a
maintainer PR update are external/process evidence, not an obvious local code
failure.

## Current branch state

- `git status --short --branch` before this audit showed
  `codex/reference-function-audit-2026-05-22...origin/main [ahead 35]` with
  only design-ledger files modified.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,updatedAt,statusCheckRollup`
  returned `[]`.
- `git log --all --oneline --since="6 hours ago"` showed the current cleanup
  lane commits only.
- No spawned subagents were running.

## Validation evidence

- Full tests:
  `Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'`
  returned 2547 passes, 13 skips, 1 warning, 0 failures in 631.7 seconds.
- The single warning was the known legacy-level warning in
  `test-spatial-latent-recovery.R:140`: `level = "spde"` is deprecated; use
  `level = "spatial"` instead.
- Pkgdown:
  `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- Diff hygiene:
  `git diff --check` returned clean.
- Stale wording scan:
  `rg -n 'Phase 1c-viz at 0/7|quartimax|Confidence-I|confidence-I|randrop|raindrop shows|Tight drops|ci-correlation-raindrop' docs/design NEWS.md README.md vignettes R man tests _pkgdown.yml`
  returned no hits.
- Raindrop compatibility scan:
  `rg -n 'style = "raindrop"|raindrop|Raindrop|raindrop_level' R man tests NEWS.md docs/design vignettes README.md _pkgdown.yml`
  returned expected hits only where `raindrop` is documented or tested as a
  compatibility alias.

## What this audit closed

- Design 46 no longer says Phase 1c-viz is 0/7. It now records the current
  partial/covered/planned state of ordination, confidence eyes, matrix
  heatmaps, estimate-vs-truth plots, integration plots, and gallery/M3 debt.
- Design 53 now has an explicit visual-QA debt section: rendered article QA,
  visual snapshot strategy, 3-OS CI, and Rose alias scan remain open before a
  stable figure-surface claim.
- Design 35 now records confidence eyes as soft filled frequentist
  compatibility displays with hollow estimate markers, and corrects
  `rotate_loadings()` from stale `quartimax` wording to `promax`.
- Design 06 now matches the implemented `getLoadings(..., rotate = ...)` and
  `rotate_loadings(..., method = ...)` signatures and no longer presents
  `raindrop` as the primary Sigma-table plot name.

## Residual risk

- `devtools::check(args = "--no-manual")` was not rerun after this final
  design-ledger slice.
- There is no 3-OS CI evidence for the branch until it is pushed/PR-tested.
- There are still no `vdiffr` snapshots for stable plot helper shapes.
- The full-test warning for legacy `level = "spde"` remains; it is not caused
  by this slice, but it is visible in the current local evidence.
- The branch is ahead of `origin/main`; no push or PR update was performed in
  this audit.

## Next safest action

Review this audit plus the newest after-task reports, then decide whether to
run `devtools::check(args = "--no-manual")` locally or push a PR update and let
3-OS CI exercise the branch. Do not advertise the figure surface as
publication-stable until visual snapshots or an equivalent rendered-figure QA
strategy exists.
