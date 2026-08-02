# S0 evidence map — 2026-08-01

## Issue ↔ register ↔ tests

| Issue | Scope | Register | Evidence on `origin/main` @ `6a5bc352` | Disposition |
| --- | --- | --- | --- | --- |
| #336 Phase 2b grouped `mi()` | `impute = list(x = x ~ … + (1\|group))`; independent `b_x` | **MIS-27 `covered`** | `test-missing-predictor-gaussian.R`: Phase 2b boundary; supports grouped intercept; masks; `imputed()`; grouped recovery | Close **after** Rung 1 pin (gate 2 unmet below) |
| #337 Phase 2c group-level broadcast | `mi_group()` level-mismatch | No dedicated MIS row; Design 67 Phase 2c | Same file: Phase 2c boundary; one latent/group; broadcast; group recovery; unit-level still 2a; GAP-1 reject | Close citing named tests |
| #338 Phase 3 phylo `mi()` | phylo covariate field + signal gate | **MIS-28 `covered`** | `test-missing-predictor-phylo.R`: strong/weak signal, separate fields, etc. | Close citing MIS-28 |

## Fisher gate 2 (#336) — shared-group independence

Issue body: "β_x unbiased even when covariate and response share the grouping factor."

Scan result: **UNMET**. All Phase 2b fits use
`value ~ 0 + trait + (0 + trait):z + mi(x)` with **no** response-side `(1 | grp)`.
Covariate side alone uses `(1 | grp)`.

**Call:** run S2 Rung 1 thin pin, then close #336.

## Root LOOP/

Tracked `LOOP/` on main is the **0.6 release** arc-loop. This lane uses
`lanes/missing-data-ledger-336/LOOP/` only.
