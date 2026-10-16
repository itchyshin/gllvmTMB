# Runnable help examples for the 24 brms-sugar keyword pages (#1346, part A)

## Scope
- **The gap (#1346).** All 24 help pages documented in `R/brms-sugar.R` wrapped their whole
  `\examples` section in `\dontrun{}`. `example(<topic>)` therefore ran nothing, and `R CMD check`
  never executed a line of them. The pages are `dep`, `gr`, `indep`, `kernel_slope`, `latent`,
  `meta`, `meta_V`, `meta_known_V`, `phylo`, `phylo_dep`, `phylo_indep`, `phylo_latent`,
  `phylo_rr`, `phylo_scalar`, `phylo_slope`, `phylo_unique`, `scalar`, `slope`, `spatial`,
  `spatial_dep`, `spatial_indep`, `spatial_latent`, `spatial_scalar` and `spatial_unique`.
- **Hidden behind the wrapper.** Unwrapping showed that nine examples could not have run: they
  used an undefined `df`, `stage1_summary` or `mesh`. Several others ran on stale syntax:
  - `| site` where spatial keywords read `| coords`; the token is ignored with a warning;
  - the deprecated global `phylo_tree =`;
  - `latent(..., d = T)`, which R reads as `d = TRUE`, i.e. 1.
- **Lane limits.** Only roxygen `@examples` lines in `R/brms-sugar.R` change, plus the regenerated
  Rd files and one new test. No code lines, no `NAMESPACE`.

## Outcome
- **Every page runs.** Each example is self-contained on simulated data and has no `\dontrun{}` or
  `\donttest{}`. Under `R CMD check --as-cran --run-donttest --timings` each page takes at most
  2.14 s elapsed (`meta`); the 24 together take 13.8 s.
- **Each example fits a non-degenerate model.** All 32 fits created by the examples converge
  (nlminb code 0) with a positive-definite Hessian. Three design choices make this so:
  - `latent` simulates six traits with a true rank-2 covariance, which identifies `d = 2` plus Psi.
    The old example fitted 11 parameters to 10 covariance elements on data with no latent
    structure.
  - The spatial pages include the simulated site covariates in the formula. Leaving them out gave
    non-PD Hessians and a singular fit.
  - The single-site phylogenetic pages share one recipe (60 tips, `sigma2_phy = 1`,
    `sigma2_eps = 0.2`). The earlier 8- to 20-tip recipes put the phylogenetic variance on the
    boundary.
- **Comments are checked claims.** Every equivalence an example states was confirmed by equal
  log-likelihoods:
  - `dep()` = `latent(d = n_traits, unique = FALSE)`;
  - `scalar()` = `indep(common = TRUE)`;
  - `phylo(1 | species)` = `gr()` = `phylo_scalar()` = `phylo_indep(common = TRUE)`;
  - `phylo_unique()` = `phylo_indep()`;
  - `phylo_rr()` = `phylo_latent()`;
  - `kernel_slope(K = I)` = `slope()`;
  - the `spatial()` dispatch forms = their keywords;
  - `meta()` = `meta_V()` = `meta_known_V()`.
- **Deprecated-alias pages say why they print a notice** and name the equivalent canonical form.
- **Forcing test** `tests/testthat/test-examples-run-1346a.R`. For each page it checks two things:
  - the `\examples` section is not a single `\dontrun{}` block;
  - the code `example()` runs parses to at least one expression, evaluates without error and
    creates objects.

  A page guarded by `requireNamespace()` is skipped when that package is missing. Without the
  skip it would pass vacuously. The Rd comes from `man/` under `devtools::test()` and from the
  installed Rd database under `R CMD check`.

## Checks
Run in a cloud session: R 4.5.3 and roxygen2 8.0.0 (the version pinned in `DESCRIPTION`) from
conda-forge, because CRAN is not reachable from the session; TMB 1.9.23. `NOT_CRAN=true`.
- **Red on base.** The forcing test on `aec24e16` with the base package: 48/48 test blocks fail
  (24 static, 24 dynamic), with 72 failed expectations and 0 errors. Red-proof PR #1551.
- **Green on the fix.** `devtools::test(filter = "examples-run-1346a")`: 48 blocks, 120
  expectations, 0 failures, 0 warnings, 0 skips.
- **`R CMD check --as-cran --run-donttest --timings --no-manual`** on the final commit:
  `checking examples ... [52s/51s] OK`. The 3 WARNINGs and 3 NOTEs are pre-existing or come from
  the environment, not from this diff:
  - the container has no `en_US.UTF-8` locale and no `qpdf`;
  - the network is blocked, so the time check fails;
  - conda adds `-march=nocona`;
  - `TMB:::EvalADFunObject`;
  - a duplicated `\argument` in `gllvmTMB_julia-methods.Rd`.
- **Full `devtools::test()`**: see the PR for the final tally. The one failure seen so far,
  `test-control-field-surface.R:43` (`control$optimizer_diagnostics` is undeclared), is
  pre-existing on base. It skips under `R CMD check`.
- **Scope.** A script confirmed three things:
  - every changed line in `R/brms-sugar.R` is a roxygen line inside an `@examples` block;
  - the 24 Rd diffs lie only inside `\examples`;
  - `tools/check-reader-surface.sh` passes.
- **Review.** Four independent lenses, each followed by an adversarial verifier:
  - R/CRAN;
  - the test harness;
  - statistics and docs;
  - lane scope.

  They found 0 blockers. The verified findings (the unidentified `latent` example, boundary
  phylo fits, the vacuous `ape` pass and five comment nits) are fixed in the second commit.
- **Maintainer R review on #1561** ("SHIP once CI is green"):
  - The redundant `gr(species, cov = Cphy)` call is dropped (`e95beb2`).
  - `\donttest{}` was declined, because the slowest page takes 2.14 s.
  - Gating the test behind an env var is deferred until CI time shows it is needed.

## Follow-up
- **Filed while doing this:**
  - #1556: `extract_Sigma()` prints the "latent-only, refit without `unique = FALSE`" advisory on a
    `dep()` fit. The `?dep` example avoids `extract_Sigma()` for that reason.
  - #1557: `phylo(1 | g)` / `spatial(1 | g)` warn about `*_scalar()`; alias messages recommend
    soft-deprecated targets; the legacy `spatial()` warning blames the package.
  - #1558: `NAMESPACE` `stats::sigma` lines were hand-edited, so `devtools::document()` reverts
    them. This PR leaves `NAMESPACE` untouched.
  - #1559: `simulate_site_trait(n_predictors = 0)` errors.
  - #1560: page text says `d = T`, says `gr(cov =)` is unused, and calls soft-deprecated scalar
    keywords "Canonical".
- **#1346 parts B-D** cover the remaining fully-`\dontrun` pages in other files.
