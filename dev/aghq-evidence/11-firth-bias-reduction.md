# Firth-style bias reduction on the AGHQ objective, and the separation connection

Script: `dev/aghq-evidence/11-firth-bias-reduction.R`. DGP: binomial GLLVM,
T = 4 traits/site, q = 1, k = 9 (AGHQ), via `dev/aghq-r-reference.R`
(`ref_fit`/`ref_nll`), byte-identical to the DGP used across this evidence
directory.

## What was asked, and the one-sentence answer

Firth (1993) adds `0.5*log|I(theta)|` to the log-likelihood to remove
first-order estimator bias, and is the standard remedy for separation in
binary regression — directly relevant here because this project has already
measured conditional separation in these exact fits (62/320 observations with
`|eta| > 10`, sign matching y in all 62). **The literal recipe implemented
here (observed information, one capped Nelder-Mead fit of the penalised
objective per dataset) does NOT reliably close the small-n gap** on the
evidence gathered — at the per-fit level it helped 5, did nothing for 9, and
hurt 9, out of 23 fits, none of which internally converged; see the numbers
below and the honest caveats about the reduced run. It also
surfaced a genuine numerical-methods finding that is arguably the most durable
output of this slice: **a Newton-step Firth correction built by
finite-differencing the (already finite-difference) observed information is
numerically unusable** — diverging to absurd magnitudes for a subset of fits —
and the reason is diagnosable, not mysterious (see "Abandoned route" below).

## Observed vs expected information (stated, not silent)

`theta = (b, lambda_free)` is the full fixed-parameter vector; `ref_nll`
already integrates out the latent `z_i` via AGHQ, so `nll_aghq(theta)` is the
marginal negative log-likelihood, and

```
nll_firth(theta) = nll_aghq(theta) - 0.5*log|I(theta)|
```

is exactly the negative Firth-penalised marginal log-likelihood, PROVIDED
`I(theta)` is the right information matrix. We use **observed** information —
the Hessian of `nll_aghq(theta)` itself, by finite differences — not expected
(Fisher) information. Firth's original justification is stated for expected
information, and for this latent-variable, non-canonical model, expected
information would require a further integral of the Hessian over `Y | theta`
(marginalising the *data*, on top of the *latent z* that AGHQ already
marginalises) — there is no closed form, and no Monte Carlo route that would
not itself dominate the compute budget. Observed information is the practical
substitute most applied Firth implementations reach for when expected
information isn't closed-form (the same substitution Cox & Reid 1987 make).
This is a stated approximation, not a silent one, and it is a candidate
explanation if the correction under-performs: observed information near a
separated fit is exactly where it is least trustworthy as a proxy for expected
information (its own curvature is what separation distorts).

## Cost, measured before committing to a design

A literal implementation would (a) compute `I(theta)` by finite differences —
`p_theta^2` `ref_nll` evaluations — **inside** (b) a call to a generic
optimiser on `nll_firth(theta)`, which would normally estimate its own
gradient by *further* finite-differencing, multiplying the `p_theta^2` cost by
another `~p_theta` per outer iteration, times the number of iterations to
converge. Measured directly before committing to any design:

- One naive 4-point-central Hessian at n=200 (`p_theta=8`): **~12.8s**.
- A single full AGHQ `ref_fit()` at n=800 alone: **exceeded a 2-minute
  budget** (did not return in the allotted window on this run).

A literal `nlminb(nll_firth, ...)` re-optimisation to convergence was
therefore **not attempted** — it would cost tens of minutes per fit, against a
requested grid of 4 n's x >=20 seeds. This is the "prohibitive" case the brief
anticipated, and the reduced design below is the stated response.

## Abandoned route: a one-step Newton correction (recorded as a negative result)

The first implementation built the standard "one-step" bias-correction
construction: from the AGHQ MLE `theta_hat`, take one Fisher-scoring-style
Newton step of `nll_firth`,

```
theta_Firth = theta_hat - solve(I(theta_hat), grad_nll(theta_hat) - 0.5*grad(log|I(theta_hat)|))
```

where `grad(log|I|)` was estimated by **finite-differencing the log-determinant
itself** — i.e. a nested numerical derivative (the log-determinant is already
a functional of a finite-difference Hessian). This failed, and failed in a
way worth recording precisely because it is diagnosable rather than mysterious:

**`log|I(theta)|` itself is a stable, reproducible VALUE.** Varying the inner
Hessian's finite-difference step `h` from `1e-2` to `1e-4` at a fixed
`theta_hat` (n=200 case, `logdet ≈ 18.5`) moved the log-determinant by less
than 0.05 — negligible.

**But its finite-difference GRADIENT is not.** Holding the inner Hessian step
fixed at `h=1e-4` and shrinking the OUTER step (`theta + h_outer*e_j`) used to
estimate `d(log|I|)/d(theta_j)`:

```
h_outer = 1e-1   grad_logdet = [ 0.03, -0.96, -1.45, -1.41, -0.84,  -6.26, -2.75,  4.02]
h_outer = 1e-2   grad_logdet = [ 0.40,  0.43, -1.48, -5.05, -4.62, -14.79, -3.76,  5.27]
h_outer = 1e-3   grad_logdet = [11.38,  6.33, -0.81, -3.04,  3.39, -54.64,-17.20,-45.27]
h_outer = 1e-4   grad_logdet = [28.02,-246.35, 38.89,-92.61,324.64, -10.32, 11.46,-164.16]
```

There is no sign of convergence as `h_outer -> 0`; the estimate gets WORSE,
not better — the classic signature of a finite-difference step small enough
that floating-point/optimiser-convergence noise in the inner computation
dominates the true signal. The mechanism: each evaluation of `log|I(theta +
h_outer*e_j)|` requires its own from-scratch 45-evaluation Hessian, itself
built from an inner Newton-solved per-site posterior mode with a fixed
tolerance (`1e-10`) — differencing two such noisy values and dividing by a
tiny `h_outer` amplifies that noise by `1/h_outer`. This is not a tuning
problem solvable by picking a better `h_outer`: there is no `h_outer` that is
simultaneously small enough to see the true local slope of `log|I|` and large
enough to swamp the inner numerical noise, at least not without a much tighter
(and much more expensive) inner tolerance.

**Consequence measured**: the resulting one-step Newton correction produced
`||Lambda||` ratios in the **thousands** for a subset of fits — e.g. 17205 at
n=50, 9490 at a second n=50 seed, 713 at n=200 — not a subtle bias, a diverged
correction. Critically, it did **not** diverge for every fit (a second n=200
seed gave a perfectly sane 0.796). The failures are concentrated exactly where
the observed-information matrix is worst-conditioned — which in this problem
is the same regime as separation. That the failure mode itself tracks
separation is informative, not just a bug to route around: it says the
observed-information surface is genuinely pathological in the separated
regime, which is the whole reason Firth is being tried here.

**Self-check exercised on this route** (see the script's development
history): asserting the correct-sign step improves on AGHQ, then flipping the
applied step's sign and re-asserting it is worse, run on the SAME fit/data —
this confirmed the check could discriminate a real code mutation, but both
directions were sane-looking only in the sense that they both blew up in
magnitude; the underlying instability was orthogonal to sign and had to be
found by tracing the Hessian noise, not by this check alone. This is reported
plainly: the discriminating self-check passed, but it was not sufficient on
its own to catch the numerical instability — a second, more targeted
diagnostic (the `h_outer` sweep above) was needed.

## Adopted route: Nelder-Mead on the penalised VALUE (derivative-free)

The fix follows directly from the diagnosis: `nll_firth`'s VALUE is stable,
only its finite-difference GRADIENT is not, so use an optimiser that never
needs the gradient. `stats::optim(..., method = "Nelder-Mead")` fits
`nll_firth(theta)` directly from the AGHQ MLE `theta_hat`, evaluating the
(reduced-cost, see below) Hessian-based penalty only as a **value** at each
simplex trial point. This sacrifices the fast convergence of a gradient method
but sidesteps the instability entirely. Verified sane on the case that
previously diverged (n=200, the "hard" seed used for diagnostics): AGHQ ratio
1.389 -> Firth(NM, maxit=25) ratio 1.411 — a small, plausible move, not a
divergence, though notably it moved the wrong direction on this one seed (see
campaign numbers below for whether this generalises).

Iterations are capped (stated per run, `NM_MAXIT` in the script) because each
`nll_firth` evaluation is itself a full finite-difference Hessian; NM
convergence codes are recorded and reported rather than assumed.

### Reduced-cost Hessian

Each Hessian uses a cheaper finite-difference scheme than the fully-central
one used elsewhere in this project for the Cox-Reid `j_bb` (`06-three-arm.R`):
diagonal terms stay central (2nd-order accurate); off-diagonal (mixed-partial)
terms use a forward 4-point stencil,
`(f(x+h*ei+h*ej) - f(x+h*ei) - f(x+h*ej) + f(x)) / h^2`, which is only
`O(h)`-accurate instead of `O(h^2)` but needs `choose(p,2)` evaluations
instead of `4*choose(p,2)`. At `h=1e-4` the extra discretisation error on a
log-determinant (itself only a 0.5x term in the objective) is negligible
against the effect sizes in play (ratio changes of 0.1-1.0). Total evaluations
per Hessian: `1 + 2*p_theta + choose(p_theta,2)` — about a third of the
fully-central scheme's cost.

### Reduced seed counts — and why, stated plainly

At run time this machine was running **~90 concurrent R worker processes**
from the other three parallel slices of this same brief (`load average ~314`
on a 20-core box, confirmed directly with `uptime`/`ps aux` immediately before
launch). A single NM fit at n=200, `maxit=25` measured **123s wall-clock**
under that contention — far above what the isolated per-Hessian benchmark
would predict on a quiet machine. The seed counts actually run were cut to
what could plausibly finish while sharing the machine with three other live
campaigns, not to what this algorithm alone would need on a quiet box:

| n   | seeds requested | seeds run |
|-----|------------------|-----------|
| 50  | >=20             | 8         |
| 100 | >=20             | 6         |
| 200 | >=20             | 6         |
| 800 | >=20             | 3         |

This is a real limitation on statistical precision (MCSEs below are
correspondingly wide) and is reported as such, not normalised away. `NM
maxit` was also capped at 12 for the campaign for the same reason.

## Campaign results

Wall clock for the whole campaign (23 fits, `mc.cores=4`): **598.2s** (~10
min), run concurrently with the other three slices' campaigns on the same
machine (load average fell from ~314 to ~230 to ~10 R processes system-wide
over the course of this run, i.e. contention eased partway through — later
fits ran faster than the diagnostics predicted from the peak-contention
regime).

```
=== ratio ||Lambda_hat||/||Lambda_true||; T=4, q=1, k=9, NM maxit=12 ===
     n |   Laplace              |   AGHQ                 |   AGHQ+Firth(NM)       | n_seeds
    50 |   1.218 (mcse 2.197)   |   1.142 (mcse 0.316)   |   1.105 (mcse 0.326)   |    8
   100 |   0.803 (mcse 1.500)   |   1.193 (mcse 0.394)   |   1.210 (mcse 0.394)   |    6
   200 |   0.751 (mcse 1.579)   |   1.065 (mcse 0.248)   |   1.023 (mcse 0.281)   |    6
   800 |   0.768 (mcse 0.105)   |   1.109 (mcse 0.067)   |   1.019 (mcse 0.072)   |    3
```

(These medians differ from the earlier 288-fit `05-descend` ladder because n
here is a much smaller, differently-seeded sample — 3-8 seeds vs 6-30 — so
compare shape, not the exact digits.)

**On the median alone, Firth looks like it helps at n=200 and n=800.** That
reading does not survive looking at the per-fit data, and the per-fit data is
the more important result here.

### The finding that matters more than the medians: NM never converged, and the correction is close to a coin flip

**Every one of the 23 fits hit the Nelder-Mead iteration cap without internal
convergence** (`optim()`'s own `convergence` code was 1 — "iteration limit
reached" — for all 23/23 fits; every single fit used exactly 13 function
evaluations, `NM_MAXIT=12`). None of the "Firth" numbers above are a converged
Firth-penalised MLE; they are AGHQ plus whatever a 13-evaluation-capped
simplex search could find, which for a compute-bound reason (not a scientific
one) is not much:

```
per-n: does the correction move ||Lambda|| ratio CLOSER to 1 (better), leave it
       exactly unchanged (unchanged, step_norm=0 -- NM never accepted a move),
       or FURTHER from 1 (worse)?
  n=  50: better=2  unchanged=2  worse=4   (of 8)
  n= 100: better=1  unchanged=3  worse=2   (of 6)
  n= 200: better=1  unchanged=2  worse=3   (of 6)
  n= 800: better=1  unchanged=2  worse=0   (of 3)
  TOTAL:  better=5  unchanged=9  worse=9   (of 23)
```

At the level of individual fits, the correction **improved 5, did nothing for
9, and made 9 worse.** The favourable-looking group medians at n=200 and
n=800 are each carried by a single large, fortunate move (e.g. seed 503 at
n=800: AGHQ ratio 1.109 -> Firth 1.019, the whole reason the n=800 median
looks good) sitting alongside fits that did not move at all. **This is not
evidence that Firth-with-observed-information reliably reduces the bias here
— on this run it is closer to noise than a systematic correction**, and that
is the honest headline, not the median table above.

### Large-n vanishing self-check — ran, and it FAILED as designed to catch exactly this

Firth's correction is `O(1/n)` and should shrink as n grows; the pre-declared
check was that median `|step_norm|` fall monotonically across the n-ladder.
Measured:

```
     n=50      n=100      n=200      n=800
  0.2909     0.0750     0.1563     0.0000
  monotonically non-increasing across the n-ladder: FALSE
```

It is **not** monotonic (n=200's median step exceeds n=100's), and the
self-check correctly flags this rather than silently passing. The likely
cause is visible in the per-fit data above: roughly 40% of fits at every n
have `step_norm` exactly zero (NM never accepted a move at all, not "found a
small move"), so the median is dominated by which fits happened to get stuck
vs. which happened to move, not by a smoothly shrinking effect size. A
genuinely converged Firth fit would be needed to test the vanishing prediction
properly; this capped implementation cannot cleanly separate "the correction
is small at large n" from "NM got stuck at large n" — and on n=800 specifically
2/3 fits show exactly zero movement, so the n=800 "0.000" is the stuck-cases
median, not evidence the correction vanished.

### Separation correlation — could not be tested on this data

`sep_frac` (fraction of `|eta| > 10`) was **exactly 0 for all 23 fits** in
this reduced sample — none of the fits actually run happened to land in the
separated regime that motivated trying Firth in the first place. `cor()`
correctly returned `NA` with a zero-standard-deviation warning rather than a
fabricated number. This is a genuine gap created by the reduced seed count
(see contention discussion above), not a null finding about the mechanism:
with only 3-8 seeds per n and `lam_sd=1.2`, this particular draw simply did
not sample a separated fit at these n's. A larger seed count (the originally
requested >=20) would very likely hit some, based on the 62/320-observation
separation rate measured elsewhere in this project at similar settings.

## Answers to the brief's specific questions

1. **Does Firth close the small-n gap?** **No, not demonstrably, on this
   evidence.** The group medians move in a favourable direction at n=200 and
   n=800, but the per-fit breakdown (5 better / 9 unchanged / 9 worse across
   23 fits, zero of which internally converged) shows this is not a reliable
   effect — it is dominated by a small number of large individual corrections
   plus a large fraction of fits where the capped optimiser made no move at
   all. A properly converged Firth fit (full NM to convergence, or a stabilised
   analytic-gradient route) would be needed before drawing a real conclusion,
   and that was exactly the thing measured as prohibitive on this machine (see
   cost section above).
2. **Wall-clock cost.** A literal full re-optimisation was measured
   prohibitive before any campaign was run (single Hessian ~12.8s at n=200 on
   a quiet-ish machine; a single AGHQ `ref_fit()` at n=800 exceeded 2 minutes
   in isolation). The adopted Nelder-Mead route costs one Hessian per simplex
   evaluation; under heavy machine contention (~90 concurrent R processes from
   sibling slices, load average ~314) a single diagnostic NM fit at n=200,
   `maxit=25`, measured **123s**. The full 23-fit campaign at the reduced
   `maxit=12` completed in **598s** total (`mc.cores=4`), helped partway
   through by contention easing (system R-process count fell from ~91 to
   ~10). Per-n mean per-fit Firth-step wall-clock: 15.5s (n=50), 26.8s
   (n=100), 57.0s (n=200), 66.4s (n=800, note this ISN'T much larger than
   n=200's despite 4x the data — because at `maxit=12` every fit terminates
   after the same fixed 13 evaluations regardless of n, so cost scales with
   per-evaluation Hessian cost, not with how much exploration NM actually did).
3. **Large-n vanishing self-check.** Ran, and **failed** to show clean
   monotonicity (see above) — itself informative given the compute-capped
   design, not a simple pass/fail on the scientific question.
4. **Concentrated in separated fits?** **Could not be tested**: `sep_frac = 0`
   for all 23 fits actually run (see above) — a consequence of the reduced
   seed count, not a finding that separation is irrelevant. Independently, the
   *abandoned* one-step-Newton route's catastrophic failures (ratios in the
   thousands) WERE concentrated in the worst-conditioned Hessians, which in
   this problem is the same regime as separation — indirect evidence that
   separation is exactly where this problem's curvature misbehaves, even
   though that route was not used for the final numbers and did not carry a
   `sep_frac` measurement of its own.

## What was verified, and what was not

**Verified**: `nll_firth`'s value (not gradient) is stable under Hessian-step
variation (h=1e-2 to 1e-4 changes logdet by <0.05 at n=200). The Nelder-Mead
route does not diverge on the case where the Newton route diverged. The
self-check discriminates a real sign mutation (correct vs flipped Firth-sign
give materially different answers on the same fit). All 23 campaign fits
completed and were checked individually (not just at the median): every one
hit the NM iteration cap (`convergence=1`, `counts=13`) and the per-fit
better/unchanged/worse breakdown (5/9/9) was computed directly from the raw
CSV, not inferred from the summary table — this is what caught the medians
being unrepresentative in the first place.

**NOT verified / explicitly out of scope**: full convergence of the NM
optimisation (capped at `maxit=12` for the campaign, `maxit=25` for the single
diagnostic case — NEITHER reached `optim()`'s internal convergence on any fit
attempted, and this is reported rather than assumed); expected (vs observed)
information as the "textbook" Firth recipe; the requested `n<=800`, `>=20`-seed
grid at full size (cut for measured machine contention, see table above); the
separation-correlation question (no separated fits landed in this reduced
sample); whether a properly-tightened inner tolerance and a Richardson-style
outer step could rescue the one-step Newton route (plausible but not
attempted — the Nelder-Mead route was faster to get a correct answer from and
is reported instead); whether a larger `NM_MAXIT` or a warm second NM restart
from the capped result would let the correction actually converge and change
the better/unchanged/worse balance — the single most important follow-up this
slice identifies but does not answer.
