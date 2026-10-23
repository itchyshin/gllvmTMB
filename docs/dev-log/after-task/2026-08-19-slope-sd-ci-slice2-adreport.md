# After Task: `slope_sd_ci()` -- Slice 2 (ADREPORT, phylo + loadings routes)

**Branch**: `claude/slope-ci-adreport-20260819`
**Date**: `2026-08-19`
**Roles (engaged)**: Curie (implementation)

## 1. Goal

Extend `slope_sd_ci()` to the two routes Slice 1 deliberately refused
(register row CI-15, `blocked`): the phylogenetic Cholesky augmented-slope
route (`theta_dep_chol`, `fit$use$phylo_dep_slope`) and the loadings-only
augmented random-slope route (`theta_rr_B_slope` with no diagonal
companion). Both need a multivariate delta method, and the design
(`dev/fable-extractor-recommendation.md` G3, `dev/S6-slope-sd-ci-review.md`)
requires it be built via `ADREPORT()` in the C++ template, never a
hand-indexed R-side Jacobian -- the exact failure mode a first attempt at
the phylo route already hit once (indexed `theta_dep_chol` entries 2/5/8
instead of the correct 2/4/6, and exponentiated a raw off-diagonal entry
as if it were a log-SD; `dev/slope-interval-feasibility-RESULTS.md`).

This touches `src/gllvmTMB.cpp` -- the highest-risk area of this repo --
so the brief required measuring, not assuming: the `sdreport()` runtime
cost of the added `ADREPORT()`s, and whether any existing consumer of
`fit$sd_report` indexes its ADREPORT ("report") block by position rather
than by name (which the new rows could silently break).

## 2. Implemented

### `src/gllvmTMB.cpp` -- additive only

- **`sd_b` in the `theta_dep_chol` (phylo_dep/phylo_indep slope) branch**
  (~line 1944): already `REPORT()`ed; now also `ADREPORT()`ed. `sd_b(j) =
  sqrt(Sigma_b_dep(j,j))` is a nonlinear function of multiple packed
  `theta_dep_chol` entries whenever coordinate `j` has off-diagonal `L`
  entries below it, so its SE needs the delta method run against the exact
  packed expression -- which `ADREPORT()` + `sdreport()` now does.
- **`sd_rr_B_slope`** (new vector, alongside the existing `Lambda_B_slope`
  / `Sigma_B_slope` block, ~line 1587): `sqrt(diag(Sigma_B_slope))`, the
  marginal per-augmented-coordinate SD from the shared loadings block
  alone. `REPORT()`ed and `ADREPORT()`ed. Serves the loadings-only route
  (`theta_rr_B_slope`, no diagonal companion).
- **`sd_B_slope_total`** (new vector, after the `diag_B_slope` block, ~line
  1654): `sqrt(diag(Sigma_B_slope) + diag(Sigma_B_unique_slope))`, i.e. the
  TRUE total marginal slope SD when both the shared-loadings and diagonal
  Psi blocks are active on the same fit (the default `latent()`
  combination). `REPORT()`ed and `ADREPORT()`ed. Computing this as ONE
  combined C++ expression -- rather than summing two separately-ADREPORTed
  SEs in R -- lets `sdreport()`'s delta method account for any correlation
  between `theta_rr_B_slope` and `theta_diag_B_slope` in the Hessian, which
  an R-side sum could not.
- Two local variables (`Sigma_B_slope`, `Sigma_B_unique_slope`) were
  hoisted from block-local scope to function scope so the new
  `sd_B_slope_total` code (which runs after both blocks) can read both
  diagonals. No existing computation, likelihood term, or `REPORT()` was
  altered; the hoisted matrices are identical zero-valued placeholders
  when their governing flag is off, exactly as before.

### `R/slope-sd-ci.R` -- route dispatch, same guards on every route

- Added `.slope_ci_adreport_lookup()`: reads an ADREPORTed vector from
  `summary(fit$sd_report, "report")` by NAME
  (`rownames(tab) == name`), never by position.
- Added `.slope_ci_natural_to_log()`: delta-method transform from a
  natural-scale ADREPORT estimate/SE to the log-SD scale
  (`se(log(X)) = se(X) / X`) so every route's interval is built the same
  way Slice 1 built it (`exp(theta +/- z*se(theta))`, positive by
  construction).
- Factored the shared kill-switch guard + interval-building logic that
  Slice 1 wrote inline into `.slope_ci_rows()` / `.slope_ci_emit_guard_warnings()`,
  and now call it from THREE routes instead of one, so non-PD Hessian,
  non-finite SE, SE blow-up, and near-zero-relative-to-siblings apply
  identically everywhere.
- New `.slope_sd_ci_phylo_dep()` and `.slope_sd_ci_loadings_only()`
  route handlers, dispatched from the top of `slope_sd_ci()` in place of
  Slice 1's two `cli_abort()` refusals. Each cross-checks its ADREPORT
  point estimate against the corresponding already-`REPORT()`ed quantity
  (`all.equal(..., tolerance = 1e-6)`) and `cli_abort()`s on an internal
  packing mismatch rather than silently returning a wrong number.
- The diagonal route (Slice 1) is otherwise byte-identical: same
  `theta`/`se_theta` computation from `fit$opt$par` /
  `fit$sd_report$cov.fixed`, same `estimate`/`lower`/`upper`. The only
  addition is that `total_sd` -- a point estimate only in Slice 1 -- now
  also gets `total_lower`/`total_upper`/`total_status` wherever
  `fit$report$sd_B_slope_total` is present (falls back to Slice 1's
  point-estimate-only formula, with `total_status = "unavailable"`, for a
  stale cached fit predating this slice).
- New columns on the returned `data.frame`: `total_lower`, `total_upper`,
  `total_status`. New `method` value `"wald_log_scale_adreport"` for the
  two ADREPORT-based routes (vs `"wald_log_scale"` for the direct-parameter
  diagonal route), so a reader can tell which mechanism produced a row.

## 3. Files Changed

- `src/gllvmTMB.cpp` (additive: 2 new `ADREPORT()`ed vectors + 1 existing
  quantity newly `ADREPORT()`ed; 2 variables hoisted to wider scope; no
  existing computation altered)
- `R/slope-sd-ci.R` (route dispatch + two new route handlers + shared
  helpers; Slice 1's diagonal route logic preserved)
- `tests/testthat/test-slope-sd-ci.R` (new mocks + guard tests + two real
  recovery/cross-check tests; three Slice-1 tests that asserted the OLD
  refusal behaviour rewritten for the new behaviour)
- `docs/design/35-validation-debt-register.md` (CI-14 updated note; CI-15
  moved `blocked` -> `partial`)
- `docs/dev-log/check-log.md` (dated entry, this file)
- `docs/dev-log/after-task/2026-08-19-slope-sd-ci-slice2-adreport.md` (this
  file)

No `NAMESPACE` change (no new exports; the two new route functions and
both helpers are internal, `@noRd`). No `DESCRIPTION` or `NEWS.md` change,
per the brief's constraints.

## 4. The Two Things The Brief Said To Measure

### 4a. `sdreport()` runtime cost

Measured with an alternating-build A/B comparison, not a single before/after
pair (a single pair on this shared, heavily-loaded development Mac showed a
LARGE apparent slowdown -- baseline median 0.45s vs slice-2 median 0.10s --
that vanished and reversed under a fair, back-to-back comparison; it was
confounded by other concurrent lanes' CPU load on this shared machine, not a
property of the code). Method: built the package twice (baseline =
`src/gllvmTMB.cpp` reverted via `git checkout`, no new `ADREPORT()`s;
slice-2 = this branch), saved both compiled `.so` files, then alternated
which one was live in the R library and re-fit + re-timed `TMB::sdreport()`
on the same representative fixture (`n_ind = 50`, `n_traits = 3`, `n_rep =
6`, `latent(0 + trait + (0 + trait):temperature | individual, d = 2)` --
activates BOTH new ADREPORTs, `sd_rr_B_slope` and `sd_B_slope_total`, 12
new report rows on top of the pre-existing 7), 4 rounds, 5 reps/round,
median per round:

```
round 1: baseline 0.066s | slice2 0.070s
round 2: baseline 0.068s | slice2 0.063s
round 3: baseline 0.107s | slice2 0.084s
round 4: baseline 0.073s | slice2 0.098s
```

**No measurable slowdown at this scale.** The two builds are
indistinguishable within this machine's noise floor (both ~0.06-0.11s);
slice-2 is faster in half the rounds. This is the expected result
architecturally: the added ADREPORT vectors are length `O(n_traits)` (2 or
`(1+s)*n_traits`), not `O(n_obs)` or `O(n_species)` -- they do not grow
with dataset size, only with the number of traits in the model, which is
small for realistic fits. `sdreport()`'s cost here is dominated by the
fixed-effect Hessian factorization (`cov.fixed`) rather than by the
report-block reverse sweeps -- "not measurably affected at this scale" is
the supported claim; "`cov.fixed` unaffected by ADREPORT count at all"
overreaches beyond what a 4-round A/B on one fixture size can show.

### 4b. Position-based consumers of `fit$sd_report`

Grepped every `R/` file that touches `sd_report` (30 files) for any use of
the `"report"` (ADREPORT) component of `summary(fit$sd_report, ...)`.
Found exactly four call sites in the whole package:

- `R/extract-cutpoints.R:101` -- `grep("^ordinal_cutpoints$", rownames(adr))`
- `R/extractors.R:798` (`.lv_sdreport_effect_se`) --
  `which(rownames(table) == row_name)`
- `R/methods-gllvmTMB.R:214` -- uses `summary(fit$sd_report, "fixed")`
  only, never touches the "report" component at all
- `R/slope-sd-ci.R` (this file, both Slice 1 and the new Slice 2 routes)
  -- `which(rownames(tab) == name)`

**Every one filters by name** (`rownames(...) == "..."` or `grep(...)`),
never by numeric position. Also checked `tests/testthat/*.R` for the same
pattern: `test-lv-gaussian-recovery.R` and `test-lv-parser-guard.R` also
read `summary(fit$sd_report, "report")` and filter by
`rownames(report) == "B_lv_unit"` -- name-based, and on fixtures that never
activate `use_rr_B_slope` / `use_diag_B_slope` / `use_phylo_dep_slope`, so
their ADREPORT vector is unchanged in content by this slice regardless.

**Everything else that touches `fit$sd_report`** (26 of the 30 `R/` files)
uses `$cov.fixed` or `$par.fixed` -- the fixed-effect covariance/point-
estimate block, whose dimension and ordering depend only on the number of
FIXED PARAMETERS (`fit$opt$par`), not on how many `ADREPORT()`ed
quantities exist. These are structurally unaffected by this slice's
changes.

**Correction (adversarial review, Rose): this audit under-counted.**
`summary.sdreport()` defaults to `select = "all"`, which INCLUDES the
report/ADREPORT block, not only the two explicit `select = "report"` call
sites named above. Four test files call the bare form
(`summary(fit$sd_report)`, no `select` argument):
`test-matrix-slope-poisson.R:153`, `test-matrix-slope-phylo-dep.R:166`,
`test-matrix-slope-phylo-latent.R:226`, `test-matrix-slope-spatial-
latent.R:180` (`.aug_wald_ci()`'s `sdr <- summary(fit$sd_report)`), each
then filtering `rownames(sdr) == entry_name` for `entry_name` in
`"log_sd_b"` / `"atanh_cor_b"` -- names that do not collide with this
slice's `"sd_b"` / `"sd_rr_B_slope"` / `"sd_B_slope_total"` rows, and the
phylo-dep file is exactly a fit that gains `sd_b` rows under this slice.
**The conclusion below survives, but by luck of the grep (all four filter
by name and none collide), not because the audit as originally stated
checked them.**

**Conclusion: no position-based consumer found anywhere in the package.**
The added ADREPORT rows cannot silently misalign an existing extractor --
verified across every `R/` consumer (30 files) AND, on the corrected
count, all four bare-`summary()` test call sites.

### 4c. `sd_b` consistency with `fit$report$sd_b`

Confirmed two ways: (1) architecturally, `ADREPORT(sd_b)` was added
immediately after the existing `REPORT(sd_b)` line with no intervening
edit to `sd_b`'s computation, so both read the identical C++ variable;
(2) empirically, both new real-fit tests (Section 6) assert
`all.equal(adr$estimate, fit$report$sd_b, tolerance = 1e-6)` (and the
`sd_rr_B_slope` / `sd_B_slope_total` equivalents) inside
`slope_sd_ci()` itself -- `cli_abort()`s loudly on any mismatch rather
than silently proceeding -- and this passed on every real-fit test.

## 5. Checks Run

- `pkgbuild::compile_dll(force = TRUE)` -- clean recompile, 4 pre-existing
  unrelated compiler warnings (Eigen `SparseLU`/`TriangularSolver` unused
  variables, one unused function in `lane_b_jeffreys_maxvol_atomic_v8.h`),
  **no new warnings** from this change's `src/` edits.
- `devtools::document()` -- clean; regenerated `man/slope_sd_ci.Rd` only.
  Pre-existing unrelated `@export`/`@exportS3Method` notes for
  `anova`/`BIC`/`AIC.gllvmTMB_multi` (not touched by this change).
- `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 devtools::load_all(); testthat::test_file("tests/testthat/test-slope-sd-ci.R")`
  -- **all pass, 0 fail** (including the heavy-gated phylo_dep recovery
  test).
- `NOT_CRAN=true devtools::load_all(); testthat::test_file("tests/testthat/test-slope-sd-ci.R")`
  (no `GLLVMTMB_HEAVY_TESTS`) -- all pass, 1 skip (the heavy-gated phylo
  test, matching house convention for every other `phylo_dep` model fit in
  this package -- `test-phylo-dep-slope-gaussian.R` gates all of its tests
  the same way).
- `testthat::test_file("tests/testthat/test-reader-facing-no-register-codes.R")`
  -- 1 pass. `man/slope_sd_ci.Rd` carries no `CI-1x` register codes (the
  module-header `##` comments in `R/slope-sd-ci.R` do, but those are plain
  comments, not roxygen `#'` lines, so they never reach the generated
  `.Rd`).
- `pkgdown::check_pkgdown()` -- "No problems found." (`slope_sd_ci` is
  already in `_pkgdown.yml`'s reference index from Slice 1).
- `NOT_CRAN=true OPENBLAS_NUM_THREADS=1 devtools::test()` (full package,
  run to completion, not backgrounded-and-abandoned) -- see Section 7 for
  the verbatim tail.

## 6. Tests of the Tests

- **New mock builders**: `mock_phylo_dep_slope_fit()` and
  `mock_rr_only_slope_fit()` hand-build an `sd_report` with `value` / `sd`
  fields (named/ordered by ADREPORT variable name) plus `pdHess`, which
  dispatches through the REAL `TMB:::summary.sdreport` S3 method (verified:
  it only reads `object$value` and `object$sd` for the `"report"` select)
  -- these mocks exercise the same code path a real fit does, not a
  hand-simplified stand-in.
- **Guard tests, both new routes, four each** (non-PD Hessian, non-finite
  SE, SE blow-up, near-zero-relative collapse) -- same structure as Slice
  1's guard tests, now proven to fire identically on the ADREPORT-based
  routes.
- **Phylo_dep route real recovery + cross-check** (heavy-gated,
  `GLLVMTMB_HEAVY_TESTS=1`, following house convention -- every other
  `phylo_dep` model-fit test in this package is heavy-gated too): fits
  `phylo_dep(0 + trait + (0 + trait):x | species)` on a 70-species,
  2-trait, known-`L` fixture (the same `L` as
  `test-phylo-dep-slope-gaussian.R`'s `.dep_Ltrue()`); asserts both slope
  CIs cover their true SDs, `component == "total"`,
  `total_sd/lower/upper == estimate/lower/upper` (no separate split for
  this route). **Correction (adversarial review, Rose): the earlier text
  here credited the WRONG assertion as the packing guard.** The
  ground-truth recovery assertion (`ci$lower <= slope_sd_true &
  slope_sd_true <= ci$upper`, with `slope_sd_true` derived from the
  simulated `L` matrix wholly outside `slope_sd_ci()`'s own code path) is
  what actually tests the C++ packing -- a wrong position (the
  2/5/8-vs-2/4/6 hazard) would show up here as a failed-to-cover interval.
  The test also carries a second, narrower check: the ADREPORTed `sd_b`,
  as read by `slope_sd_ci()`, equals (tolerance `1e-6`)
  `sqrt(diag(Sigma_b_dep))` computed directly from `fit$report`. This is
  **not** an independent construction -- `sd_b(j)` and `Sigma_b_dep(j,j)`
  are the same C++ quantity (`sd_b` is defined as `sqrt(Sigma_b_dep(j,j))`
  in `src/gllvmTMB.cpp`) -- so it is an algebraic restatement guarding
  R-side position selection (did `slope_sd_ci()` read the right ADREPORT
  rows?), not a check on the C++ packing itself. The claim that this
  cross-check "would have caught the 2/5/8 bug on day one" is retracted;
  the ground-truth recovery assertion is what would have.
- **Loadings-only route real fit + agreement check** (NOT heavy-gated --
  a plain Gaussian `latent(..., unique = FALSE)` fit, no phylogeny; runs
  in the default suite): same `sqrt(diag(Sigma_B_slope))` agreement check
  as above, same "not independent" caveat. **Correction: this is not a
  recovery test** and the underlying test was renamed
  (`"...recovers a known-truth slope SD..."` -> `"...returns a plausible
  finite interval on a misspecified fit..."`) -- under `unique = FALSE`
  the fit has no diagonal Psi companion, but the fixture's DGP simulates
  one, so the fit is misspecified against its own fixture and there is no
  known truth to recover; the test only checks the estimate lands in a
  plausible, finite order of magnitude.
- **Updated Slice-1 test**: `"slope_sd_ci() refuses a fit with no augmented
  random-slope term at all"` now asserts the new message text (the old
  message named only the diagonal route; the new one names all three).
- **New: `total_lower`/`total_upper`/`total_status` coverage** (adversarial
  review, Rose -- these columns were previously untested except where they
  trivially equal `lower`/`upper`). Two additions: (1) the real mixed-route
  fixture (diagonal Psi + shared loadings both present, the default
  `latent()` combination) now also asserts `total_status == "ok"`,
  `total_lower`/`total_upper` finite, bracket `total_sd`, and differ from
  `lower`/`upper` -- the genuinely non-trivial case, since `component ==
  "unique_psi"` there; (2) a new mock-based test exercises the
  `adr_tot$ok == FALSE` degrade branch (`R/slope-sd-ci.R:594-599`) that was
  previously reachable by no test at all, confirming it sets
  `total_status = "unavailable"` and NA bounds rather than silently
  returning a wrong number. Both were verified to FAIL against a
  temporarily broken version of the branch they guard (see this branch's
  git history / the S0a report for the proof), then the break was
  reverted.

## 7. Full Suite Result

`NOT_CRAN=true OPENBLAS_NUM_THREADS=1 Rscript -e 'devtools::test()'`, run
to completion (not backgrounded-and-abandoned). Verbatim tail:

```
health-gate marginal (ran fine, accounting correct, status != healthy): betabinomial_logit, delta_gamma_log
18-cell wall time: 28.4 s
Warning: 39 external pointers will be removed
using C++ compiler: 'Apple clang version 21.0.0 (clang-2100.1.1.101)'
using SDK: 'MacOSX26.5.sdk'
clang++ -arch arm64 -std=gnu++20 -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG -I"/Users/z3437171/Library/R/arm64/4.6/library/TMB/include" -I"/Users/z3437171/Library/R/arm64/4.6/library/RcppEigen/include"  -DTMB_SAFEBOUNDS -DTMB_EIGEN_DISABLE_WARNINGS -DLIB_UNLOAD=R_unload_gllvmTMB_va_r3  -DTMB_LIB_INIT=R_init_gllvmTMB_va_r3  -DCPPAD_FRAMEWORK  -I/opt/R/arm64/include    -fPIC  -O2  -c gllvmTMB_va_r3.cpp -o gllvmTMB_va_r3.o
clang++ -arch arm64 -std=gnu++20 -dynamiclib -Wl,-headerpad_max_install_names -undefined dynamic_lookup -L/Library/Frameworks/R.framework/Resources/lib -L/opt/R/arm64/lib -o gllvmTMB_va_r3.so gllvmTMB_va_r3.o -F/Library/Frameworks/R.framework/.. -framework R

-- Design 108 Stage 4 AD-safety, H = 15 (extreme node 6.3639 SD of eta) --
cell                      dE/dmu AD      dE/dmu FD        rel       dE/dv AD       dE/dv FD        rel  min eta
bulk bernoulli            0.7337576      0.7337576   2.69e-13     -0.2666131     -0.2666131   2.68e-12     -6.1
bulk binomial n=10       -0.5251462     -0.5251462   3.45e-12      -2.790678      -2.790678   5.16e-12     -5.4
left tail mu=-30            30.0333        30.0333   6.86e-13     -0.4994463     -0.4994463   1.22e-09    -36.4
deep tail mu=-40           40.02498       40.02498   1.48e-12     -0.4996881     -0.4996881   2.89e-09    -46.4
huge v=100                 4.059181       4.059181   6.50e-12     -0.2516668     -0.2516668   4.78e-13    -63.6
right tail mu=+30          -30.0333       -30.0333   5.23e-13     -0.4994463     -0.4994463   1.36e-11     23.6
both tails                 100.2678       100.2678   1.69e-12      -2.492238      -2.492238   2.14e-11    -51.8

-- Design 108 Stage 4 AD-safety, H = 61 (extreme node 14.4985 SD of eta) --
cell                      dE/dmu AD      dE/dmu FD        rel       dE/dv AD       dE/dv FD        rel  min eta
bulk bernoulli            0.7337576      0.7337576   2.27e-13     -0.2666131     -0.2666131   2.49e-12    -14.2
bulk binomial n=10       -0.5251462     -0.5251462   3.22e-11      -2.790678      -2.790678   1.65e-12    -11.7
left tail mu=-30            30.0333        30.0333   4.96e-14     -0.4994463     -0.4994463   5.56e-10    -44.5
deep tail mu=-40           40.02498       40.02498   1.83e-12     -0.4996881     -0.4996881   3.46e-09    -54.5
huge v=100                 4.121156       4.121156   2.24e-12     -0.2520039     -0.2520039   2.16e-12   -145.0
right tail mu=+30          -30.0333       -30.0333   3.71e-13     -0.4994463     -0.4994463   4.61e-10     15.5
both tails                 100.2678       100.2678   4.77e-13      -2.492234      -2.492234   2.25e-11    -92.5

-- Stage 4 toy: max|log Sigma_B ratio| vs Laplace probit 0.1696, vs Laplace logit 0.9653
SKIP: 'test-warm-nlminb-restart.R:515:3' ----------
Reason: Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run

SKIP: 'test-warm-nlminb-restart.R:594:3' ----------
Reason: Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run

SKIP: 'test-warm-nlminb-restart.R:629:3' ----------
Reason: Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run

SKIP: 'test-warm-nlminb-restart.R:668:3' ----------
Reason: Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run

SKIP: 'test-warm-nlminb-restart.R:688:3' ----------
Reason: Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run

SKIP: 'test-warm-nlminb-restart.R:702:3' ----------
Reason: Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run

i Auto-suppressing `sigma_eps`: `indep(0 + trait | site)` is at the per-row level, so it already absorbs the observation residual.
* Fixed at 0.000939 (~1/1000 of sd(y)) to keep the Gaussian density well-defined; the row-level residual variance is fully captured by the per-row diagonal term.
i Auto-suppressing `sigma_eps`: `indep(0 + trait | site)` is at the per-row level, so it already absorbs the observation residual.
* Fixed at 0.000939 (~1/1000 of sd(y)) to keep the Gaussian density well-defined; the row-level residual variance is fully captured by the per-row diagonal term.
SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:186:5' ----------
Reason: internal curvature pin is still fenced from Gamma

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:206:7' ----------
Reason: Gamma MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:232:7' ----------
Reason: Gamma MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:206:7' ----------
Reason: lognormal MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:232:7' ----------
Reason: lognormal MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:206:7' ----------
Reason: student MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:232:7' ----------
Reason: student MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:206:7' ----------
Reason: ordinal_probit MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:232:7' ----------
Reason: ordinal_probit MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:206:7' ----------
Reason: delta_lognormal MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:232:7' ----------
Reason: delta_lognormal MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:206:7' ----------
Reason: delta_gamma MSPL family door is missing

SKIP: 'test-zz-mspl-rest-families-se-feasibility.R:232:7' ----------
Reason: delta_gamma MSPL family door is missing

SKIP: 'test-zz-mspl-tweedie-beta-se-feasibility.R:175:3' ----------
Reason: tweedie MSPL family door is missing

SKIP: 'test-zz-mspl-tweedie-beta-se-feasibility.R:181:3' ----------
Reason: tweedie MSPL family door is missing

SKIP: 'test-zz-mspl-tweedie-beta-se-feasibility.R:199:3' ----------
Reason: Beta Q_P/Q_0 NLLs match on this cell; tapes are named but nll-difference is not informative

[ FAIL 0 | WARN 9 | SKIP 877 | PASS 16305 ]
```

**0 failures, 16,305 passes.** The 9 warnings are all in
`test-aghq-missing-response.R` (6), `test-comparator-gllvm.R` (2), and
`test-link-residual-multinomial.R` (1) -- none touch `slope-sd-ci`,
`gllvmTMB.cpp`'s slope routes, or any file this slice edited; the same
three files' warnings were already noted as pre-existing/unrelated in
Slice 1's after-task report. `grep -n "slope-sd-ci"` on the full log
shows exactly one line: `SKIP: 'test-slope-sd-ci.R:476:3'` (the
heavy-gated phylo_dep recovery test, `GLLVMTMB_HEAVY_TESTS` unset for
this run, matching house convention -- separately confirmed passing under
`GLLVMTMB_HEAVY_TESTS=1` in Section 6). No other line from
`test-slope-sd-ci.R` appears, confirming every other test in that file
passed silently within the full run.

## 8. Register Update

- **CI-14** (`partial`, unchanged status): appended a 2026-08-19 note --
  `total_sd` now also carries a genuine interval
  (`total_lower`/`total_upper`/`total_status`) wherever both
  `theta_diag_B_slope` and `theta_rr_B_slope` are present, via the new
  `sd_B_slope_total` ADREPORT. `estimate`/`lower`/`upper` for this route
  are byte-identical to Slice 1.
- **CI-15** moved `blocked` -> `partial`. **Not `covered`**: single-seed
  recovery evidence only (one cell per route), `interval_status =
  "wald_uncalibrated"` on every row, no repeated-sampling coverage
  campaign (gated by CI-08/CI-10, same framing as CI-14). The row now
  documents the ADREPORT mechanism, the two recovery cells, the
  cross-check tests, and the cost/compatibility findings from Section 4.

## 9. What Did Not Go Smoothly

- The first `devtools::install()` attempt after the C++ rebuild failed
  with a stale `00LOCK-gllvmTMB` directory in the shared
  `~/Library/R/arm64/4.6/library` -- a leftover from an earlier
  auto-backgrounded install whose foreground call had been killed at the
  120s tool timeout before its own cleanup ran. No other process held the
  lock (`ps aux` confirmed), so it was safe to clear; `R CMD INSTALL
  --no-lock` was used as a workaround for the timing-comparison rebuilds.
  This machine is shared with several other concurrent lanes' active R
  sessions (confirmed via `ps aux` during this task -- `isdm-precision`
  campaigns, another package's own install), which is also why the FIRST
  sdreport-cost measurement (single before/after pair) was misleading; see
  Section 4a.
- `pkgbuild::compile_dll(force = TRUE)` reported "make: Nothing to be done
  for `all`" once even after `git checkout -- src/gllvmTMB.cpp` reverted
  the file. **Correction (adversarial review, Rose): the mtime argument
  originally given here for trusting that "baseline" build was backwards
  and is retracted, not merely softened.** The original text reasoned that
  because the `.so` was newer than the reverted `.cpp`, a real recompile
  had occurred -- but a newer `.so` is exactly the condition under which
  `make` SKIPS a rebuild (nothing looks out of date), so it is evidence
  FOR the "nothing to be done" message, not against it; `compile_dll(force
  = TRUE)` does not clean stale `.o` files, so a `force = TRUE` call can
  still no-op against an `.o` built from different source content if the
  build system's own staleness check is satisfied by mtime alone. This
  slice's `sdreport()` cost comparison (Section 4a) was NOT re-verified
  against a clean (`.o`-deleted) rebuild of the baseline; treat the
  "baseline" arm of that A/B as unconfirmed-clean, not confirmed-fresh.

## 10. Known Limitations And Next Actions

**What this does NOT cover** (do not read a green PR here as covering any
of this):

- **No repeated-sampling coverage evidence**, same as Slice 1 and every
  other Wald route in this package. `interval_status = "wald_uncalibrated"`
  on every row, all three routes. Gated by CI-08/CI-10; unblocking needs
  Design 80 Bar 3 / the REML-AGHQ coverage arc, not this slice.
  D-112 remains in force.
- **Non-Gaussian families untested for all three routes.** The phylo_dep
  and loadings-only recovery cells built here are both Gaussian, matching
  the existing Gaussian-gating of the augmented diagonal/loadings slope
  engines elsewhere in the codebase.
- **Multi-slope phylo_dep (`s >= 2`) is supported by the R-side dispatch
  code (it derives `stride = 1 + n_phy_slope` and labels each term by its
  own covariate name) but has NO test evidence in this slice** -- the
  recovery cell built here is single-slope (`s = 1`). The dispatch logic
  was written generically because the C++ `sd_b` computation is already
  dimension-general; a future test extending the recovery cell to `s = 2`
  would close this gap cheaply, reusing
  `test-phylo-dep-slope-s2-gaussian.R`'s fixture pattern.
- **This is a `src/` change to the `sdreport` payload.** Per CLAUDE.md's
  merge rules this needs explicit maintainer sign-off before merge; the PR
  is opened as **DRAFT** for exactly this reason.
