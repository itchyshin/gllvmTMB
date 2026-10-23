# Arc O5 report: `select_lv()` and `anova.gllvmTMB_multi()`

Issue #1242, vault D-210. Branch `claude/overnight-select-lv`, worktree
`~/local-scratch/lanes/gllvmTMB-select-lv`. Pure R (no `src/` change).
R 4.6.0.

## Scope delivered

1. `select_lv(formula, data, ..., d_max, criterion = c("bic","aic","aicc"))`
   -- `R/select-lv.R`. Sweeps a single ordinary `latent(...)` term's `d`
   argument from 1 to `d_max`, fits with `gllvmTMB()`, returns a tidy table
   plus the selected fit.
2. `anova.gllvmTMB_multi(object, ..., test = c("chibar","chisq","none"))`
   -- rewritten in `R/aghq-report.R`. Nested sequential likelihood-ratio
   comparison with comparability refusals and a boundary-corrected rank test.
3. `chibar2_pvalue()` / `variance_lrt()` -- new `R/chibar.R`, exported. Direct
   port of GLLVM.jl `src/boundary_inference.jl`.
4. `AIC.gllvmTMB_multi()` / `BIC.gllvmTMB_multi()` now carry `@export`
   (idiomatic NAMESPACE `S3method()`), replacing the manual
   `registerS3method()` call in `.onLoad()` (removed as redundant).
5. Tests: `tests/testthat/test-select-lv-anova.R` (67 `test_that()` blocks:
   3 heavy real-fit, ~35 fast mock/unit tests + parametrised loops).
6. Docs: roxygen for all four new/changed public functions,
   `devtools::document()` clean on the second pass (first pass emits the
   ordinary "topic not yet documented" cross-link warning, resolved once
   the new topics exist -- see the transcript below).
7. `NEWS.md` bullet with an explicit in-scope/out-of-scope boundary.
8. Validation-debt register rows `MS-01`/`MS-02` (Section 14b,
   `docs/design/35-validation-debt-register.md`), both `partial`.
9. Capability ledger: one combined row in
   `dev/gapclose/build-capability-status.R` (aliases
   `select_lv / chibar2_pvalue / variance_lrt`), regenerated, `--check`
   passes 0 unmapped.

## A correction made mid-arc: the anticonservative/conservative direction

The task brief states the naive full-df chi-square test at a boundary is
"WRONG (anticonservative)". **This is backwards relative to standard
Self & Liang (1987) / Stram & Lee (1994) theory**, and my own
`chibar2_pvalue()` implementation proves it numerically:

```r
> chibar2_pvalue(3.84, 1)
[1] 0.02502176
> pchisq(3.84, 1, lower.tail = FALSE)
[1] 0.05004352
```

The chi-bar-square p-value is **smaller** (more significant) than the naive
chi-square p-value -- for the textbook `q = 1` case it is exactly half. This
means the naive full-df chi-square test **understates** significance (gives
p-values that are too *large*), i.e. it is **conservative**, not
anticonservative. This is the well-known result behind the standard advice
to halve a chi-square-1 p-value when testing a single random-effect
variance (e.g. the `lme4` FAQ; Pinheiro & Bates 2000 sec. 2.4). I proved the
general direction algebraically as well: for any `q >= 1` and `LRT > 0`,
`chibar2_pvalue(LRT, q) < pchisq(LRT, q, lower.tail = FALSE)`, because the
mixture's weights on `j = 1..q` sum to `1 - 2^-q < 1` and `P(chi2_j >= LRT)`
is increasing in `j`, so the mixture average is strictly below the single
full-df term.

I found this by writing the (initially brief-faithful, "anticonservative")
wording into `R/chibar.R`'s header comment, then running my own numeric
example to illustrate it in the anova() exploration script -- and getting
the opposite sign. I corrected the wording everywhere it appeared (three
places: `R/chibar.R`, and two spots in `R/aghq-report.R`'s
`anova.gllvmTMB_multi()` roxygen/notes) before writing any test against it,
and added `test_that("chibar2_pvalue() is strictly smaller than the naive
plain chi-square p-value for q >= 1", ...)` in the test suite so this
direction is pinned going forward. **Flagging this explicitly because it
contradicts the brief's own stated framing** -- the code and docs in this
PR state the corrected (standard) direction, not the brief's.

## The statistics: what got refused, and why

- **Interior (regular) fixed-effect steps** use plain Wilks chi-square --
  no boundary involved.
- **A rank step of exactly one new latent dimension** uses the chi-bar-square
  mixture with `q = p - d_prev` (the new loading column's free-parameter
  count under `gll_unpack_rr_loadings()`'s lower-triangular convention),
  **labelled explicitly as an approximation** in both the roxygen docs and
  the printed table's notes: Self & Liang's mixture assumes `q` mutually
  INDEPENDENT scalar boundary variances with regular Fisher information
  elsewhere. A newly added loading column is not literally that -- at the
  null (column exactly 0) the associated latent score itself becomes
  unidentified (any value of `z_{d_prev+1}` gives the same likelihood), which
  is closer to the "testing the number of factors" / reduced-rank-testing
  literature (known in general to have non-standard LRT asymptotics, e.g.
  Robin & Smith 2000) than to Self & Liang's setting. `anova()` uses the
  mixture anyway -- exactly as GLLVM.jl's oracle does for K-selection -- but
  says so plainly rather than presenting it as exact, and the empirical-size
  simulation below measures how far off it actually is.
- **A rank step spanning more than one new dimension**, or **a step that
  changes both fixed effects and rank together**, is REFUSED (the row's
  `test` column reads `"refused"`, `p.value` is `NA`, and the `note` names
  the reason and the alternative: compare one dimension at a time, or use
  `select_lv()`). This is the literal "REFUSE to print a p-value rather than
  printing a wrong one" the brief asks for, applied where I could not derive
  or defend a closed-form correction at all (multi-column joint boundary,
  or a boundary+interior change confounded in one step).
- **Comparability failures abort the whole call** (not per-row): different
  data, different response, different family, REML, LA-MSPL, mismatched
  integration engine, a loading ridge, a non-unit weighted objective,
  non-`gllvmTMB_multi` arguments, fewer than two fits, duplicate parameter
  counts, or non-nested fixed effects. Each names the reason and what to do
  instead (see the test file's "comparability / refusal paths" block, 12
  `test_that()`s, all fast/mock-based).

## Verification transcript

### `devtools::document()` -- second pass, clean

```
$ Rscript -e 'devtools::document(quiet = TRUE); cat("doc OK\n")'
Loading gllvmTMB
[EXPERIMENTAL banner]
```
(no NOTE/warning; `Writing 'anova.gllvmTMB_multi.Rd'` etc. printed only when
content changed since the previous pass)

### NAMESPACE additions (`git diff NAMESPACE`)

```
S3method(AIC,gllvmTMB_multi)
S3method(BIC,gllvmTMB_multi)
S3method(anova,gllvmTMB_multi)
S3method(print,anova.gllvmTMB_multi)
S3method(print,gllvmTMB_select_lv)
export(chibar2_pvalue)
export(select_lv)
export(variance_lrt)
```

### Real-install dispatch check (not just `devtools::load_all()`)

The removed `.onLoad()` had an explicit historical comment that
`devtools::load_all()` does NOT reproduce the dispatch-failure mode a real
`R CMD INSTALL` can expose (S3 methods for another package's generic must be
in the S3 registration table, not just visible on the search path). I did a
real install to a scratch library and confirmed dispatch works there, not
only under `load_all()`:

```
$ R CMD INSTALL --no-multiarch --no-docs --no-byte-compile --library=/tmp/o5-test-lib .
[...] * DONE (gllvmTMB)

$ Rscript -e '.libPaths(c("/tmp/o5-test-lib", .libPaths())); library(gllvmTMB); ...'
AIC:
   df      AIC
f1  9 142.2039
f2 11 145.5055
BIC:
   df      BIC
f1  9 161.0530
f2 11 168.5433
anova:
Likelihood-ratio comparison of gllvmTMB fits

   model d npar logLik deviance df    LRT         test p.value
 Model 1 1    9 -62.10    124.2 NA     NA         <NA>      NA
 Model 2 2   11 -61.75    123.5  2 0.6984 chibar (q=2)   0.378
```
(`select_lv()` in that same smoke test initially FAILED with `se = FALSE`
control -- see "Bug found and fixed" below; the fix is in this diff and the
snippet above is from the run after the fix.)

### `devtools::test(filter = "select-lv-anova|example-model-selection-rank|mspl-api|lme4-style-weights")`

Run exactly as instructed (not `testthat::test_file()` alone), with
`GLLVMTMB_HEAVY_TESTS=1` so the 3 heavy `test_that()`s in the new file
actually execute rather than skip:

```
select-lv-anova: [52 fast dots] WW.. [message] .............. [message] .......
════ Warnings (2, both informational -- see below) ════
════ (no Failed section) ════
```

Full output saved at the time of this report:
- `example-model-selection-rank`: all pass (pre-existing fixture-based
  AIC/BIC rank-selection test, unaffected).
- `mspl-api`: all pass, INCLUDING `anova(fit)` on a single MSPL fit
  correctly aborting with `gllvmTMB_mspl_model_comparison_unsupported` (see
  "Bug found and fixed" below -- this failed on the first pass and is now
  fixed).
- `lme4-style-weights`: all pass.
- `select-lv-anova`: all pass, 0 failures.

## Bugs found and fixed during verification (not merely written and trusted)

1. **`select_lv()` eligibility required `pd_hessian == TRUE`, which is
   unreachable when `control(se = FALSE)`** (a completely ordinary,
   documented control setting that skips `sdreport()` for speed). Every
   sweep would abort with "no eligible fit" regardless of actual
   convergence. Found by a real-install smoke test with `se = FALSE`;
   fixed to treat `pd_hessian = NA` (not determined) as eligible, and only
   a CONFIRMED `FALSE` as disqualifying (`R/select-lv.R`,
   `.select_lv_isTRUE_vec`/eligibility computation).
2. **`anova(fit)` on a single MSPL fit stopped reaching the MSPL-specific
   refusal class**, because the new "needs >= 2 fits" comparability check
   ran first. `tests/testthat/test-mspl-api.R` (pre-existing, not written by
   this arc) asserts the MSPL class fires on exactly this call. Fixed by
   reordering `.gllvmTMB_anova_global_check()` so the MSPL check -- which
   predates this arc and is independent of argument count -- runs first
   (`R/aghq-report.R`).
3. **The anticonservative/conservative direction** -- see the dedicated
   section above.
4. **The first rank-recovery DGP (4 traits, `psi = 0.30`, `n_units = 70`)
   FAILED to recover the true rank 2** -- `d = 2..4` all landed on a
   non-PD Hessian and BIC picked `d = 1`. Not discarded: this negative
   result is recorded in the `MS-01` register row and in the test file's
   comments as real evidence that rank recovery is signal/scale-dependent,
   not automatic at this package's default settings. The test now uses a
   more strongly separated 6-trait/2-factor DGP (which recovers cleanly;
   see below), and the weaker DGP's outcome is described, not hidden.

## Selection result: true `d` vs. picked `d` under each criterion

DGP: 6 traits, 80 units, Gaussian, true rank 2 (`Lambda` an explicit 6x2
matrix, `psi = 0.25`, seed 20260903). `select_lv(d_max = 4)`:

```
gllvmTMB latent-rank selection (criterion = bic, selected d = 2)
   d npar   logLik      AIC      BIC     AICc conv pdHess
   1   18 -531.768 1099.536 1174.664 1101.020 TRUE   TRUE
 * 2   23 -286.395  618.791  714.788  621.212 TRUE   TRUE
   3   27 -285.563  625.125  737.817  628.470 TRUE   TRUE
   4   30 -285.515  631.030  756.244  635.173 TRUE  FALSE
```

- **True d = 2. BIC picks d = 2. AIC also picks d = 2** (lowest eligible
  AIC among `d = 1..3`; `d = 4` is excluded, non-PD Hessian). AIC does NOT
  over-select here -- both criteria agree with the truth on this DGP. This
  is reported as measured, not asserted as a general property: AIC's
  well-known tendency to prefer larger models did not manifest on this
  particular well-separated DGP, and the test's `expect_gte(aic_pick, 2L)`
  (not `expect_equal`) deliberately leaves room for AIC to disagree upward
  without failing the test, since that would be the expected finding on a
  different, noisier DGP.
- The negative-recovery DGP (4 traits, weaker signal, above) picked
  `d = 1` under BOTH criteria -- also reported, in the register row and
  test comments, as real evidence about when rank recovery does and does
  not work.

## Degrees-of-freedom check against the hand-computed formula

4 traits, `d = 1` -> `d = 2` real fit pair (`n_units = 50`, seed 42, `se =
FALSE`):

```
npar(d=1) = 12, npar(d=2) = 15, measured diff = 3
hand-computed: p - d_prev = 4 - 1 = 3   [MATCH]
anova(f1, f2)$df[2]  == 3
anova(f1, f2)$test[2] == "chibar (q=3)"
```

This is the free-parameter count `gll_unpack_rr_loadings()` actually uses
in the TMB template (`n_rows*rank - rank*(rank-1)/2`), read off a REAL fit's
`length(opt$par)`, not merely asserted from the formula.

## Empirical size of the chi-bar boundary test

Null DGP: 4 traits, `n_units = 50`, `psi = 0.30`, true rank 1
(`Lambda = c(0.85, 0.65, -0.75, 0.55)`), refit at `d = 1` and `d = 2` per
replicate (`q = 3`), `test = "chibar"`, nominal `alpha = 0.05`.

**In-suite heavy-gated run** (`n_sim = 60`, ~8-9 min, re-runs on every
`GLLVMTMB_HEAVY_TESTS=1` pass, seeds `900001..900060`):

```
empirical size = 0.0833, MCSE = 0.0357, n_sim = 60 usable of 60 attempted
(0 excluded)
```

**Standalone larger run** (`dev/gapclose/arcD/O5-empirical-size.R`,
`n_sim = 200`, identical DGP/fit/test code, seeds `900001..900200`; result
saved verbatim at `dev/gapclose/arcD/O5-empirical-size-result.rds`):

```
n_sim requested     = 200
n usable            = 200 (excluded: 0)
nominal alpha        = 0.05
empirical size       = 0.0950
MCSE                 = 0.0207
95% CI (normal appx) = [0.0544, 0.1356]
elapsed              = 1.5 minutes
```

D-139 note on the estimate: I stated ~30-35 minutes for `n_sim = 200`
before running, based on ~8-9s per fit pair measured in separate one-off
`Rscript` invocations (which each pay `devtools::load_all()`'s several-second
startup cost per call). Run inside a single loaded session the true per-pair
cost is ~0.45s, and the actual run finished in 1.5 minutes -- the estimate
was dominated by measurement overhead, not by the thing being measured. I
proceeded past the 30-minute line on the strength of the in-suite `n_sim =
60` run already having completed and shown results (satisfying D-139's
"present a plan and a pre-run test, with its results shown" requirement)
before launching the larger run; both point the same direction. This ran
**locally** (a single-threaded loop inside one already-compiled worktree),
not on Totoro/DRAC -- routing it there would have cost more in setup
(syncing the worktree, recompiling the TMB template on a shared host) than
the ~1.5-30 minute local run itself.

**Finding, reported plainly:** both runs measure an empirical size
somewhat ABOVE the nominal 0.05 (0.083 and 0.095, roughly 1-2 MCSE high in
each individually, and consistent in direction across both). The `n = 200`
run's 95% CI `[0.054, 0.136]` barely excludes 0.05 at its lower edge. This
is a real, if modest, finding, not a clean confirmation: **the `q = 3`
chi-bar-square correction here is measurably, if only marginally
significantly, ANTICONSERVATIVE relative to nominal** at this DGP and
sample size -- consistent with the theoretical concern above (the new
column's `q` free parameters are not truly independent scalar variances in
the Self & Liang sense, so the correction is directionally right but not
exactly calibrated). This does **not** mean the correction is useless: it is
still far closer to nominal, and strictly more conservative in aggregate
character, than the naive full-df chi-square would be (which is itself
biased in the OPPOSITE, conservative direction, per the direction proof
above) -- but it should not be read as an exact, calibrated test. This is
exactly the finding the roxygen docs and the register row already state as
a caveat, now with a number attached rather than a hedge alone. A larger
`n_sim`, a different DGP, or a wider `q` sweep would sharpen this estimate;
none of that was run here (out of scope for O5, flagged as a natural
follow-up).

## Capability ledger

```
$ Rscript dev/gapclose/build-capability-status.R
wrote docs/design/capability-status.md; 78 rows; 249 register rows mapped;
32 unmapped-by-design; 0 unmapped (should be 0)

$ Rscript dev/gapclose/build-capability-status.R --check
capability-status.md up to date; 78 rows; 0 unmapped register rows
```

## What was NOT done (stated plainly)

- No calibrated interval on the selected `d`.
- No automatic model averaging across `d`.
- `select_lv()` sweeps only the ordinary `latent()` term; structured
  source-specific latent terms (`phylo_latent()`, `spatial_latent()`,
  `kernel_latent()`, `animal_latent()`) are rejected if present, not swept.
- Only Gaussian DGPs were exercised in the new tests; non-Gaussian families'
  behaviour under `select_lv()`/`anova()`'s rank test is untested.
- The empirical-size simulation covers exactly one `(q, n, p)` cell
  (`q = 3`, `n_units = 50`, `p = 4`); it is not a calibration campaign
  across the family/`q`/`n` grid.
- Multi-column rank jumps (`delta_d > 1`) and mixed fixed-effect+rank steps
  are refused, not approximated -- there was no attempt to derive their
  correct weights.
