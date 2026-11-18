# Runnable help examples for the 17 extractor pages (#1346, part C)

## Scope
- **The gap (#1346).** Seventeen extractor help pages wrapped their whole `\examples` section in
  `\dontrun{}`, so `example(<topic>)` ran nothing and `R CMD check` never executed them. The
  pages are:
  - `extract_Sigma`, `extract_Gamma`, `predict_cross_covariance`, `extract_coevolution_modules`
    (`R/extract-sigma.R`);
  - `extract_Sigma_table` (`R/extract-sigma-table.R`);
  - `extract_correlations`, `extract_cross_correlations` (`R/extract-correlations.R`);
  - `compare_dep_vs_two_psi`, `compare_indep_vs_two_psi` (`R/extract-two-psi-cross-check.R`);
  - `extract_repeatability`, `extract_latent_scores`, `extract_cutpoints` (one file each);
  - `extract_communality`, `extract_ordination` (`R/extractors.R`);
  - `getREsd` (`R/re-uncertainty.R`), `gllvmTMB_multi-vcov` (`R/vcov-coef.R`) and
    `standard_errors` (`R/standard-errors.R`).
- **Hidden behind the wrapper.** Twelve of the seventeen used an undefined `df`, `fit`, `dat`,
  `tree` or `ordinal_dat`. Others had problems that would have shown once unwrapped:
  - `latent(d = 2)` with Psi on 4 traits (11 parameters for 10 covariance elements; not identified);
  - `level = "phy"`, which `predict_cross_covariance()` rejects on a kernel fit;
  - the deprecated global `phylo_vcv =`;
  - a bare `latent()`, which prints the one-time "now includes Psi by default" warning;
  - a 200-draw bootstrap in an always-run example.
- **Lane limits.** Only roxygen `@examples` lines change in the eleven R files, plus the
  regenerated Rd files, one new test and this report. No code lines, no `NAMESPACE`, no `NEWS.md`.
  `?getLV` / `?getLoadings` live in `R/output-methods.R`, which another lane owns, so they stay
  for a later wave.

## Outcome
- **Every page runs on its own simulated data,** with current syntax: explicit `unit =`, explicit
  `unique =`, in-keyword `vcv =`. None needs a Suggests package except the
  `requireNamespace("ggplot2")`-guarded heatmap on `?extract_correlations`.
- **Each fit is a clean fit.** Every fit converges (nlminb code 0) with a positive-definite
  Hessian, no boundary variance and an identified parameter count. Two agents checked this
  independently for each page.
- **Each page is small.** About 1-2 s on its own, and 25 s for all 17 under `devtools::test()`.
  See the PR for the `R CMD check --timings` table.
- **`\donttest{}` is used only for four parametric bootstraps:** `extract_Sigma_table`,
  `extract_correlations`, `extract_repeatability` and `extract_communality`, at 15-37 s each.
  Each is labelled in the example as slow and below the warning-free 999 resamples. Each says
  real analyses need several hundred, and that the intervals are not coverage-certified.
- **Comments are checked claims.** Each example compares its estimates with the simulation truth
  where that is meaningful (correlations, repeatabilities, communalities, cutpoints, Gamma,
  latent scores up to sign). Reviewers verified every stated identity, for example total =
  shared + diag(Psi), and `predict_cross_covariance` = kernel entry x Gamma entry.
- **Honest about what the diagnostics show.** The two-psi pages show both components flagged on
  data simulated from the paired model itself. They say a flag means the fits disagree, not that
  the paired model is wrong (filed as #1571).
- **Forcing test** `tests/testthat/test-examples-run-1346c.R`, three checks per page:
  1. **static:** code outside both `\dontrun` and `\donttest`;
  2. **routine:** the always-run code parses, runs without error and **without warnings**, and
     creates objects;
  3. **heavy-gated** (`skip_if_not_heavy()`): the full example including `\donttest` runs
     without error.

  The two two-psi pages emit a spurious package warning (#1568). The test **pins** it: the
  warning must still occur and must be the only one, so the pin fails once #1568 is fixed and
  forces removal of the pin and of the one-line note in the two examples.

## Checks
Cloud session: R 4.5.3, roxygen2 8.0.0 (as pinned in `DESCRIPTION`) and TMB 1.9.23 from
conda-forge, because CRAN is unreachable from the session. `NOT_CRAN=true`.
- **Red on base** (`aec24e1`, red-proof PR #1564): 34/51 blocks fail with 51 failed
  expectations; with `GLLVMTMB_HEAVY_TESTS=1`, 51/51 fail.
- **Green on the fix:**
  - routine: 51 blocks, 104 expectations passed, 0 failures, 17 heavy skips;
  - heavy: 51 blocks, 138 expectations passed, 0 failures.
- **`R CMD check --as-cran --run-donttest --timings --no-manual --no-tests --ignore-vignettes`:**
  `checking examples ... [159s/147s] NOTE`. The only example NOTE is "elapsed > 5 s", for:
  - the four `\donttest` bootstraps: 33.2, 33.2, 20.8 and 13.2 s;
  - `compare_dep_vs_two_psi` at 7.3 s elapsed with 20.5 s CPU. This was multithreaded-OpenBLAS
    oversubscription while the full test suite ran alongside; the page takes 1.8 s uncontended.

  The other 12 pages take 0.10-0.92 s each. The overall result is 2 WARNINGs and 5 NOTEs, all
  pre-existing or environmental:
  - no `en_US.UTF-8` locale in the container;
  - the duplicated `\argument` in `gllvmTMB_julia-methods.Rd`;
  - `TMB:::EvalADFunObject`;
  - conda's `-march=nocona`;
  - blocked network (time and URL checks).

  The first attempt failed in `?add_utm_columns`, which this PR does not touch, because conda's
  PROJ database was not on the path. It passed once `PROJ_DATA` / `GDAL_DATA` were set.
- **Full `devtools::test()`** (all 675 files, no failure cap): 4394 blocks, 29473 expectations
  passed, 907 skipped, 22 failed expectations, 3 errors. **None is attributable to this PR.**
  - **Base vs branch.** I re-ran all 12 failing files on this branch and on base `aec24e1` (the
    red-proof worktree), both with a UTF-8 locale and conda's PROJ data on the path. The same
    10 tests fail on both, and nothing fails only on this branch:
    - `control-field-surface` (as #1561 reports);
    - `loading-unpack-contract` (it scans `src/gllvmTMB.cpp`);
    - three vdiffr visual snapshots;
    - `interval-calibration-claims` x 2;
    - `interval-calibration-ci09` (it needs a clean checkout);
    - `reader-facing-no-register-codes` (pkgdown navigation);
    - a 1.8e-6 vs 1e-6 tolerance in `va-r3-prototype`.
  - **Environment-only failures** that pass once a UTF-8 locale and PROJ data are present:
    `utm-conversions`, `gapclose-parity-ledger`, `g3-smallest-smoke-packets` and
    `zz-mspl-fenced-family-tapes`.
  - **Flaky:** the `isdm-diagnostic-runner` process-group watchdog failed once on each tree.
- **Scope.** A script checked that every changed `R/` line is a roxygen line inside an
  `@examples` block and every `man/` change lies inside `\examples{}`. `tools::checkRd()` is
  clean on all 17 pages. `tools/check-reader-surface.sh` passes. `devtools::document()` also
  rewrote the three `S3method(stats::sigma, ...)` lines; that drift predates this PR (#1558), so
  it was reverted.
- **Review.** Each page went through a drafting agent and then an adversarial reviewer. The
  reviewer re-ran the example in a fresh session, checked convergence, PD Hessian, boundary and
  identifiability, checked every comment against the output, checked the reader-quality bar, and
  re-ran the scope `git diff`. All ten files passed after fixes; the open reviewer nits are
  listed under Follow-up.
- **A timing artefact, not a defect.** Under `devtools::test()` the first page to run absorbs
  about 12 s of R's JIT byte-compilation of `gllvmTMB_multi_fit()`, because `load_all()` code is
  not pre-compiled. The installed package is byte-compiled, so `R CMD check` and users are not
  affected (`?compare_dep_vs_two_psi`: 14.0 s under `load_all()`, 1.96 s installed).

## Issues filed (found here, out of lane)
- #1568: two-psi cross-checks always warn about an unused `unit_obs` (pinned in the test).
- #1569: `extract_repeatability()` leaves the Gaussian residual out of R with replicate
  `unit_obs` rows (0.54 reported vs 0.22 including noise).
- #1570: `extract_coevolution_modules()` singular values are identically 1 when d <= traits per
  lineage.
- #1571: the two-psi `flag` at threshold 0.10 flags correctly specified data almost always.
- #1572: `compare_dep_vs_two_psi()` cannot refit when `unit` != cluster column.
- #1573: `check_gllvmTMB()` is stale after `standard_errors()`.
- #1574: explicit `indep()` on single-observation ordinal traits collapses silently.
- #1575: a `family_var = "trait"` family list fails with a multinomial trait.
- #1576: the bootstrap wrappers warn at their own defaults.
- #1577: tier label `"B"`, and `extract_cutpoints()` row names.
- #1578: kernel-helper `level` aliases and the non-identified shipped coevolution example.
- #1579: docs text errors on the extractor pages.
- #1580: messages that name terms the user did not write.
- #1581: `simulate_site_trait()` performance.

Already filed, not duplicated: #1393, #1399, #1556, #1557, #1558.

## Follow-up
- When #1568 lands, delete its two entries in `known_warnings_1346c` and the notes in the two
  two-psi examples.
- `?getLV` / `?getLoadings` and the pages in `R/extract-omega.R`, `R/bootstrap-sigma.R` and
  `R/julia-bridge.R` remain fully `\dontrun` (#1346, later wave).
- Seed sensitivity, disclosed rather than hidden:
  - the two-psi pages use seed 18, picked from the boundary-free seeds at 64 species;
  - the `extract_latent_scores`, `extract_ordination` and `extract_communality` designs hit a
    boundary or a larger gradient at some other seeds.

  The shipped seeds are clean. Revisit if a platform's RNG or BLAS changes the fits.
- CI cost. `R CMD check --as-cran` runs `\donttest`, so the four bootstraps add roughly
  100-110 s to each of the four routine CI shards.
