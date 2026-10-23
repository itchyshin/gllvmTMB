# After Task: ordinary update() and simulate() nsim guards (#1403)

**Branch**: `cursor/oct4-1403`
**Date**: `2026-10-04`
**Roles (engaged)**: Ada, Curie, Rose

## 1. Goal

Close [itchyshin/gllvmTMB#1403](https://github.com/itchyshin/gllvmTMB/issues/1403). Ordinary (non-temporal) fits store no `call`, so `update(fit, ...)` hit the base-R message `need an object with call component`. The same issue asked `simulate()` to reject invalid `nsim` before any draw.

## 2. Implemented

- `update.gllvmTMB_multi()` now aborts on non-temporal fits and tells the user to refit from the original formula and data.
- `simulate.gllvmTMB_multi()` checks that `nsim` is a single positive integer before `set.seed()` or `replicate()`.
- New constructed-object tests cover both guards.

## 3. Files Changed

- `R/methods-gllvmTMB.R`
- `tests/testthat/test-update-nsim.R`
- `man/update.gllvmTMB_multi.Rd`
- `man/simulate.gllvmTMB_multi.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-10-04-update-nsim.md`

Did not edit `R/simulate-site-trait.R`, `R/julia-bridge.R`, or the likelihood.

## 3a. Decisions and Rejected Alternatives

Decision: refuse ordinary `update()`, do not implement a general refit.
Rationale: the method is documented as temporal-only, and ordinary fits do not save a public call.
Rejected: forwarding to `stats::update.default()` when `$call` happens to exist (variational fits). That still leaves ordinary users on the base-R message this issue reported.
Confidence: high for the reported bug; medium on later variational `update()` support.

## 4. Checks Run

```sh
Rscript --vanilla -e 'pkgload::load_all(".", compile = FALSE, quiet = TRUE); testthat::test_file("tests/testthat/test-update-nsim.R")'
# RED: FAIL 2 / PASS 0 (call-component error; invalid length)
# GREEN: FAIL 0 / WARN 0 / SKIP 0 / PASS 6
```

Did not run the full suite. Did not push. Did not open a PR. Did not comment on GitHub.

## 5. Tests of the Tests

Failure-before-fix: constructed `gllvmTMB_multi` with `temporal$active = FALSE`.
`update()` failed with `need an object with call component`.
`simulate(nsim = -1)` failed with `invalid 'length' argument` from `integer(n)`.
After the guards, both tests pass without a real fit.

## 6. Consistency Audit

- `need an object with call component` in `R/methods-gllvmTMB.R`: gone from the ordinary path.
- `nsim` validation sits at the top of `simulate.gllvmTMB_multi()`.

## 7. Roadmap Tick

N/A. Bugfix only.

## 7a. GitHub Issue Ledger

Inspected #1403. No comment posted (lane instruction). Issue stays open until a later PR.

## 8. What Did Not Go Smoothly

`roxygen2::roxygenise()` tried to recompile TMB. Stopped it and synced the two Rd files to the roxygen text.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept the slice on #1403 and stayed in the named worktree.
Curie: constructed objects were enough; a 40-unit Gaussian fit was not required.
Rose: the method title already said temporal-only; the bug was the silent fall-through to `update.default()`.

## 10. Known Limitations And Next Actions

`update()` still does not refit ordinary or variational models. That needs a saved public call, which is a later slice. Local commit only.
