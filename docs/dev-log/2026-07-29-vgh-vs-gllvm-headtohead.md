# VGH vs the gllvm package — corrected head-to-head, 2026-07-29

Testing the claim "VGH + Laplace is the fastest and best GLLVM algorithm in R".
Gaussian family, q = 2, 3 seeds per cell, each package at its **own defaults**.

## A defect found and fixed before any number was believed

The first run reported `relfrob_G` of **5772** for gllvm — i.e. gllvm looked
catastrophically inaccurate. It is not. `gllvm` constrains its loading matrix for
identification: `fit$params$theta` carries **1.0 on the diagonal** and is *not* the
loadings; the scale lives separately in `fit$params$sigma.lv`. The actual loadings are
`theta %*% diag(sigma.lv)`.

Verified on an 80×5 gaussian fixture: `theta` alone → relfrob 505.2; with `sigma.lv` →
0.366. Every accuracy number below uses the corrected extraction. **Had this gone
unnoticed it would have produced a spectacular and entirely false "gllvm is inaccurate"
result.**

## Speed — median seconds

| n | T | gllvm VA | gllvm LA | VGH | VGH vs VA | VGH vs LA |
|---|---|---|---|---|---|---|
| 100 | 5 | 0.119 | 0.129 | 0.016 | 7.4× | 8.1× |
| 400 | 5 | 1.614 | 0.316 | 0.035 | 46.1× | 9.0× |
| 1000 | 5 | 15.874 | 1.054 | 0.058 | **273.7×** | 18.2× |
| 100 | 10 | 0.164 | 0.147 | 0.027 | 6.1× | 5.4× |
| 400 | 10 | 1.926 | 0.614 | 0.047 | 41.0× | 13.1× |
| 1000 | 10 | 17.226 | 2.265 | 0.078 | 220.8× | 29.0× |

## Accuracy — median relfrob(G_hat, G_true), Frobenius scale, unsquared

Rotation-invariant by construction; raw loadings are never compared.

| n | T | gllvm VA | gllvm LA | VGH |
|---|---|---|---|---|
| 100 | 5 | 0.2983 | 0.2909 | 0.2353 |
| 400 | 5 | 0.0967 | 0.0811 | 0.0833 |
| 1000 | 5 | 0.0942 | 0.0582 | 0.0401 |
| 100 | 10 | 0.1839 | 0.1839 | 0.1880 |
| 400 | 10 | 0.0825 | 0.0825 | 0.0776 |
| 1000 | 10 | 0.0343 | 0.0343 | 0.0333 |

**VGH is not trading accuracy for speed.** Its G-recovery is comparable to both gllvm
arms everywhere and better in two of six cells. That is the substantive result.

## Do not quote the 273× — read this first

1. **The gllvm VA arm is behaving oddly, and the largest ratios come from it.** gllvm's
   VA takes 15.9 s where its own LA takes 1.05 s at n = 1000. A variational method being
   15× *slower* than Laplace in the same package is not what VA is supposed to do; it
   suggests that path is hitting something pathological on this DGP (iteration count,
   starting values), not that VGH is 274× better engineered. **The defensible comparator
   is gllvm's LA arm, where the ratio is 5–29×.** Quoting the VA ratio without diagnosing
   why VA is slow would be exactly the kind of flattering artefact this audit exists to
   catch.
2. **Equal effort is NOT established.** Each package ran at its own defaults —
   convergence tolerances, `n.init`, starting values all differ. An unequal-effort timing
   is not yet a speed result.
3. **Objectives are not comparable.** VGH reports an ELBO (a lower bound); gllvm reports
   a log-likelihood. They are never tabulated against each other here, and must not be.
4. **Narrow scope:** gaussian only, q = 2, n ≤ 1000, one DGP, 3 seeds. VGH admits only
   three families, no `Psi`, no structured or spatial tiers — and **is not wired into the
   package**, so no user can currently reach it.

## ⚠️ Adversarial review REFUTED the above. Read this before quoting any number.

An independent reviewer re-ran the evidence and found the framing above still too
generous. The measurements are real; what they license is much less.

**1. The thing being claimed was never benchmarked.** The claim is "VGH **+ Laplace
finish**". This benchmark has no Laplace stage — arm C is `.vgh_fit` and nothing else.
There is **zero** external evidence for the actual Phase 2 pipeline, whose whole point is
that VGH's speed must survive paying for a Laplace finish.

**2. A three-line closed form beats VGH on this problem.** With identity link and
dispersion held fixed, the model is linear-Gaussian PPCA. A bare `eigen()` of the residual
covariance ties VGH's recovery in every cell (differences ≤ 0.006) in **≤ 1 ms** — 15–100×
*faster* than VGH. VGH converges in 5–8 outer iterations precisely because `.vgh_init`
(`R/va-vgh.R:466`) **is** that eigendecomposition. A benchmark a trivial closed form wins
cannot license "fastest anything".

**3. VGH was handed a true parameter — the single biggest review threat.**
`gaussian_anchor` fixes `phi <- rep(gaussian_sd^2, Tt)` at the **true simulated value**
and never estimates it, while gllvm estimates `T` dispersions. That is an *information*
advantage, not merely a cost advantage: it inflates every speed ratio **and** contaminates
the accuracy tie. Every ratio here is an upper bound, not a point estimate.

**4. The incumbent ran in its most expensive configuration.** `gllvm` VA with
`control.va = list(Lambda.struc = "diagonal", diag.iter = 0)` is **2.3–2.6× faster** at
essentially identical logLik (n=1000/T=5: 6.59 s vs 15.45 s). The benchmarked default
fits an *unstructured* variational covariance — a strictly richer approximating family
than VGH's mean-field. `n.init = 1` also denied gllvm its restart remedy, and its VA arm
landed in a clearly worse optimum in one cell (29.5-nat gap).

**5. There is a crossover: at n = 50 VGH is SLOWER** than gllvm's LA (0.086 s vs 0.075 s).
Unqualified "faster" is already false at the small end.

**6. Timing hygiene will not survive review.** 19 single-shot `proc.time()` calls, no
warm-up, no replication, uncontrolled BLAS threads. VGH fits are 16–97 ms — noise-dominated
at that magnitude. The `seconds` column is also asymmetric: gllvm's external wall clock vs
VGH's self-reported `fit$seconds`, whose clock starts *after* init (measured 0–2 %, so the
ratios survive, but it is not like-for-like).

**7. Binomial — the only admitted family that actually exercises the 15-point
Gauss-Hermite quadrature — was never run.** The benchmarked cases are VGH's cheapest
(`exact = TRUE`).

**8. Engine bug found in passing:** `.vgh_fit` returns `elbo = prev`, the ELBO from the
*previous* sweep, not the objective at the returned parameters.

## What is actually supported

> On simulated gaussian data with identity link, q = 2, n ≥ 100, **and the residual
> dispersion fixed at its true value**, `.vgh_fit` reaches the same rotation-invariant
> G-recovery as `gllvm` 2.0.13's VA and LA engines in 5–28× less time than LA — a margin
> that shrinks 2.3–2.6× once gllvm's VA arm is run in its cheaper diagonal configuration,
> that reverses at n = 50, and that says nothing about other families, standard errors, or
> about the VA→Laplace pipeline, which was never benchmarked.

**Not supported:** "fastest", "best", or anything unqualified. "Best" has no accuracy
evidence on any axis — no SEs, no coverage, no predictive check, and the one metric used
is a tie (VGH ahead in 10 of 19 cells, exact binomial p = 1.0).

## Novelty, separately checked — two findings that pull in opposite directions

- **Within GLLVM packages: not pre-empted.** `gllvm` 2.0.13 does **not** automatically
  warm-start Laplace from a converged VA fit. Its `n.init` restarts the *same* method;
  `start.fit` is a manual any-to-any escape hatch. Decisive source evidence: inside
  `start_values_gllvm_TMB()`, `if (method == "LA") method = "VA"` merely relabels which
  cheap heuristic generates the initial vector — not a converged VA feeding Laplace.
- **In the wider literature: NOT novel.** VA-warm-starting Laplace predates this by years
  under other names — "Variational Laplace" (Friston, SPM), INLA's VB-correction-to-Laplace
  (Van Niekerk & Rue 2021), and the low-rank VB correction in arXiv 2111.12945. [UNVERIFIED,
  web-sourced.] The defensible novelty is *within a GLLVM implementation*, not the idea.

## What would earn a stronger claim

Gaussian with VGH **estimating** dispersion (not fixed), plus binomial and poisson, against
gllvm VA/LA/EVA in its cheap configuration; n = 25/50/75/100/250/500/1000/2000 to locate
the crossover; ≥ 20 seeds per cell; a **common gradient-norm convergence criterion** rather
than trusting nominal `tol`; warmed, replicated timings; and the Laplace finish actually
included, since that is the artifact being claimed.
