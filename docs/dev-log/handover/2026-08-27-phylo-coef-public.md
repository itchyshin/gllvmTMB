# Handover — public response-column coefficients

**Branch:** `codex/phylo-coef-public`
**Base:** `e431f7890a425d76f29cff072682ec0514226801`
**State:** local implementation and review complete; protected landing pending.

## Goal

Land exported Gaussian point-model `column_coef()` and `phylo_coef()` for long
and wide data, including fixed and estimated rho, without changing the current
warning-free/non-deprecated `*_slope()` family.

## Read first

1. `docs/dev-log/plans/2026-08-27-phylo-coef-public-ultra-plan.md`
2. `docs/design/131-response-column-coefficient-foundation.md`
3. `docs/dev-log/after-task/2026-08-27-phylo-coef-public.md`
4. `.unlazy/phylo-coef-public/GATES.md`

## Verified local state

All G1--G14 evidence is complete: symbolic/API/engine/recovery/equivalence,
487 focused coefficient assertions, 235 exact slope-equivalence assertions,
222 neighbouring slope regression assertions, built long/wide articles,
pkgdown, installed-package check, and terminal Gauss/Noether, Grace, Rose/Pat
reviews. The full local candidate verifier passed in about 18 minutes.

## Next safest action

Freeze and commit the current tree, push once under CI pacing, open one focused
PR, link issue #1212 without closing it, wait for routine CI, then dispatch one
manual exact-head Ubuntu/macOS/Windows matrix. Merge normally without bypass
only when exact-head checks are green. Verify exact merged main, release
`codex:phylo-coef-public`, notify dependent lanes, and delete the programme
heartbeat.

## Boundaries

Do not widen into animal/kernel/spatial coefficients, non-Gaussian models,
intervals, or slope deprecation. The dense-VCV no-intercept `rho = 1` endpoint
inherits released `phylo_slope()` conditioning `K + 1e-8 I`; all public docs
disclose it. Estimated rho rejects diagonal standardized sources because the
mixture is unidentified.
