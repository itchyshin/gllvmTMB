# After Task: Public predictive diagnostics for #228

**Branch**: `codex/public-diagnostics-228-2026-05-25`
**Date**: `2026-05-25`
**Roles (engaged)**: `Ada / Fisher / Florence / Emmy / Grace / Rose / Pat / Shannon`
**Spawned subagents**: none

## 1. Goal

Promote the #222 fitted-model predictive diagnostic prototype into the
public #228 API without making a Bayesian posterior-predictive claim.

## 2. Implemented

- Added exported `predictive_check()` for fitted-model diagnostic plots:
  randomized-quantile Q-Q, count rootogram, grouped statistics, and density
  overlay.
- Added `residuals.gllvmTMB_multi()` with exact family-CDF
  randomized-quantile residuals for Gaussian, Poisson, and NB2 rows, plus a
  simulation-rank fallback.
- Deleted the non-exported prototype file and prototype-only test.
- Attached `check_gllvmTMB()` rows and `fit$fit_health` snapshots to both
  residual and plot objects through `attr(x, "gllvmTMB_diagnostic")`.
- Updated roxygen/Rd, NAMESPACE, pkgdown reference placement, NEWS, ROADMAP,
  Design 51, and DIA-11 / DIA-12.

## 3. Mathematical Contract

No TMB likelihood, formula grammar, family parameterisation, or fitted-object
estimator changed.

For exact residuals, the public diagnostic uses:

```text
continuous: u_i = F_i(y_i)
discrete:   u_i ~ Uniform(F_i(y_i^-), F_i(y_i))
residual:   r_i = Phi^{-1}(u_i)
```

For simulation-rank residuals, the fallback uses:

```text
u_i = (#{yrep_is < y_i} + Uniform(0, #{yrep_is = y_i} + 1)) / (S + 1)
r_i = Phi^{-1}(u_i)
```

These are diagnostic residuals for the fitted response distribution. They are
not interval calibration, latent-rank proof, formal DHARMa-equivalent tests, or
Bayesian posterior predictive checks.

## 4. Files Changed

Implementation:

- `R/predictive-diagnostics.R`
- `NAMESPACE`

Tests:

- `tests/testthat/test-predictive-diagnostics.R`
- `tests/testthat/test-ppcheck-diagnostics-prototype.R` (deleted)

Documentation and ledgers:

- `man/predictive_check.Rd`
- `man/residuals.gllvmTMB_multi.Rd`
- `_pkgdown.yml`
- `NEWS.md`
- `ROADMAP.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/51-posterior-predictive-diagnostics.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-25-public-predictive-diagnostics-228.md`
- `docs/dev-log/recovery-checkpoints/2026-05-25-080241-ada-checkpoint.md`

Prototype retired:

- `inst/prototypes/ppcheck-diagnostics.R` (deleted)

## 5. Checks Run

Completed:

- `Rscript --vanilla -e 'parse("R/predictive-diagnostics.R"); parse("tests/testthat/test-predictive-diagnostics.R")'`
  -> parsed both files successfully.
- `air format R/predictive-diagnostics.R tests/testthat/test-predictive-diagnostics.R`
  -> completed; scope was restricted to touched R/test files.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> loaded `gllvmTMB`; wrote `NAMESPACE`, `predictive_check.Rd`, and
  `residuals.gllvmTMB_multi.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "predictive-diagnostics")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 103`.
- `Rscript --vanilla -e 'devtools::test(filter = "predictive-diagnostics|sanity-multi")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 129`.
- `Rscript --vanilla -e 'devtools::test()'`
  -> `FAIL 0 | WARN 1 | SKIP 13 | PASS 2734` in 696.9s. The warning is
  the pre-existing `level = "spde"` deprecation warning in
  `test-spatial-latent-recovery.R`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `tail -5 man/predictive_check.Rd man/residuals.gllvmTMB_multi.Rd`
  -> both files end after their example blocks.
- `grep -Hc '^\\keyword' man/predictive_check.Rd man/residuals.gllvmTMB_multi.Rd`
  -> both files report `0`.
- `git diff --check`
  -> clean.
- `find vignettes -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -print`
  -> no output.

Deliberately not run:

- `devtools::check(args = "--no-manual")`; full package tests and
  `pkgdown::check_pkgdown()` are green locally, but the stacked PR still needs
  ordinary 3-OS CI after #257 is settled.
- `pkgdown::build_articles(lazy = FALSE)`; this slice added reference docs and
  did not touch article code chunks or formula parsing.

## 6. Tests Of The Tests

The new tests satisfy the boundary-case rule: they retain non-finite observed
values, unsupported exact-family rows, count rootogram validation, and explicit
argument-conflict failures.

They also satisfy the feature-combination rule: residual and plot objects must
carry `check_gllvmTMB()` and `fit_health` metadata from the #257 fit-health
surface, so this #228 API is tested against the current diagnostic stack rather
than only against isolated plotting code.

The full `devtools::test()` run checks that registering
`residuals.gllvmTMB_multi()` does not break neighbouring method dispatch.

## 7. Consistency Audit

Rose PASS for the scoped public story. NEWS, roxygen, generated Rd, Design 51,
the validation-debt register, and ROADMAP now agree that this is a fitted-model
diagnostic surface, not posterior prediction, interval calibration, or a formal
residual-test suite.

Exact scans:

- `rg -n 'posterior predictive|posterior-predictive|posterior draws|Bayesian posterior|pp_check|gllvmTMB_pp_check_prototype|inst/prototypes/ppcheck-diagnostics|test-ppcheck-diagnostics-prototype' NEWS.md ROADMAP.md _pkgdown.yml R/predictive-diagnostics.R man/predictive_check.Rd man/residuals.gllvmTMB_multi.Rd docs/design/51-posterior-predictive-diagnostics.md docs/design/35-validation-debt-register.md tests/testthat/test-predictive-diagnostics.R`
  -> intentional hits only: Design 51 cites sister-package `pp_check()`
  patterns and every public hit rejects Bayesian posterior-predictive claims.
- `rg -n 'Exact family-CDF randomized-quantile residuals remain future|Non-exported prototype|not a public API promise|Out Of Scope.*Exported|Until this gate passes.*partial|#228 stays parked|Starts after #248' ROADMAP.md NEWS.md docs/design/51-posterior-predictive-diagnostics.md docs/design/35-validation-debt-register.md _pkgdown.yml R/predictive-diagnostics.R tests/testthat/test-predictive-diagnostics.R man/predictive_check.Rd man/residuals.gllvmTMB_multi.Rd`
  -> no output.
- `rg -n 'DIA-11|DIA-12|predictive_check|residuals\\.gllvmTMB_multi|gllvmTMB_diagnostic|fit_health|check_gllvmTMB' NEWS.md ROADMAP.md _pkgdown.yml R/predictive-diagnostics.R man/predictive_check.Rd man/residuals.gllvmTMB_multi.Rd docs/design/51-posterior-predictive-diagnostics.md docs/design/35-validation-debt-register.md tests/testthat/test-predictive-diagnostics.R`
  -> row IDs, exports, metadata, pkgdown placement, tests, and generated Rd are
  all visible.
- `rg -n 'Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|meta_known_V|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(' NEWS.md ROADMAP.md docs/design/51-posterior-predictive-diagnostics.md docs/design/35-validation-debt-register.md R/predictive-diagnostics.R man/predictive_check.Rd man/residuals.gllvmTMB_multi.Rd tests/testthat/test-predictive-diagnostics.R`
  -> expected existing `meta_known_V()` compatibility and
  `gllvmTMB_wide(Y, ...)` soft-deprecation hits only; no new #228 drift.

## 8. Roadmap Tick

`ROADMAP.md` now marks #228 predictive diagnostics as the active public API
branch, and the Diagnostics horizon row names fitted-model predictive checks
and residual diagnostics explicitly.

## 9. GitHub Issue Ledger

Inspected:

- #228: `Promote diagnostic prototype to public pp_check and residual API`.
  This branch implements the public API decision, exact Gaussian / Poisson /
  NB2 residuals, rootograms, metadata, roxygen/Rd, pkgdown placement, and
  DIA-11 / DIA-12 movement. The issue should close only after the stacked PR
  is opened, reviewed, and CI passes.
- #222: closed prototype lane; this branch retires the prototype file rather
  than keeping two diagnostic surfaces.
- #257: open base PR `Add identifiability diagnostics to check_gllvmTMB`;
  Ubuntu, macOS, and Windows R-CMD-check were green when inspected.
- #258: unrelated M3 workflow PR; CI was in progress when inspected. Its
  workflow/script files are not touched here.
- #230: article surface reset ledger; not directly changed by this API slice.

No issue comment has been posted yet. Post the PR and CI evidence once the
stacked branch is pushed.

## 10. Team Learning

Ada: kept the parked #228 implementation but rewrote the ledgers against the
current #257 stack rather than replaying stale check-log text.

Fisher: kept exact randomized-quantile residuals separate from simulation-rank
fallbacks, and kept both as diagnostics rather than interval or rank evidence.

Florence: required returned plot objects with inspectable data and fit-health
metadata, plus count-rootogram labels that name the count-family scope.

Emmy: kept the API package-specific (`predictive_check()`) and registered the
ordinary `residuals()` S3 method without inventing a second residual class.

Grace: required roxygen/Rd, pkgdown placement, focused tests, full tests, and
`pkgdown::check_pkgdown()` before treating the branch as locally coherent.

Rose: forced the prototype wording, validation-debt rows, roadmap queue, NEWS,
and reference docs to agree on one scoped story.

Pat: the user-facing examples remain small copyable Gaussian/Poisson fixtures.
The next applied-user layer should be a Tier-1 diagnostic article only after
Florence and Fisher review real examples.

Shannon: flagged WARN, not FAIL, at branch switch: #257 is the base stack and
#258 is unrelated M3 workflow work. No spawned subagents are running.
The recovery checkpoint records the current dirty tree, validation commands,
and next safest action.

## 11. Known Limitations And Next Actions

- Exact residuals are limited to Gaussian, Poisson, and NB2 rows.
- Unsupported families are retained with row status; they are not silently
  promoted to exact residual support.
- No formal DHARMa-equivalent tests, posterior predictive draws, interval
  calibration, or latent-rank selection claims are made.
- The diagnostic article remains intentionally planned, not shipped.
- Next safe action: review the diff, then push/open the stacked #228 PR after
  confirming the desired base against #257.
