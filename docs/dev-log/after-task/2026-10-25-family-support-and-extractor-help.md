# After Task: Family support checks (#1356) and extractor help (#1579)

**Branch**: `cursor/family-support-extractors-6728`
**Date**: `2026-10-25`
**Roles (engaged)**: Curie, Pat, Rose, Boole

## 1. Goal

Close the remaining #1356 support-check gap (binomial integrality, plus the sibling families that had the same hole) and the remaining #1579 help-page items so the extractor docs match behaviour.

## 2. Implemented

Plain `poisson()` and `nbinom2()` already aborted on a negative or non-integer `y` (PR #1658). This slice adds the same early abort for `binomial()` and the sibling gaps: `betabinomial()` (integer successes in `0..n_trials`), `nbinom1()` (non-negative integer), and `tweedie()` (`y >= 0`). A proportion plus `weights` is refused. The abort is classed `gllvmTMB_response_support`. Binomial and betabinomial integrality uses `abs(y - round(y)) > sqrt(.Machine$double.eps)`, so a near-integer such as `3 - 4e-10` is accepted.

Extractor help from PR #1653 already covered the #1579 checklist except two leftovers: `?extract_Sigma_table` still said the helper was "point-estimate only" in `@return` (the existing test forbids that phrase), and `?make_cross_kernel` still said "C0 coevolution prototype" and routed users only through `phylo_latent(..., vcv = K_star)`. Both are now aligned with behaviour. `devtools::document()` regenerated the matching `man/*.Rd` files.

## 3. Files Changed

- `R/fit-multi.R`: binomial, betabinomial, nbinom1, and tweedie support checks
- `R/gllvmTMB.R`: multi-trial binomial help now says `y` is the success count
- `R/extract-sigma-table.R`: `@return` no longer calls the helper point-estimate only
- `R/kernel-helpers.R`: `make_cross_kernel()` description names both kernel and phylo consumers
- `man/extract_Sigma_table.Rd`, `man/gllvmTMB.Rd`, `man/make_cross_kernel.Rd`
- `tests/testthat/test-family-support-checks.R`
- `tests/testthat/test-issue-1579-extractor-help-text.R`
- `NEWS.md`
- `docs/dev-log/after-task/2026-10-25-family-support-and-extractor-help.md`
- `docs/dev-log/check-log.d/2026-10-25-family-support-extractors.md`

## 3a. Decisions and Rejected Alternatives

Decision: refuse a binomial/betabinomial proportion plus `weights`, rather than convert it. Rationale: the issue comment measured that path as a silent wrong model (intercepts near `log(p/N)`). Rejected: a warning that still fits. Confidence: high; the existing `weights = n_trials` tests already pass the success count, not a proportion.

Follow-up (R review on PR #1689): binomial and betabinomial integrality now uses `abs(x - round(x)) > sqrt(.Machine$double.eps)` for both `y` and `n_trials`. The new support aborts are classed `gllvmTMB_response_support`. NEWS now leads with the breaking change that a proportion plus `weights = n` is refused.

Decision: name both `kernel_*()` and `phylo_latent(..., vcv = )` as consumers of `make_cross_kernel()`. Rationale: the leftover #1579 item was an exclusive route, not a missing helper. Rejected: picking one recommended engine without a new maintainer ruling.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-10-25-family-support-extractors.md`.

Focused: `test-family-support-checks.R` FAIL 0 / WARN 0 / SKIP 0 / PASS 19 after the R-review follow-up (classed errors, near-integer tolerance test); `test-issue-1579-extractor-help-text.R` FAIL 0 / WARN 0 / SKIP 0 / PASS 23.

`R CMD check --no-manual --as-cran` after the R-review follow-up: Status 4 NOTEs, 0 WARNINGs, 0 ERRORs. Package tests `[ FAIL 0 | WARN 54 | SKIP 2069 | PASS 22638 ]`. Details in `docs/dev-log/check-log.d/2026-10-25-family-support-extractors.md`.

## 5. Tests of the Tests

The new binomial / nbinom1 / betabinomial / tweedie abort tests fail on origin/main: negative poisson/nbinom2 already abort, but binomial `y = 0.5` and `nbinom1`/`tweedie` negatives do not. After the fix they match the named family message and are not `gllvmTMB_all_restarts_failed`. The proportion-plus-weights case is the trap from the #1356 comment. The #1579 Rd tests fail if `document()` reintroduces "point-estimate only" or "C0 coevolution prototype".

## 6. Consistency Audit

```
rg -n "because this helper is point-estimate only|C0 coevolution prototype|C2 recovery" R man tests NEWS.md
```

Verdict: the forbidden phrases remain only as negative tests and one NEWS line that says they were removed.

```
rg -n "non-negative integer|proportion plus" R/fit-multi.R R/gllvmTMB.R NEWS.md tests/testthat/test-family-support-checks.R
```

Verdict: binomial, betabinomial, poisson, nbinom2, nbinom1, and the zi/censored siblings all name the same integer support; tweedie is non-negative only.

```
rg -n "—" R/fit-multi.R R/extract-sigma-table.R R/kernel-helpers.R tests/testthat/test-family-support-checks.R tests/testthat/test-issue-1579-extractor-help-text.R
```

Verdict: none in the touched new prose.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

- https://github.com/itchyshin/gllvmTMB/issues/1356 : remaining binomial integrality plus sibling gaps. Closed by this PR.
- https://github.com/itchyshin/gllvmTMB/issues/1579 : remaining extractor / `make_cross_kernel` help wording. Closed by this PR.
- Inspected PR #1658 and PR #1653 as the prior partial landings.

## 8. What Did Not Go Smoothly

`devtools::document()` on roxygen2 8.1.1 also rewrote `NAMESPACE` import grouping, bumped `Config/roxygen2/version`, and expanded `man/tidy.gllvmTMB_multi.Rd`. Those three files were reverted so the PR stays on the two issues.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Curie: the new tests pin abort-before-fit for each named family, and they pin that the abort is not the restart failure. A successful tweedie fit was deliberately not required, because Tweedie support is `y >= 0` and a full fit is not the claim.

Pat: the binomial help now says `y` is the success count. A proportion plus `weights` is the path a glm() user will try first; it now names that mistake.

Rose: the #1579 test file is the ratchet. The leftover "point-estimate only" phrase would have failed it on this SHA; that is why the `@return` edit belongs in this slice.

Boole: binomial and betabinomial share one message shape; nbinom1 joins the existing poisson/nbinom2 count check by family id rather than a third copy of the wording.

## 10. Known Limitations And Next Actions

No public claim that every family now has a complete support table. Gaussian, student-t, and other unbounded families are unchanged. `n_trials` integrality is checked for binomial and betabinomial; other trial-like inputs still rely on the existing range checks. No validation-debt row was promoted.
