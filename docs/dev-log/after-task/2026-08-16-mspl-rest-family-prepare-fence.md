# After-task: rest-family LA-MSPL prepare-fence (not admitted)

**Date:** 2026-08-16
**Lane:** `cursor/mspl-rest-family-prepare-fence`
**Worktree:** `/tmp/gllvmtmb-mspl-rest-family-fence`
**Branch:** `cursor/mspl-rest-family-prepare-fence` (rebased onto `origin/main` @ `f3bd4e6a`, #1007)

## 1. Goal

Add a live public-door reject for the ten families that
`test-mspl-prepare-fence.R` does not name (NB1/NB2/beta/Tweedie
already live there). Sibling oracle PRs are source-scan only.
This is not a Phase-4 oracle, not a registry row, and not a door.

## 2. Implemented

`tests/testthat/test-zz-mspl-rest-family-prepare-fence.R` calls
`gllvmTMB(..., estimator = "mspl")` and requires class
`gllvmTMB_mspl_unsupported` plus the current door sentence
("gaussian, bernoulli, Poisson, nbinom1, or nbinom2" after #1007) for:

- Gamma(log), lognormal, student, ordinal_probit
- delta_lognormal, delta_gamma
- truncated_poisson, truncated_nbinom2
- betabinomial (`cbind(succ, fail)`)
- multinomial (single categorical trait)

A registry pin asserts none of those names is `planned` or
`admitted` on this `main`.

The file is `test-zz-*` so it runs after `test-va-all-family-light-fits.R`. Two CI runs of the `test-mspl-*` name failed the unrelated VA `delta_lognormal_log` health gate (`healthy_starts` 2 < 3) while this file's own tests passed. No VA claim change.

## 3. Files Changed

- `tests/testthat/test-zz-mspl-rest-family-prepare-fence.R`
- `docs/dev-log/after-task/2026-08-16-mspl-rest-family-prepare-fence.md`
- `docs/dev-log/check-log.md`

Not touched: `R/mspl.R`, `R/mspl-registry.R`, `src/`, NEWS,
validation-debt register, sibling oracle files.

## 3a. Decisions and Rejected Alternatives

- **Decision:** live `gllvmTMB()` reject, not `readLines("R/mspl.R")`.
  **Rationale:** #1003 CI died on `test_path("../../R/mspl.R")` under
  `R CMD check`. **Rejected:** source-path fence.
- **Decision:** do not add C++ tapes. **Rationale:** Gamma/lognormal
  notes pin oracles and explicitly do not license a tape; user
  prefer-R-oracles-first. **Rejected:** fenced `W=φ` / `W=1/σ²` branches.
- **Decision:** no planned registry rows. **Rationale:** sibling
  #1003/#1004/#1007/#1014 own `R/mspl-registry.R`. **Rejected:**
  a competing registry edit.

## 4. Checks Run

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
# worktree /tmp/gllvmtmb-mspl-rest-family-fence
pkgload::load_all(".", compile = FALSE)
testthat::test_file("tests/testthat/test-zz-mspl-rest-family-prepare-fence.R")
# FAIL 0 / WARN 0 / SKIP 0 / PASS 11
testthat::test_file("tests/testthat/test-mspl-prepare-fence.R")
# FAIL 0 / WARN 0 / SKIP 0 / PASS 4
testthat::test_file("tests/testthat/test-mspl-registry.R")
# FAIL 0 / WARN 0 / SKIP 0 / PASS 28
git diff --stat -- src/ R/mspl.R R/mspl-registry.R
# empty
```

## 5. Tests of the Tests

Ordinal first failed because `rep(1:3, length.out = 24)` aligned
one category per trait. Fixture now cycles by site so every trait
sees K≥2. That failure is the proof the call reaches family
validation, then the MSPL door.

## 6. Consistency Audit

```sh
rg -n 'fam_ids %in%' R/mspl.R
# still c(0L, 1L, 2L)
rg -n 'status = "admitted"' R/mspl-registry.R
# binomial / gaussian / poisson only
rg -n 'estimator = "mspl"' tests/testthat/test-zz-mspl-rest-family-prepare-fence.R
# live rejects only
```

## 7. Roadmap Tick

N/A — fence test only; no ROADMAP row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. Coordination comments
left on #1003 (R/mspl.R path), #1005 (VA flake), #1022 (EOF blank).

## 8. What Did Not Go Smoothly

Every `family_id` already had a sibling oracle or admit PR. This
slice is the leftover live door, not a new family prep.

## 9. Team Learning

Curie: live door beats source-path reads under `R CMD check`.
Rose: do not fork #1023–#1025 oracles; do not edit the registry
while #1003/#1004/#1007/#1014 are open.
Shannon: #974 landed on `main` mid-sitting (`937ce216`).

## 10. Known Limitations And Next Actions

- Planned rows still wait for the sibling registry drain.
- C++ tapes for fid 3/4/8/9/10/11/12/13/14 stay unowned and
  unlicensed by the current notes.
- Do not admit anyone new. Lane B untouched.
