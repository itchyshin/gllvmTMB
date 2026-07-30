# VGH Phase 3 — the screen premise is wrong, and the real detector is free

Date: 2026-07-29. Lane: `claude/vgh-phase3-screen-20260729`. Status: **premise
disproved; a better detector identified and independently verified.**

The plan called Phase 3 *"possibly the highest-value output"* of the arc, on the
hypothesis that VA's KL-to-prior term is an implicit regulariser and therefore makes
VGH label its own bad fits. **That hypothesis is false as a basis for a screen.** But
the phase still produced its most valuable result, because the failure it targets is
real, reproducible, and detectable for free.

## 1. The recorded failure is real and reproduces

Bernoulli-logit, `q = 2`, following the documented recipe
(`dev/bound-vs-estimates-recovery.R`): **8 of 20 fits are silently degenerate** —
`rel_frob` on the rotation-invariant `Sigma_B` above 10 while reporting
`convergence == 0` **and** `pdHess == TRUE`. Worst case `rel_frob = 117417`. This
matches Design 108's recorded "8 of 20 (40%)" and its decreasing-with-`n` pattern
(6/10 at n=60/p=12, 3/10 at n=100/p=20).

One degenerate fit had `pdHess = FALSE`, so `pdHess` catches *some* but not most.

## 2. The VGH screen fails, on four independent grounds

The candidate statistic was `h = -(1/(Nq)) * sum_i logdet S_i`, the mean per-unit
posterior log-contraction, chosen because the KL term's `logdet` piece is the only
unbounded penalty. It does not work.

**(a) It is structurally blind to the thing that degenerates.** `h` is computed from
`fit$Svec` alone. Measured: `h` is *identical to ten significant figures* whether
`Lambda` is absent, `~N(0,1)`, or multiplied by `1e6`. The failure mode is a loading
explosion of 2–5 orders of magnitude, and the statistic cannot see loadings at all.
That is not a tuning problem; it is the wrong quantity.

**(b) Held-out performance is worse than a coin flip.** Calibration reported
sensitivity 0.75 / specificity 0.727. With the band **frozen** and fresh seeds 11–30
(39 fits): sensitivity 0.333, specificity 0.471, **AUC 0.4986, Youden J = −0.196**.
Positive predictive value 0.4375 against a base rate of 0.553 — **a flag makes you
less confident the fit is degenerate than not running the screen at all.**

**(c) The reported specificity was a design constant, not a measurement.** The band
was `healthy_mean ± 1·healthy_sd` computed on the same fits it was scored against;
`2*pnorm(-1) = 0.317` predicts the flag rate by construction, and 3/11 = 0.273 was
observed. That number would come out the same for *any* statistic, informative or not.

**(d) It is not transportable.** On benign `gaussian_anchor` data with nothing wrong
with it, the calibrated band flags **100%** of healthy fits, with `h` growing roughly
like `log(T)`.

The shipped default threshold also flagged **nothing** — sensitivity 0 on all 59
fits — so the committed function was inert on the very failure it was written for.
`R/vgh-screen.R` and its test have been removed rather than shipped.

## 3. What actually detects it, for free

`||Sigma_hat_B||_F` read off the **Laplace fit alone** — no VGH fit, no simulation
truth, no tuning:

| | healthy max | silent-degenerate min | gap |
|---|---|---|---|
| `\|\|Sigma_B\|\|_F` | 29.71 | 482.33 | **16.2×** |
| VGH's `h` | 1.229 | 0.859 | **overlapping** |

Independently re-verified in this lane from `p3-screen-merged.csv`. The adversarial
reviewer measured **AUC 1.0000** for `||Sigma_B||_F` on calibration, hold-out, and
pooled (n = 59); any cut in `[30, 417]` separates perfectly. Three other quantities
already in the same table also beat `h` (`vgh_h_sd` 0.875, `vgh_trG` 0.852, even the
Laplace `loglik` 0.841). `h` was the **worst** candidate available.

## 4. Why nothing catches it today — and the real reason, which I first got wrong

**Correction to an earlier version of this document.** I wrote that the gap was one
of *direction*: that `diagnose.R:15-178` flags only collapse-toward-zero while this
failure is a blow-up. That is true of the boundary flags, but it is **not** the
important finding, and it understated how close the package already is.

`check_gllvmTMB()` — **exported** — already has a
`binomial_prevalence_loading` row (`.gllvmTMB_binomial_prevalence_loading_row()`,
`R/diagnose.R:381-515`) that computes exactly the right quantity. Run on a
catastrophically degenerate fit (n=60, p=12, seed 3, `rel_frob = 156645`), it
reports:

```
check  : binomial_prevalence_loading
status : PASS
value  : sp12 prevalence=0.617; max_loading=949; relative_loading=6980; saturated_fit=1
```

**It has `relative_loading = 6980` against its own `loading_relative_thresh = 8` — 872×
over the line — and reports PASS.** The whole check returns only two WARNs on this
fit: a gradient of 0.011, and the generic `rotation_ambiguous` note. Nothing tells the
user their `Sigma_B` is off by five orders of magnitude.

The cause is a single conjunction, `R/diagnose.R:464`:

```r
tab$flag <- tab$extreme_prevalence & (tab$dominant_loading | tab$saturated_fit)
```

`extreme_prevalence` (prevalence ≥ 0.9 or ≤ 0.1) is a **required** conjunct. Here
prevalence is 0.617, so no matter how far the loading runs away, the row cannot fire.
But the recorded cause of this failure is **quasi-complete separation**, which
produces a runaway loading at *moderate* marginal prevalence — separation is a
property of the fitted linear predictor, not of the marginal rate.

So the accurate statement is: the package **already measures** the degeneracy and
then gates the flag behind a condition the failure does not satisfy.

For completeness: `check_identifiability()` (unexported) targets a third, unrelated
failure — a spurious extra factor under rank over-specification — and
`docs/design/61-capability-status.md:193` already records it as accepting
"optimiser convergence or a positive-definite Hessian rather than requiring a healthy
conjunction", the same defect class in a different function.

**Vocabulary.** This failure has an established name: a **Heywood case** /
improper solution, the classical (1931) factor-analysis term for a boundary or
out-of-bounds ML solution. Any fix should use that vocabulary rather than invent
new terms. [UNVERIFIED, web-sourced: one paper generalises the definition to
exponential-family latent-variable models, which would license applying it here.]

## 5. Recommendation

Do not build a VGH-based screen, and do not add a new public route. **Fix the gate on
the check that already exists.** `R/diagnose.R:464` requires extreme prevalence as a
conjunct; a runaway `relative_loading` (6980 against a threshold of 8) should be
sufficient on its own, since quasi-complete separation produces one at moderate
prevalence. That is a small change to an already-exported diagnostic.

Superseded earlier wording: extend the boundary flags with
the direction they currently miss — implausibly **large** implied latent variance —
which needs no second fit and no new public route.

**One caution, learnt from (d) above:** an absolute cut such as
`||Sigma_B||_F > 50` is calibrated to *these* cells and would not transport. A
binomial response has bounded variance, so an implied `Sigma_B` of 482 is absurd;
a gaussian response with genuinely large variance could legitimately produce a large
norm. The flag must therefore be **scale-relative** — implied latent variance against
what the observed data can support — and must be validated across families, `n`, `T`
and `q` on data with nothing wrong with it. Shipping an absolute threshold here would
repeat exactly the mistake that killed the VGH screen.

## What this phase did NOT establish

VGH remains `research_only = TRUE`. Nothing here supports VGH as an estimator, and
Phase 2 already bounded its warm-start speedup at 1.25×. The KL term *is* a
regulariser in the sense the plan meant — but the barrier is only **logarithmic** in
the degeneracy factor (`N q log c`), so the plan's framing that it "prevents"
explosion overstates it. What it guarantees is that explosion is observable on a
bounded scale — which turned out not to be enough.
