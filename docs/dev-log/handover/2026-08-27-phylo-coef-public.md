# Handover — public response-column coefficients

**Branch:** `codex/phylo-coef-public`
**Base:** `e431f7890a425d76f29cff072682ec0514226801`
**State:** implementation merged normally and exact-main verification passed;
terminal documentation closeout and lease release remain.

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

## Protected landing receipt

Reviewed head `0cdc8ec90cf9eb89e146eb22039abb5127a75dc9` passed routine
run `33135276600` and manual three-OS run `33137341941` (macOS job
`98740165239`, Windows job `98740165303`, Ubuntu job `98740165342`). PR
#1220 merged normally without bypass at exact main
`badb45147f982c2ec34d948c7118261995485576`. Exact-main run `33139404505`,
Ubuntu job `98746636282`, passed on that SHA at 2026-08-28T04:16:39Z.

## Next safest action

Land this terminal documentation-only receipt, release
`codex:phylo-coef-public`, notify dependent lanes, link the bounded IID/phylo
completion on issue #1212 without closing its broader structured-source scope,
and delete the programme heartbeat.

## Boundaries

Do not widen into animal/kernel/spatial coefficients, non-Gaussian models,
intervals, or slope deprecation. The dense-VCV no-intercept `rho = 1` endpoint
inherits released `phylo_slope()` conditioning `K + 1e-8 I`; all public docs
disclose it. Estimated rho rejects diagonal standardized sources because the
mixture is unidentified.
