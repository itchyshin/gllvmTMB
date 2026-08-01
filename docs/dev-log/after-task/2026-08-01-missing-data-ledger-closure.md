# After task — missing-data ledger closure (#336/#337/#338)

**Date:** 2026-08-01  
**Branch:** `cursor/missing-data-ledger-336-20260801`  
**Worktree:** `/private/tmp/gllvmtmb-missing-data-336-20260801`  
**Base:** `origin/main` @ `6a5bc352`

## Scope

Close GitHub ledger debt for shipped Phase 2b / 2c / 3 missing-predictor work.
Add the missing Fisher shared-group independence pin for #336 gate 2.
Point the next D-113 capability lane at Design 107 (VA missing-data), not a
greenfield Phase 2b rebuild.

## Outcome

| Issue | Disposition | Evidence |
| --- | --- | --- |
| #336 Phase 2b | **CLOSE** | MIS-27 `covered` + Phase 2b `test_that` blocks + new shared-group independence pin (`b_x_hat` abs err 0.044 vs tol 0.35) |
| #337 Phase 2c | **CLOSE** | Phase 2c `test_that` blocks in `test-missing-predictor-gaussian.R` (Design 67); no separate MIS row |
| #338 Phase 3 phylo | **CLOSE** | MIS-28 `covered` + `test-missing-predictor-phylo.R` |

**Not claimed:** MIS-32 / `correlate_with="response"`; Design 107 VA template work;
coverage certificates; tweedie slopes.

## Code change

- `tests/testthat/test-missing-predictor-gaussian.R` — new heavy test
  `shared-group independence: response (1|grp) + covariate (1|grp) keeps b_x unbiased`.

## Checks

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e '
devtools::load_all(quiet=TRUE)
testthat::test_file(
  "tests/testthat/test-missing-predictor-gaussian.R",
  desc = "shared-group independence: response (1|grp) + covariate (1|grp) keeps b_x unbiased",
  reporter = "summary"
)'
# Result: 1 test, 0 failed, 0 error
# Probe mirror: lanes/missing-data-ledger-336/probe-shared-group-pin.R → PROBE_PASS
#   b_x_hat=1.2939 truth=1.2500 abs_err=0.0439 gr_max=3.096e-03
```

## Definition-of-done map

1. Implementation — pin test only (engine already on main).
2. Simulation recovery — pin recovers `b_x` under shared grouping (heavy).
3. Documentation — this after-task + handover/CLAUDE/MC pointer refresh.
4. Runnable example — N/A (ledger; no new user surface).
5. check-log — entry for this lane.
6. Review — Fisher gate 2 closed by pin; Rose scope = ledger only.

## Follow-up

**Next capability arc:** Design 107 VA missing-data (Ayumi response-`include` path).
Tweedie slope remains the alternate gap-ledger pick, still gated.
Do not resume coverage re-measure (D-112).

## Lane kit

Durable loop state: `lanes/missing-data-ledger-336/LOOP/` (root `LOOP/` left
untouched — it is the 0.6 release lane).
