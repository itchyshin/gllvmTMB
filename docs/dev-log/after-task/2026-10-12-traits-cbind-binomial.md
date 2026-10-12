# cbind() binomial traits: wide traits() support and mixing with other families (#1494)

## Scope
- **The reported bug (#1494).** `traits(cbind(s, f), ...)` failed with "object not found".
  `rewrite_traits_lhs()` sent every `traits()` argument to tidyselect, which only accepts
  column selections.
- **Found while fixing it: mixed fits were impossible in both shapes.** In long format, a
  two-column response was treated as binomial on every row (`R/fit-multi.R` ~3605-3617). A
  negative Gaussian value or a zero count aborted the fit, so binomial counts could not share
  a model with other families through `cbind()`.

## Outcome
- **Engine (`R/fit-multi.R`).** In a two-column response, column 2 is the failures count only
  on rows whose family is binomial, betabinomial or zi_binomial (ids 1, 8, 19). These are the
  only families whose likelihood reads `n_trials` (`src/gllvmTMB.cpp` 3534/3552, 3623, 3862).
  Every other non-censored row:
  - takes `y` from column 1;
  - gets `n_trials = 1`, which those families ignore;
  - must have 0 in column 2, otherwise the fit aborts with
    `gllvmTMB_cbind_second_column_nonbinomial`.
- **Wide format (`R/traits-keyword.R`, `R/gllvmTMB.R`).** `traits()` accepts `cbind()` pairs,
  optionally next to plain columns, in the order written.
  - A pair is named after its first argument, or after its argument name if one is given.
  - Cells are treated as missing when either count is NA or the pair has zero trials.
  - Once the family is known, `.traits_cbind_family_fixup()` does three things:
    - it refuses a pair whose family is not binomial-type;
    - it refuses a `family` list whose names don't match the traits (previously this fell
      through silently to a confusing "needs a `family` column" error);
    - it treats a plain column with a binomial-type family as Bernoulli (0/1 only).
- **`engine = "julia"`.** A two-column response is admitted only when every family is
  binomial, because the bridge sums both columns into a trial count on every row.
- **Oracle.** Every mixed fit hands TMB the same `y` and `n_trials`, and reaches the same
  objective, as the single-column `weights = trials` route that already existed.

## Checks
Run locally: R 4.3.3, TMB 1.9.10, fmesher installed from GitHub. `NOT_CRAN=true` was set
throughout so that tests do not skip.
- **`dev/traits-cbind-mixed/verify.R`** (ledger `.unlazy/traits-cbind-mixed/GATES.md`):
  - `engine`: 8 checks pass.
  - `wide`: 9 checks pass.
  - `methods`: 6 checks pass.
  - Negative control: the engine gate aborts against `HEAD`'s `R/fit-multi.R`.
- **`tests/testthat/test-traits-cbind-binomial.R`**: all assertions pass, none skipped.
- **Regression sweep (G4)** and **independent review (G6)**: see the PR.

## Follow-up
- **#1496 (pre-existing, filed).** The bootstrap and refit helpers overwrite only the successes
  column, so the trial count drifts for every `cbind` fit. CV scores `cbind` rows as Bernoulli.
- **#1412.** `predict(newdata =)` on wide fits needs long `newdata`.
- **Maintainer decisions:**
  - Merge approval: this is a likelihood-adjacent and grammar change.
  - Whether a plain 0/1 binomial column in a mixed wide call should be Bernoulli.
