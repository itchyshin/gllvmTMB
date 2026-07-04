# After Task: spatial_latent unique fold

**Branch**: `codex/r-bridge-grouped-dispersion`  
**Date**: `2026-07-03`  
**Roles (engaged)**: `Ada / Fisher / Gauss / Noether / Rose / Grace`

## 1. Goal

Implement the R/TMB contract
`spatial_latent(..., unique = TRUE)` as the spatial total covariance

```text
Sigma_spde = Lambda_spde Lambda_spde' + diag(Psi_spde)
```

while preserving `spatial_latent(..., unique = FALSE)` as the old
low-rank-only path and keeping legacy
`spatial_latent(...) + spatial_unique(...)` as compatibility syntax.

This is a prerequisite for the Ayumi site-by-trait functional
phylogeography reanalysis, especially the between-site spatial
correlation/commonality figures.

## 2. Implemented

- `spatial_latent()` now has a `unique` argument in the R API.
- Parser desugaring carries `.spatial_unique_diag = TRUE/FALSE`.
- `fit-multi.R` detects the folded spatial latent unique form and keeps
  both `omega_spde_lv` and `omega_spde` active.
- TMB receives `spde_lv_unique`; when active it fits shared SPDE latent
  fields plus per-trait unique SPDE fields.
- TMB reports `Sigma_spde_shared`, `sd_spde_unique`,
  `Psi_spde_unique`, and total `Sigma_spde`.
- `extract_Sigma(level = "spatial", part = "total")` uses total spatial
  covariance when the fold is active.
- `profile_ci_correlation(tier = "spatial")` rebuilds the same total
  covariance target by adding `exp(-2 * log_tau_spde)` to the diagonal.
- `profile_correlation(tier = "spatial")` now uses that same total
  covariance target for profile-likelihood curves, so diagnostic curve
  figures do not silently drop the unique SPDE diagonal.
- Fit summaries report shared, unique, and total spatial SDs for the
  folded form.

## 3. Files Changed

- `R/brms-sugar.R`
- `R/fit-multi.R`
- `src/gllvmTMB.cpp`
- `R/extract-sigma.R`
- `R/profile-derived.R`
- `R/profile-derived-curves.R`
- `R/methods-gllvmTMB.R`
- `tests/testthat/test-canonical-keywords.R`
- `tests/testthat/test-keyword-grid.R`
- `man/spatial_latent.Rd`
- `man/spatial.Rd`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/04-random-effects.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-03-spatial-latent-unique-fold.md`

## 3a. Decisions and Rejected Alternatives

Decision: SPDE unique variance uses `exp(-2 * log_tau_spde)`.

Rationale: the per-trait SPDE prior is
`SCALE(GMRF(Q), 1 / tau)`, so the trait-scale unique variance is
`1 / tau^2`, not `tau^2`.

Decision: keep `SPA-02` and the source-specific part of `CI-07` as
`partial`.

Rationale: the fast Gaussian parser / engine / extractor tests now pass,
but profile-interval inversion is constrained-refit work and still needs
a heavy gate before publication-grade interval claims.

Rejected alternative: promote SPA-02 to `covered` immediately after the
Gaussian fast tests. Confidence: high that this would overclaim.

## 4. Checks Run

```sh
Rscript --vanilla -e 'pkgbuild::compile_dll()'
```

Passed; only upstream Eigen unused-variable warnings.

```sh
Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|keyword-grid", reporter = "summary")'
```

Passed after a test dimnames cleanup; three `INLA`-dependent
`spatial_dep` redundancy tests skipped.

```sh
Rscript --vanilla -e 'devtools::test(filter = "stage4-spde|spatial-orientation|spatial-pair-binary|spatial-depindep-binary|profile-targets|confint-derived", reporter = "summary")'
```

Passed for non-heavy tests; heavy binary/profile cells skipped under the
normal heavy-test gate.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Regenerated `man/spatial_latent.Rd` and `man/spatial.Rd`. Existing
unresolved-link warnings remained in unrelated documentation.

```sh
Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|keyword-grid|stage4-spde|spatial-orientation", reporter = "summary")'
```

Passed; same three `INLA` skips.

```sh
Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|extractors-extra|m1-3-extract-sigma|profile-derived|profile-derived-curves|m1-4-extract-correlations", reporter = "summary")'
```

Passed for non-heavy tests; heavy extractor/profile cells skipped as
expected.

```sh
Rscript --vanilla -e 'devtools::test(filter = "keyword-grid", reporter = "summary")'
Rscript --vanilla -e 'devtools::test(filter = "profile-derived-curves|confint-derived", reporter = "summary")'
```

Passed after the profile-curve addendum. The `keyword-grid` suite now
includes the invariant that the spatial profile curve returns to the
fitted objective when evaluated at the total spatial correlation. The
profile-derived and confint-derived suites remain heavy-gated under the
normal test environment and skipped cleanly.

```sh
git diff --check -- R/brms-sugar.R R/fit-multi.R src/gllvmTMB.cpp R/extract-sigma.R R/profile-derived.R R/methods-gllvmTMB.R tests/testthat/test-canonical-keywords.R tests/testthat/test-keyword-grid.R man/spatial_latent.Rd man/spatial.Rd docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/04-random-effects.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md
```

Passed with no output.

## 5. Tests of the Tests

New tests first failed in useful ways:

- source-loaded smoke confirmed the parser must be tested through
  `pkgload::load_all()`, not only an installed package;
- the first arbitrary tiny fit converged poorly and still produced
  rank-1-looking correlations, so the test fixture was replaced with a
  Gaussian DGP drawn from the same SPDE precision used by the engine;
- extractor expectations initially failed only on dimnames, then passed.

The final fast regression coverage checks:

- parser marker `.spatial_unique_diag = TRUE`;
- `fit$use$spatial_latent_unique`;
- both `omega_spde` and `omega_spde_lv` in `fit$random`;
- TMB reports for shared, unique, and total spatial covariance;
- extractor `shared`, `unique`, and `total` parts match the report;
- rank-1 total spatial correlations are not forced to `+/-1`;
- the spatial profile-correlation curve targets total spatial
  covariance, including `Psi_spde`, at the MLE;
- legacy paired syntax activates the same fold.

## 6. Consistency Audit

Design docs now agree on the same equation and scale:

```text
Sigma_spde = Lambda_spde Lambda_spde' + diag(Psi_spde)
Psi_spde,t = tau_t^-2
```

The validation-debt register says `partial`, not `covered`, for SPA-02
and the source-specific part of CI-07. The stale-wording scan found only
intended partial/Gaussian-fold language.

## 7. Roadmap Tick

No roadmap row was changed. This slice moves the spatial total-covariance
capability from a documented gap to a fast-tested Gaussian implementation
slice, but heavy profile/family coverage remains open.

## 7a. GitHub Issue Ledger

No GitHub issue or PR was commented. The user had previously said not to
reply to Ayumi yet.

## 8. What Did Not Go Smoothly

The first smoke fit used the installed package rather than source-loaded
R code, which made the parser look unfixed. After switching to
`pkgload::load_all()`, the parser/engine path was active. The first tiny
Gaussian fit was numerically weak, so the test moved to an internally
consistent SPDE fixture.

## 9. Team Learning

**Fisher:** pdHess/gradient remain fit-health gates; derived spatial
uncertainty should use profile or bootstrap where feasible. The target
must be total covariance, not low-rank covariance, for final figures.

**Gauss:** SPDE unique variance is inverse-tau-squared. The engine must
keep two random-effect blocks active for the fold.

**Noether:** formula, symbolic covariance, TMB report, extractor, and
profile target now line up for the Gaussian fast-tested case.

**Rose:** do not promote the register row to `covered` until the heavy
profile/family gate exists.

**Grace:** focused tests pass locally; full `devtools::check()` and
`pkgdown::check_pkgdown()` were not run in this slice because the active
worktree is very dirty and this was a narrow capability repair.

## 10. Known Limitations And Next Actions

Remaining before final Ayumi-style claims:

1. Add a heavy profile gate for spatial total-covariance correlations.
2. Decide whether spatial total-covariance communality needs a dedicated
   source-specific extractor/profile helper or whether it remains an
   `extract_Sigma()`-derived diagnostic.
3. Rerun the site-by-trait functional phylogeography models with
   `spatial_latent(..., unique = TRUE)` and the within-site
   `latent(..., unique = TRUE)` / current ordinary latent-Psi path.
4. Regenerate the correlation, loadings, commonality, ordination, and map
   figures from accepted model outputs.
