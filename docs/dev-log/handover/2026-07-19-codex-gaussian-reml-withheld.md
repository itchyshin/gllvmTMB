# Codex handover — Gaussian REML 0.6 certificate withheld (2026-07-19)

**Branch:** `codex/gaussian-reml-certificate-20260719`.

## Landed scope

The branch makes the native Gaussian REML contract explicit, adds dense
Patterson--Thompson oracle tests, rejects invalid predictor-informed `lv`
REML, requires positive residual degrees of freedom, and provides a paired
ML/REML point and profile funnel with a raw-shard audit.

## Current evidence

- Totoro point pilot (25), point screen (100 + stress), and point recovery
  (500 anchors) are healthy. The 500 run is point-only; it does not establish
  coverage.
- The 150-unit profile pilot is route-healthy.
- The 150-unit 100-replicate profile screen is **WITHHELD**. Six rows exceed
  the frozen 0.01 gradient rule despite convergence 0 and PD Hessians. The
  exact lower confidence bounds also remain below 0.94 at this screen size.
- Fisher, Grace, and Noether independently returned NOT DONE. See
  `docs/dev-log/audits/2026-07-19-gaussian-reml-d43-admission.md`.

## Do not do next

Do not run the planned 500/15,000 profile certificate from this seed set, relax
the gradient rule post hoc, promote MIS-33/NEWS/README wording to a
small-sample benefit, or start the non-Gaussian REML/AGHQ arc. Do not touch
CI-11, tier-2a/multinomial, Ayumi, Bartlett, or `docs/dev-log/check-log.md`.

## If the maintainer authorizes a retry

Start a fresh planning-only lane. It must predeclare a revised numerical-health
contract before data are generated, use a clean remote worktree and an explicit
installed-package SHA (`GLLVM_REML_FUNNEL_PACKAGE_SHA`), disjoint seeds, a
local profile smoke, and an independent raw-shard audit. Treat the current
screen only as the reason for that new design—not as evidence to pool.

## Release state

NOT READY. The existing pkgdown reference-index issue and locally host-killed
`R CMD check --as-cran` remain separate Grace-owned release blockers.
