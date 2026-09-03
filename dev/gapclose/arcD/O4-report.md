# O4 report: `ordinal_logit()` cumulative-logit response family

Arc O4 of the approved gap-closure programme (issue #1241; name
`ordinal_logit()` maintainer-approved, vault D-210). Branch
`claude/overnight-ordinal-logit`, off `origin/main` @ `5855e2ad9`
("Merge PR #1240: zero-inflated families zi_poisson(), zi_nbinom2(),
zi_binomial() (ARC D1; maintainer-approved D-207)").

Roles: Gauss (TMB likelihood), Noether (symbolic<->code alignment), Boole
(constructor/API).

## Summary

`ordinal_logit()` is family_id **20** -- a link swap on the already-shipped
`ordinal_probit()` (family_id 14) cumulative-threshold apparatus. The
per-trait cutpoint metadata (`n_ordinal_cuts_per_trait`,
`ordinal_offset_per_trait`), the flat `ordinal_log_increments` parameter
vector, and the cutpoint reconstruction/reporting are ALL reused verbatim
across both families. The only new C++ code is a `fid == 20` branch that
computes cell probabilities with the standard logistic CDF (`plogis`)
instead of `pnorm`, using two helper functions (`gll_log_inv_logit`,
`gll_log_inv_logit_diff`) that already existed in `src/gllvmTMB.cpp` --
built earlier for the UNRELATED `cumulative_logit()` missing-predictor
family and reused here for a different, response-side family.

All work is on `claude/overnight-ordinal-logit`; NOT pushed, NO PR opened,
per the task brief.

## Files touched / line ranges

### Symbolic alignment (built first, per `symbolic-alignment` discipline)

- `dev/gapclose/arcD/alignment-ordinal-logit.md` (new) -- the full symbol
  table, log-likelihood derivation (bottom/top/middle cases), the numerical
  guard explanation (why no separate ~8.3-style tail threshold is needed
  for logit, and why the adjacent-cutpoint collision guard still applies),
  identifiability notes, and explicit scope boundary.

### C++ (`src/gllvmTMB.cpp`)

- Family-id comment block: added `20 = ordinal_logit` entry (~line
  725-737, after the existing `16 = multinomial` entry).
- New `fid == 20` likelihood branch (~line 3299-3355, immediately after
  the existing `fid == 14` block and before `fid == 15`): reconstructs
  cutpoints identically to fid 14, then computes the three cell-probability
  cases (top/bottom/middle category) with `gll_log_inv_logit` /
  `gll_log_inv_logit_diff` in place of `gll_log_pnorm` /
  `gll_log_pnorm_diff`, with the same `log(1e-300)` residual floor.
- No new PARAMETER or DATA vectors -- `ordinal_log_increments`,
  `n_ordinal_cuts_per_trait`, `ordinal_offset_per_trait` are shared,
  unmodified.
- The `ordinal_cutpoints` REPORT/ADREPORT block (end of file) needed NO
  change -- it already loops over `n_traits` using the family-agnostic
  cutpoint-count metadata.
- Compiled clean: `Rscript -e 'pkgbuild::compile_dll(quiet = FALSE)'` --
  4 pre-existing, unrelated warnings (Eigen `-Wunused-but-set-variable`,
  one `refine_maxvol_double` unused-function warning), 0 new warnings, 0
  errors.

### R (constructor, admission, plumbing)

- `R/families.R`: new `ordinal_logit()` constructor + full roxygen,
  including the explicit `cumulative_logit()` naming-trap cross-reference
  (~75 new lines, after `ordinal_probit()`).
- `R/enum.R`: `ordinal_logit = 20L` added to `.valid_family`.
- `R/fit-multi.R` (the bulk of the plumbing, ~136 line-diff):
  - `family_to_id()` switch: `ordinal_logit = 20L`, link check (refuses
    non-logit, names `ordinal_probit()`), updated "Unsupported family"
    message.
  - `auto_unique_off_family` (Psi auto-drop gate): `c(12L, 13L, 14L, 20L)`.
  - The ordinal cutpoint-metadata block (`any_ordinal_probit`,
    `ordinal_rows`, the per-trait validation loop): generalised to
    `family_id_vec %in% c(14L, 20L)`, with per-trait family detection
    (`fam_t`/`fam_label_t`) so error/inform messages name the RIGHT family,
    a mixed-ordinal-family-within-one-trait refusal, and
    `MASS::polr(method = "logistic")` for logit traits (vs. `"probit"`).
  - `ordinal_only` (b_fix OLS-init branch): `c(14L, 20L)`.
  - W-tier OLRE skip (`ordinal_only_per_trait`): `c(14L, 20L)`.
  - `R/lv-predictor.R`: the LV-predictor Psi identifiability gate mirrors
    `auto_unique_off_family`, updated the same way.
- `R/extract-sigma.R`: `fid == 20L` branch reports `sigma_d^2 = pi^2/3`
  exactly; `"20" = "ordinal_logit"` added to the fid-label lookup.
- `R/extract-cutpoints.R`: gate broadened to `fids %in% c(14L, 20L)`; doc
  updated ("ordinal cutpoints" instead of "ordinal-probit cutpoints").
- `R/predictive-diagnostics.R`: `fid == 20L` branch in the randomized-
  quantile-residual CDF dispatch (mirrors fid 14 with `plogis`); fid-label
  lookup extended.
- `R/family-cdf-args.R`: `fid == 20L` branch (cutpoint args + `plogis`
  note) mirroring fid 14's block.
- `R/methods-gllvmTMB.R` (the largest single-file diff, ~124 lines):
  `.per_trait_link()` default-link map; `.apply_linkinv_per_row()` /
  `.dlinkinv_per_row()` fid==20 branches (`plogis(e)` and its derivative
  `p*(1-p)`); print-cutpoints gate + label; `tidy(effects = "cutpoint")`
  gate; `simulate()`'s `supported` fid list + error message + the fid==20
  draw branch (`stats::rlogis`); `predict_missing()`'s ordinal-response gate
  and `.predict_missing_ordinal_response()` (now dispatches `plogis` vs
  `pnorm` per row from `family_id_vec`); roxygen updates on `tidy()`,
  `predict_missing()`, `gllvmTMB()`'s `family = ` doc.
- `R/check-auto-residual.R`: the ordinal single-family-trait detector
  broadened to `c(14L, 20L)`; class name (`gllvmTMB_auto_residual_
  ordinal_probit_overcount`) kept UNCHANGED for backward compatibility
  (verified: the one test matching it matches on class, not message text);
  message text generalised; `.family_name_from_id` gained `"20" =
  "ordinal_logit"`.
- `R/extract-correlations.R`: `.cross_ordinal_partner_traits()` broadened;
  the cross-family-nominal-summary abort message generalised (class
  unchanged, verified against the one test matching it).
- `R/extract-omega.R`: both `link_residual == "none"` advisory checks
  (`extract_phylo_signal`) broadened to `c(14L, 16L, 20L)` with updated text.
- `R/missing-predictor.R`: `cumulative_logit()`'s roxygen updated to name
  `ordinal_logit()` explicitly in the naming-trap warning (both directions).
- `R/gllvmTMB.R`: three doc cross-references (`family = ` arg, `@seealso`)
  updated to mention `ordinal_logit()` alongside `ordinal_probit()`.

### Deliberately NOT touched (with reasons, cross-referenced in the
### alignment doc's Scope Boundary section)

- `R/va-routing.R`, `R/va-r3-proto.R` -- VA is a separate opt-in route;
  `ordinal_logit` is not added to
  `.gllvmTMB_integration_fence_limits()$families`
  (`R/integration-fence.R`), so any `integration = "va"` attempt aborts
  via the existing allowlist mechanism (default-refuse, not a new fence).
- `R/mspl-registry.R` -- MSPL is opt-in via `estimator = "mspl"`; absence
  from the registry means the existing "not admitted" refusal fires,
  matching how zi_* families and other recent additions behave.
- `R/aghq-control.R` -- already matched the literal string
  `"ordinal_logit"` in its `high_curvature` family-label list (added
  pre-emptively in an earlier arc); no code change needed. AGHQ itself is
  a separate opt-in route this arc does not touch.
- `.augmented_slope_family_contract()` (`R/fit-multi.R`) -- the augmented
  intercept+slope random-regression path is a separate capability gate
  requiring its own C1-style evidence; fid 20 is not added.
- `.gllvmTMB_ordinal_degeneracy_row()` (`R/diagnose.R`) -- the O1/O2
  loading-degeneracy screen stays scoped to fid 14 only. Its own roxygen
  states a probit-specific scale-free argument for O2 ("the probit-
  liability residual variance is EXACTLY 1... so a loading IS the trait's
  latent SD in liability units") that is FALSE as written for logit
  (sigma_d^2 = pi^2/3 != 1), and its thresholds come from a dedicated
  315-fit probit-only calibration campaign. Both thresholds already
  default to `Inf` (disarmed), so this exclusion changes no shipped
  behaviour -- it is a validation-debt item for a future arc.

## Commands and exact output

### 1. Compile

```
$ Rscript -e 'pkgbuild::compile_dll(quiet = FALSE)'
...
4 warnings generated.
[dynamiclib link succeeds]
* DONE (gllvmTMB)
```
All 4 warnings are pre-existing (Eigen internals, one unused-function
warning in `lane_b_jeffreys_maxvol_atomic_v8.h`) -- unrelated to this
change; 0 errors, 0 new warnings.

### 2. `devtools::document()`

```
$ Rscript -e 'devtools::document(quiet = TRUE)'
```
First pass: expected "could not resolve link to topic ordinal_logit"
warnings (the topic did not exist yet in that same pass). Second pass:
clean, no `ordinal_logit`-related warnings, no errors. `NAMESPACE` gained
`export(ordinal_logit)`.

### 3. Load and smoke-check the constructor

```r
> devtools::load_all(quiet = TRUE)
> print(ordinal_logit())
Family: ordinal_logit
Link function: logit
```

### 4. Density identity (task requirement: < 1e-8)

Fixed-effects-only fit (`value ~ 0 + trait`, no `latent()`/`unique()`
term, so `tmb_obj$fn()` is the EXACT NLL -- no Laplace approximation), 2
traits (K = 4 and K = 3), n = 150, seed 2025:

```
density-identity |nll_tmb - (-sum(ll))| = 5.684e-14
```

**Result: 5.684e-14, well under the 1e-8 requirement**, where `ll` is an
independent R computation using `stats::plogis()` differences on the
reconstructed cutpoints, evaluated at the exact same parameter vector TMB
used. Encoded as `test-ordinal-logit.R`'s first `test_that()` block
(`expect_equal(..., tolerance = 1e-8)`).

### 5. Finite-difference gradient (task requirement: max relative
### discrepancy < 1e-4)

Same fixed-effects-only architecture, evaluated at the GENUINE
pre-optimisation starting parameter vector (`fit$tmb_obj$par`, confirmed
never reassigned anywhere in `R/fit-multi.R` after `nlminb()` -- verified
empirically: `fit$tmb_obj$par` differs substantially from `fit$opt$par`
on a real fit, e.g. `b_fix` starting at (0.031, -0.011) vs. optimised
(0.319, 1.150) for a probit control fit):

```
FD gradient max relative discrepancy = 2.786e-08
```

**Result: 2.786e-08, four orders of magnitude under the 1e-4
requirement.**

### 6. Known-DGP recovery (task requirement: 4 traits, K = 4, rank-1
### latent, n = 300, single seed, predeclared bars, then 2 further seeds)

DGP: `value ~ 0 + trait + latent(0 + trait | unit, d = 1)`,
`family = ordinal_logit()`, 4 traits, K = 4 categories (cutpoints
tau = 0, 0.7, 1.4), n_unit = 300, 2 replicate draws per (unit, trait)
cell, shared rank-1 latent factor `f ~ N(0,1)`, loadings
`lambda = c(1.6, 1.3, -1.2, 1.1)` (scaled up relative to the probit
fixture in `test-matrix-ordinal-unit.R` because the logistic residual
variance, pi^2/3 ~ 3.29, is much larger than probit's fixed 1, so a given
loading carries less signal-to-noise under logit).

**Predeclared bars** (set from an exploratory pre-run at seed 20260903,
BEFORE the 3-seed confirmation run below): median relative loading error
< 0.25, max relative loading error < 0.40, max absolute cutpoint error <
0.30.

Exploratory pre-run (informed the bars):

```
seed=20260903 time=5.5s  convergence=0  obj=2721.593
  Lhat: 1.401 1.412 -1.052 0.911   true: 1.6 1.3 -1.2 1.1
  median rel_err loadings: 0.124   max: 0.1719
  tau_2/tau_3 per trait vs true (0.7, 1.4): 0.635/1.263, 0.684/1.404, 0.619/1.255, 0.649/1.399
  sigma_d^2 (pi^2/3 = 3.289868): 3.289868 (all 4 traits, exact)

seed=2         time=11.9s convergence=0  obj=2750.747
  Lhat: 1.488 1.336 -1.202 1.180   true: 1.6 1.3 -1.2 1.1
  median rel_err loadings: 0.049   max: 0.0725
  tau_2/tau_3 per trait: 0.708/1.444, 0.704/1.373, 0.757/1.366, 0.799/1.535
  sigma_d^2: 3.289868 (exact, all 4 traits)

seed=3         time=5.2s  convergence=0  obj=2761.289
  Lhat: 1.671 1.369 -1.202 0.877   true: 1.6 1.3 -1.2 1.1
  median rel_err loadings: 0.0487  max: 0.2028
  tau_2/tau_3 per trait: 0.688/1.411, 0.718/1.456, 0.675/1.383, 0.849/1.490
  sigma_d^2: 3.289868 (exact, all 4 traits)
```

Max absolute cutpoint error across all three seeds: 0.145 (seed
20260903), 0.135 (seed 2), 0.149 (seed 3) -- all well under the 0.30 bar.

**Formal test run** (`test-ordinal-logit.R`'s recovery `test_that()`
block, same 3 seeds, `devtools::test(filter = "ordinal-logit")`):

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 45 ]
```

All predeclared bars hold on all 3 checked seeds; every seed converges
(`opt$convergence == 0`) and reports the exact link-residual variance
`pi^2/3` for all 4 traits.

### 7. Full new test file

```
$ Rscript -e 'devtools::test(filter = "ordinal-logit", reporter = testthat::CheckReporter$new())'
i tau_se is `NA`: this fit has no sd_report.
> Compute standard errors without refitting: `fit <- standard_errors(fit)`
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 45 ]
```

The one `cli_inform()` line is expected (the `se = FALSE` fits in the
density-identity / FD-gradient tests have no `sd_report`, so
`extract_cutpoints()` correctly reports `tau_se = NA` and informs why --
not a test failure).

Six `test_that()` blocks, all pass:
1. Density identity to 1e-8.
2. FD gradient at starting values, max relative discrepancy < 1e-4.
3. Recovery on 3 seeds against predeclared bars.
4. Probit-link refusal (names `ordinal_probit()`).
5. `cumulative_logit()` / `ordinal_logit()` non-collision (distinct
   classes; `cumulative_logit()` refused as a `gllvmTMB()` response
   family).
6. Mixed `ordinal_logit` + `ordinal_probit` fit: per-trait cutpoint
   offsets stay non-overlapping (offset 0 for the 2-free-cutpoint logit
   trait, offset 2 for the 1-free-cutpoint probit trait), each row's own
   family id (20 vs. 14) is dispatched correctly, and each family's exact
   link-residual variance (`pi^2/3` vs. `1`) is reported independently.

### 8. Regression check: `ordinal_probit()` unaffected

```
$ Rscript -e 'devtools::test(filter = "ordinal-probit", reporter = testthat::CheckReporter$new())'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 39 ]
```

### 9. Regression check: `test-enum-runtime-ids.R` (the lockstep guard)

First run caught a real omission -- the test's own hardcoded
`runtime_family` reference vector needed `ordinal_logit = 20L` added
(exactly the guard's job):

```
── Failure ('test-enum-runtime-ids.R:29:3') ──
Expected `family_enum` to equal `runtime_family`.
[21] "ordinal_logit" -
`actual[18:21]`: 17 18 19 20
`expected[18:20]`: 17 18 19
[ FAIL 1 | WARN 0 | SKIP 48 | PASS 422 ]
```

Fixed (`tests/testthat/test-enum-runtime-ids.R`); re-run clean:

```
$ Rscript -e 'devtools::test(filter = "enum-runtime-ids|zi-families|zi-recovery|check-auto-residual|cross-family|omega|families$", reporter = testthat::CheckReporter$new())'
[ FAIL 0 | WARN 0 | SKIP 11 | PASS 352 ]
```

### 10. Broader regression sweep (methods/predict/simulate/diagnose/sigma/
### cutpoints)

```
$ Rscript -e 'devtools::test(filter = "diagnose|methods-gllvmtmb|predictive-diagnostics|extract-sigma|extract-cutpoints|simulate|residuals|fitted|predict", reporter = testthat::CheckReporter$new())'
[ FAIL 0 | WARN 2 | SKIP 105 | PASS 707 ]
```
Both warnings are pre-existing deprecation notices
(`extract_Sigma_B()`/`extract_Sigma_W()`) in `test-extract-sigma.R`,
unrelated to this change.

### 11. Broader regression sweep (family parsing / lv-predictor /
### mixed-family)

```
$ Rscript -e 'devtools::test(filter = "family-parse|family-admission|lv-predictor|unsupported-family|multinomial$|mixed-family", reporter = testthat::CheckReporter$new())'
[ FAIL 0 | WARN 1 | SKIP 37 | PASS 306 ]
```
The one warning is a pre-existing multinomial-contrast-degeneracy note in
`test-link-residual-multinomial.R`, unrelated to this change.

**Total across all regression sweeps run for this arc: FAIL 0.**

### 12. Docs regeneration

```
$ Rscript -e 'devtools::document(quiet = TRUE)'
(clean, no warnings on the second pass)
```
`NAMESPACE`, `man/ordinal_logit.Rd`, `man/extract_cutpoints.Rd`,
`man/gllvmTMB.Rd`, `man/tidy.gllvmTMB_multi.Rd`,
`man/predict_missing.Rd`, `man/cumulative_logit.Rd` all regenerated.

### 13. Capability-ledger regeneration

```
$ Rscript dev/gapclose/build-capability-status.R
wrote .../docs/design/capability-status.md; 78 rows; 248 register rows mapped; 32 unmapped-by-design; 0 unmapped (should be 0)

$ Rscript dev/gapclose/build-capability-status.R --check
capability-status.md up to date; 78 rows; 0 unmapped register rows
```

## Not finished / left out of scope (stated plainly)

- No calibrated interval work on the cutpoints beyond what
  `ordinal_probit()` already ships (`extract_cutpoints()`'s existing Wald
  SEs via `sd_report`) -- this arc adds no new interval machinery.
- VA / AGHQ / MSPL remain unadmitted for `ordinal_logit()`, by omission
  from their respective allowlists (see "Deliberately NOT touched"
  above) -- this is the stated scope boundary, not an oversight.
- `gllvmTMB_diagnose()`'s ordinal loading-degeneracy screen
  (`ordinal_loading_runaway_thresh`/`ordinal_loading_absolute_thresh`)
  stays probit-only; extending it to logit needs its own calibration
  campaign (a candidate follow-on arc, not started here).
- The augmented (intercept + slope) random-regression path does not admit
  `ordinal_logit()`.
- Julia (`GLLVM.jl`) parity/bridge work: NOT attempted. `ordinal_logit()`
  is NOT wired into `R/julia-bridge.R` (explicitly out of scope per the
  task brief -- "another lane owns them").
- `R/mspl-registry.R`, `R/va-routing.R`, `R/va-r3-proto.R`: not edited (see
  "Deliberately NOT touched" for the reasoning in each case).
- The `.augmented_slope_family_contract()` scope-text prose
  (`R/fit-multi.R`, `.augmented_slope_family_scope_text()`) and a handful
  of other minor doc mentions of `ordinal_probit` that already omit
  `zi_poisson`/`zi_nbinom2`/`zi_binomial`/`multinomial` too (a pre-existing
  gap, not introduced or fixed here) were left as-is rather than partially
  patched.

## Report / handoff pointers

- Symbolic alignment: `dev/gapclose/arcD/alignment-ordinal-logit.md`.
- This report: `dev/gapclose/arcD/O4-report.md`.
- Tests: `tests/testthat/test-ordinal-logit.R` (new),
  `tests/testthat/test-enum-runtime-ids.R` (one-line fix).
- Design docs: `docs/design/02-family-registry.md` (Link Residual
  Contract table row + Ordinal families table row + full 14-slot
  breakdown), `docs/design/03-likelihoods.md` (new "Ordinal logit"
  subsection), `docs/design/35-validation-debt-register.md` (FAM-24 row),
  `docs/design/capability-status.md` (regenerated; new `ordinal_logit` /
  `Ordinal` row, updated `ordinal_probit` collision note).
- `NEWS.md`: new bullet with explicit IN/NOT-IN scope statement.
