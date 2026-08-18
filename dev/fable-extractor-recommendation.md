# Random-slope variance CI extractor — recommendation (Fable planning lens)

Date: 2026-08-18. Lane: `/private/tmp/gllvmtmb-randslope`. All file:line citations
are against `origin/main` (the Dropbox working checkout is a stale branch).

## 1. Verdict: BUILD — but only the diagonal route, as slice 1. Defer the Cholesky and loadings routes.

**Build slice 1 now.** The `theta_diag_B_slope` route asks for nothing new
inferentially: the parameters are TMB fixed effects, `fit$sd_report` already
carries their SEs, and the transform is a *monotone* map sd = exp(theta), so the
interval `exp(theta ± z·se)` is a transformed Wald interval — exact under the
transform, no Jacobian, no hand-indexing, nothing to get wrong beyond reading the
right names out of `sdreport()`. This is presentation of uncertainty the package
has already computed and currently throws away. It sits squarely inside Bar 2
(point recovery with honestly-labelled uncertainty) and D-112's recovery-only
frame; it claims nothing Bar 3 owns. The demonstrated cell (theta = −1.993085,
se = 0.475181 → CI [0.0537, 0.3459] vs true 0.2) is exactly this arithmetic.

The package's own precedent settles the "is an uncalibrated Wald interval
allowed to exist" question: `loading_ci()` is exported, `confint_inspect()` is
exported (`R/confint-inspect.R:128`), `.communality_wald_ci()` uses the same
delta-on-report pattern (`R/communality-ci.R:12-18`), and
`extract_correlations()` ships per-row `interval_status` claim-boundary markers
(`R/extract-correlations.R:341`). The house has a vocabulary for "here is a
Wald interval, it is not a coverage claim." We should speak it, not invent one.

**Defer the `theta_dep_chol` route (phylo_indep `1 + x | species`) and the
`theta_rr_B_slope` loadings route to slice 2.** Three reasons, in order of
weight:

1. **The standing hazard is real and ours.** Our own first pass indexed
   `theta_dep_chol` wrong (entries 2/5/8 vs 2/4/6, exponentiated a raw
   off-diagonal) *and attached a plausible story to the wrong numbers*. The
   packing (diagonals first, then strictly-lower column-major —
   `src/gllvmTMB.cpp:1909-1935`; mirrored in
   `R/lambda-constraint.R:57-79` `dep_chol_crossblock_pins()`) is exactly the
   kind of convention a hand-written R-side Jacobian silently violates. A route
   whose failure mode is "confidently wrong, with a story" needs its own slice
   with its own adversarial gate, not a rider on the easy slice.
2. **The right implementation is different.** For the marginal slope SD
   `sqrt(L21² + L22²)`, hand-rolled `numDeriv::grad()` against the R-side
   packing is the fragile shape. The robust shape is to `ADREPORT()` the
   marginal augmented-block SDs in the C++ template so `sdreport()` performs
   the delta method against the *authoritative* packing, and the R extractor
   just reads it. That touches `src/`, changes the sdreport payload, and
   deserves its own review — a second slice by construction.
3. **Slice 1 is independently useful and independently testable.** Ordinary
   `latent(0 + trait + (0+trait):x | unit)` slope SDs are the common case; the
   demonstrated 0.68–1.21 recovery band is on this route.

## 2. Shape

**New export, not an extension.** `confint_inspect()` is a diagnostic
inspector, `bootstrap_Sigma()` is a simulate-refit engine (wrong cost profile
for a free Wald read-off), and the profile machinery (`R/profile-targets.R`,
which has no B_slope target; `R/profile-derived.R:1309-1321` is a
Gaussian-gated *correlation* canary) would mean building a new profile target —
more machinery than the estimand needs for slice 1. The natural sibling is
`loading_ci()`.

**Name and signature:**

```r
slope_sd_ci(fit, level = 0.95, scale = c("sd", "variance"))
```

Slice-1 scope: fits with `use$diag_B_slope` and NOT `use$rr_B_slope` and no
`theta_dep_chol` slope block. All other slope-bearing structures fail loudly
with an error naming the deferral (see guard G2).

**Returns** a data.frame of class `gllvmTMB_slope_ci`, one row per slope SD
(trait × slope term), with columns:

- `trait`, `term`
- `estimate`, `lower`, `upper` (on the requested `scale`)
- `theta`, `se_theta` (the raw log-SD and its sdreport SE — auditability)
- `method = "wald_log_scale"`
- `interval_status` — house claim-boundary marker per
  `R/extract-correlations.R:341`; value `"wald_uncalibrated"` for usable rows,
  `"unavailable"` for suppressed rows
- `status` — `"ok"`, `"no_pd_hessian"`, `"boundary"`, `"se_nonfinite"`

plus attributes `calibrated = FALSE` (hard-coded, mirroring
`R/va-intervals.R:63` / `:167`, never an argument) and a print method that
prints the fence line before the table.

## 3. Fencing — mechanism, not documentation

Four mechanisms, all with in-repo precedent:

1. **Per-row `interval_status` column** (`R/extract-correlations.R:341`
   pattern). Anything downstream that consumes the table carries the marker
   with it; a campaign script can and should assert on it.
2. **Hard-coded `calibrated = FALSE`** in the returned object, exactly as
   `R/va-intervals.R` does (`calibrated` is "Always FALSE", not a knob). There
   is no argument that turns it TRUE; only a future coverage certificate
   flipping the code can.
3. **Print method leads with the fence**: "Wald intervals on the log-SD scale;
   recovery-only (D-112). Coverage is NOT certified for any family
   (CI-08/CI-10)." — same posture as the lifecycle banner. The number never
   appears without the sentence.
4. **Roxygen scope-boundary statement + register row before export**
   (AGENTS.md rule). The docs say what the interval is (a transformed Wald from
   `sdreport()`), what it is not (a calibrated coverage statement), and cite
   the register row.

What we do NOT do: no `conf`-style language implying nominal coverage in the
column names beyond `lower`/`upper` (house-consistent), no NEWS "confidence
intervals for random slopes!" headline, no vignette advertisement until the
register row exists.

## 4. Failure modes and guards

**The mistake-mode that kills this feature:** a user fits a small-n model, the
slope SD collapses to the boundary (theta = −13.5, se = 61883 or NaN, non-PD
Hessian — all observed in our measurement), and the extractor returns a numeric
interval like [0, 3e+21] or, worse, a plausible-looking one — which then
appears in a paper. That converts "we surfaced existing uncertainty" into "we
manufactured garbage with the package's name on it."

**Guard G1 (the one that matters): estimates always, intervals only from a
clean read.** Row-wise, the extractor returns the point estimate but sets
`lower`/`upper` to `NA` with an explanatory `status` and a one-time
`cli_warn()` whenever any of:

- `fit$sd_report` missing / not an `sdreport` → abort (house pattern,
  `R/communality-ci.R` does exactly this);
- `pdHess` is FALSE → all interval columns NA, `status = "no_pd_hessian"`.
  This follows the settled house line: `R/bootstrap-sigma.R:38` treats
  `pdHess = FALSE` as "an inference warning, not automatic proof the point
  estimates are unusable", while `R/cv-internal.R:354-358` treats non-PD /
  non-finite SEs as disqualifying *for SEs*. Point yes, interval no. Refusing
  the whole call would be wrong (the point estimate is still Bar-2-supported);
  returning numbers would be the mistake-mode. NA-with-status is the honest
  middle and it is what the house already does elsewhere (`extract_correlations`
  NA + `interval_status = "none"`).
- `se_theta` non-finite → `status = "se_nonfinite"`, interval NA;
- boundary collapse: `theta` below a threshold (proposal: sd below 1e-4 of the
  response scale, or simply `se_theta > 10` — an SE of 10 on the log scale
  means the interval spans e^40, information-free) → `status = "boundary"`,
  interval NA. The observed garbage (theta −13.5, se 61883) trips both tests;
  neither is a tuned constant doing real inferential work.

**Guard G2 (misrepresentation): refuse structures the formula does not cover.**
If `use$rr_B_slope` is TRUE, the marginal slope variance is
(Lambda Lambda')_tt + psi_t, and reporting `exp(theta_diag)` alone would be a
*silently wrong estimand* — the same class of error as the theta_dep_chol
indexing slip. Slice 1 aborts with an error naming the reason and the deferred
slice. Same for any `theta_dep_chol`-bearing slope structure.

**Guard G3 (slice 2 hazard-killer): no hand-indexed Jacobians.** When slice 2
lands, it must go via `ADREPORT()` in the template so the delta method runs
against the C++ packing itself, with a test that cross-checks the ADREPORTed
marginal SD against an independently constructed `L L'` from
`fit$report` on a fixture — the test shape that would have caught the 2/5/8
error on day one.

## 5. Register rows (docs/design/35-validation-debt-register.md)

Using the register's status vocabulary (lines 47-52):

- **New row (CI section, next free ID, e.g. CI-12):** "`slope_sd_ci()` — Wald
  log-scale intervals on augmented diagonal slope SDs (`theta_diag_B_slope`),
  ordinary `latent()` route only." Status **`partial`**: test evidence = the
  n_ind=50/n_rep=6 recovery cell (all 6 entries in 0.68–1.21) plus unit tests
  for the G1/G2 guards (including a forced small-n non-PD fixture asserting NA
  intervals — the guard needs a failing case, not just happy-path). Interval
  status column: "Wald, uncalibrated; recovery-only per D-112; gated by
  CI-08/CI-10; `interval_status = "wald_uncalibrated"` on every row."
- **Second row (same section):** "Marginal slope-SD intervals for
  `theta_dep_chol` (phylo_indep `1 + x | species`) and `theta_rr_B_slope`
  loadings routes." Status **`blocked`** — deliberately refused by
  `slope_sd_ci()` in slice 1; unblocking requires the ADREPORT slice (G3) and
  its cross-check test. Recording the refusal as a row is what keeps a future
  session from "helpfully" widening slice 1 with a hand-indexed Jacobian.

## Summary

| Question | Answer |
|---|---|
| Build? | Yes — slice 1 (diagonal route) now; Cholesky/loadings deferred to an ADREPORT slice |
| Shape | New export `slope_sd_ci(fit, level = 0.95, scale = c("sd","variance"))`, sibling of `loading_ci()` |
| Fence | Per-row `interval_status = "wald_uncalibrated"` + hard-coded `calibrated = FALSE` + fence-first print + register row |
| Kill-switch guard | Point estimates always; interval columns NA (with `status`) on non-PD Hessian, non-finite SE, or boundary collapse — never a numeric interval from a fit that cannot support one |
| Register | New CI row `partial` for the diagonal route; companion row `blocked` for the deferred routes |
