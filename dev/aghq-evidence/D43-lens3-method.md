# D-43 completion panel — Lens 3: statistical soundness

**Reviewer:** fresh, uninvolved. **Question:** would a hostile methods referee accept the
claim? **Default under D-43:** NOT-DONE unless the evidence compels otherwise.

**Worktree:** `/private/tmp/gllvmtmb-arc0-identifiability` (`claude/aghq-engine-20260728`,
base `main` @ `72c2e53d`). All numbers below were recomputed by me from
`dev/aghq-evidence/totoro-suite-inc.csv` (954 rows), `13-coverage-inc.csv` (98 rows) and
`10-penalty-prior.csv`. The authors' arithmetic reproduces exactly (their `sigma` column is
`median(sigma_rat)`, their `rho` column is `median(rho_absd)`); nothing below is an
arithmetic dispute.

---

## Summary of position

Two of the claim's five components survive a hostile read: **Laplace's default is genuinely
unchanged** (`R/gllvmTMB.R:1221`, `aghq = FALSE`), and **the quadrature genuinely does
something at large n that no penalty can do**. Everything else — the "better at every
sample size", the ridge's a-priori status, the metric, and the entire inferential half —
does not survive. The decisive problem is not any one of them. It is that the claim's own
evidence file contains the control arm that refutes the headline, the authors found it,
wrote the retraction, and then wrote a second entry withdrawing the retraction on a
non-statistical ground.

---

## 1. The ridge: is τ = 2 truth-free?

**No — not as a matter of process, whatever the merits of the argument in isolation.**

The a-priori argument in `totoro-suite.R` (a loading of 1 swings occurrence 0.27→0.73;
4 swings 0.018→0.98; so N(0, 2) is weak on the logit scale) is a reasonable *scale*
argument and does not name `lam_sd`. I accept it as written. What I do not accept is the
sequence around it.

`10-penalty-prior.R:141-152` makes a **different** a-priori argument — "a weakly-informative
unit-variance Gaussian prior on each raw loading, `Lambda_j ~ N(0,1)`, i.e. `lambda_pen = 1`
... the generic unit-scale default a modeller would reach for with no prior information" —
and explicitly labels it `LAMBDA_REC <- 1.0`, i.e. **τ = 1**. That slice then measured
τ = 1 and found it shrinks: at n = 800, ratio 1.060 (unpenalised) → 0.957. The shipped value
is τ = 2, whose a-priori justification was written afterwards, in a different script, and
which is **not on slice 10's sensitivity grid at all** (`GRID_CHEAP = c(0, 0.02, 0.1, 0.3, 1)`
in `lambda_pen`; τ = 2 is `lambda_pen = 0.25`).

The sensitivity curve is the problem. From `10-penalty-prior.csv`, median ‖Λ̂‖/‖Λ‖ at
n = 100 (T = 4, q = 1, lam_sd = 1.2, 20 seeds):

| `lambda_pen` | 0 | 0.02 | 0.1 | 0.3 | 1.0 |
|---|---|---|---|---|---|
| n = 100 | 1.448 | 1.188 | **0.978** | 0.858 | 0.741 |
| n = 200 | 1.163 | 1.113 | 1.059 | 0.986 | 0.849 |
| n = 800 | 1.060 | — | — | — | 0.957 |

This is a **monotone knob whose sweep straddles the target**: every answer between 1.45 and
0.74 is reachable at n = 100 by choosing τ. When a one-parameter monotone knob spans the
truth and the shipped setting lands at 1.04, "chosen a priori" is a claim about the author's
introspection, not a property of the evidence. A referee does not have to allege bad faith
to reject it; the standard reply is that the sensitivity curve makes the a-priori/tuned
distinction unfalsifiable from the outside, and the correct remedy is to report the claim
**across** τ rather than at one τ.

**The τ = 1-costs-10%, τ = 2-costs-nothing distinction is not real as stated.** It is a
comparison across two different DGPs (slice 10: T = 4, q = 1, lam_sd = 1.2; the suite:
p = 6, q = 2, lam_sd = 1.0) and, more importantly, the suite *does* show the ridge costing
where the confound is absent: at p = 6, n = 1600, **Laplace+ridge |σ − 1| = 0.138 versus
Laplace alone 0.118** — the ridge makes large-n σ recovery *worse*. The reason AGHQ+ridge
shows no such cost (0.012 → 0.011) is that AGHQ's residual upward bias and the ridge's
downward shrinkage point in opposite directions. **That is an error-cancellation mechanism,
sitting undiagnosed inside the shipped default, one session after the same team retracted an
error-cancellation story about Laplace.** It is not a demonstration that τ = 2 is costless.

**"What if the true loadings were 5?"** The suite hard-codes `lam_sd = 1.0`
(`totoro-suite.R`, `mk(g$n, g$p, g$q, 1.0, g$seed)`). τ = 2 is therefore measured only where
the prior is **correctly specified up to a factor of 2 in SD** — the single most favourable
configuration a shrinkage prior can be given. At true loadings of 5, τ = 2 contributes
0.5·25/4 = 3.1 nll units *per loading*; with the 11 free loadings of the p = 6, q = 2 shape,
≈ 34 nll units of pull against a small-n likelihood of a few hundred. No cell in this
campaign measures that. A study of a shrinkage estimator that never varies the true scale
relative to the prior scale has not measured the estimator; it has measured a
correctly-specified prior.

## 2. The metric: does `sigma` inherit the elementwise defect?

**No — it inherits a worse one. It is sign-confounded.**

`sigma_rat = median(sqrt(diag(Σ̂))/sqrt(diag(Σ)))` is a median over the p traits, so it is
robust to one exploding trait — which is exactly the failure. Split the Laplace p = 6,
n = 100 cell by whether the fit ran away (`frob_rat > 2`):

| Laplace, p = 6, n = 100 | n fits | median `frob_rat` | median `sigma_rat` |
|---|---|---|---|
| healthy | 15 | 0.84 | **0.915** |
| runaway | 15 | **15.7** (range 9.1–26.8) | **0.800** |

`cor(frob_rat, sigma_rat) = −0.209`. The fifteen fits whose ‖Λ̂‖ is **9 to 27 times too
large** are reported by the σ metric as *under*-estimating the latent SDs. Catastrophic
over-estimation and honest under-estimation map onto the same column, in the same
direction. The headline "Laplace σ = 0.825" is therefore not a bias estimate — it is a
50/50 mixture of a healthy population at 0.915 and a diverged population that the metric
scores as 0.800.

Condition on non-divergence (`frob_rat ≤ 2`) — which is what a user reports — and the
headline effect halves:

| p = 6, |σ − 1| | all fits | non-diverged only |
|---|---|---|
| n = 100 Laplace | 0.175 | **0.085** |
| n = 100 AGHQ+ridge | 0.043 | 0.043 |
| n = 100 AGHQ (no ridge) | 0.197 | 0.187 |

The advertised 4× gap at n = 100 (0.175 vs 0.043) is a 2× gap (0.085 vs 0.043) among fits
anyone would report. The remainder is divergence contamination — and divergence is
separately and completely fixed by the ridge alone.

Related: nowhere in this campaign is a bias/variance/RMSE decomposition, or any
decision-theoretic risk, reported for any arm. Median-of-per-fit-medians has no such
interpretation and systematically favours whichever arm has its tail suppressed.

## 3. The comparison: is AGHQ+ridge vs unpenalised Laplace fair?

**No, and this is the finding.** The Laplace+ridge control **is already in the 954-fit
dataset** — the grid crosses `tau = c(Inf, 2)` with `k = c(1, 9)`, and `k = 1` is Laplace
exactly (`dev/aghq-r-reference.R`, line 24: "At k = 1 this IS the Laplace approximation,
exactly"). All four arms, 30 seeds each. The headline table reports three of them.

Full 2×2, p = 6, q = 2, |σ − 1| / median rho error / runaway%:

| n | Laplace | **Laplace+ridge** | AGHQ | AGHQ+ridge |
|---|---|---|---|---|
| 100 | 0.175 / 0.310 / 50% | **0.053 / 0.223 / 0%** | 0.197 / 0.233 / 13% | 0.043 / 0.230 / 0% |
| 200 | 0.191 / 0.305 / 47% | **0.140 / 0.204 / 0%** | 0.063 / 0.224 / 13% | 0.040 / 0.225 / 0% |
| 400 | 0.149 / 0.155 / 33% | 0.105 / 0.130 / 13% | 0.070 / 0.121 / 7% | 0.054 / 0.120 / 0% |
| 1600 | 0.118 / 0.087 / 7% | 0.138 / 0.091 / 17% | 0.012 / 0.075 / 4% | 0.011 / 0.062 / 0% |

Three consequences the authors' own retraction does not reach:

**(a) The runaway is the ridge's doing, not the quadrature's — and AGHQ alone makes it
worse in the other shape.** Laplace+ridge takes runaway% to **0% at n = 100 and n = 200**,
identically to AGHQ+ridge. In the p = 4, q = 1 shape, **AGHQ *without* the ridge has more
runaways than Laplace** at every n it occurs: 30% vs 20% (n = 100), 13% vs 7% (n = 200), 7%
vs 3% (n = 400). "Eliminates the divergent-fit mode" is a true statement about the ridge and
a false statement about the quadrature.

**(b) The paired analysis — which the shared-seed design licenses and nobody ran — says the
quadrature contributes nothing detectable at 3 of 4 sample sizes.** Per-seed paired
differences, AGHQ+ridge minus Laplace+ridge (negative favours AGHQ+ridge), n = 30 pairs:

| n | Δ|σ−1| (t, Wilcoxon p) | Δ rho error (t, Wilcoxon p) |
|---|---|---|
| 100 | **+0.019** (t = +0.66, p = 0.69) | **+0.006** (t = +1.09, p = 0.22) |
| 200 | −0.063 (t = −3.26, p = 0.003) | −0.0001 (t = −0.01, p = 0.64) |
| 400 | −0.030 (t = −1.37, p = 0.096) | −0.007 (t = −0.67, p = 0.54) |
| 1600 | −0.088 (t = −7.62, p < 0.001) | −0.050 (t = −3.61, p < 0.001) |

At n = 100 the sign is **against** AGHQ on both metrics. On rho, the quadrature is
indistinguishable from zero at n = 100, 200 **and** 400. The only place the quadrature is
unambiguously and reproducibly doing work is n = 1600 (plus σ at n = 200). Even against the
*unpenalised* Laplace, the n = 400 rho advantage fails a rank test (Wilcoxon p = 0.077) —
i.e. it lives in the runaway tail, not in the typical fit.

**(c) The "correction to the correction" is not a statistical argument.** `decisions.md`
restores the headline on the ground that "`Laplace + ridge` is not a route anyone can
currently run — not in this package and not in `gllvm`." But Laplace+ridge is unavailable
*because the authors bundled the ridge to AGHQ*: `R/fit-multi.R:5066`,
`aghq_ridge_tau <- control$aghq_ridge %||% 2`, inside the AGHQ branch, and `run_one`'s ridge
is 12 lines wrapping `fn`/`gr` (`R/fit-multi.R:4874-4890`) with no dependence on the
quadrature whatsoever. The comparator's non-existence is a packaging decision, not a fact
about the world. A referee will phrase this as: *you created the confound and then cited the
confound as grounds for not controlling it.* The over-correction warning in that entry is
well-taken as a general principle and misapplied here — the first entry withdrew the right
thing.

The defensible sentence is the one the **first** entry wrote and the second deleted.

## 4. Generalisation

One DGP (Λ ~ N(0,1), b ~ N(0.3,0.4), balanced, complete, no covariates, no missing cells),
one family, two shapes, `lam_sd` never varied, 30 seeds. To call any of this a property of
the estimator rather than of this simulation, a referee would minimally require: (i)
`lam_sd` varied across at least {0.5, 1, 3} so the prior is mis-specified in both directions
— currently the ridge is only ever tested where it is nearly right; (ii) at least one
non-binomial family, since the routing map is (T, M, family) and the family axis is by the
authors' own concession unmeasured; (iii) unbalanced/incomplete Y, which is the normal state
of a JSDM matrix and the regime where weak identification is worst; (iv) q ≥ 3, since the
tensor grid is k^q and both the cost and the adaptation quality change qualitatively.
Absent those, the honest scope sentence is "in this simulation", not "the estimator".

Two smaller design points a referee would raise: fits are **missing not at random** (27/30
in the unpenalised n = 1600 cells, 30/30 in the ridge cells) with no sensitivity analysis,
and the missingness is concentrated in the arms whose failure mode is being measured. And
the **oracle validation of the shipped template** (`02-template-vs-oracle.R`) is a single
dataset at **n = 6, p = 3, q = 1, one seed** — the q ≥ 2 tensor path that carries the
headline shape has never been checked against an external integrator.

**On the Gaussian exactness control:** it has almost no diagnostic power for this claim. For
a Gaussian latent-linear model the Laplace approximation is exact, so adaptive GH reproduces
it at *every* k by construction — "identical at k = 3 and 9, +6.25e-13" is close to a
tautology and cannot detect an error in the non-Gaussian weighting, which is the only place
an error could live. It is a fine regression test; it is not evidence for "correct
likelihood where Laplace is not".

## 5. Coverage — the inferential half is asserted, not demonstrated

The claim's stated justification is that "LRTs, AIC and intervals rest on" a correct
likelihood. Coverage is what this project gates on: the 2026-07-19 D-43 panel **withheld** a
certificate whose coverage was 0.9486–0.9529 because the 2·MCSE bands dipped below 0.95.

What exists (`13-coverage-inc.csv`):

| n | Laplace cover | AGHQ cover | usable seeds (L / A) | AGHQ SE/SD |
|---|---|---|---|---|
| 100 | 0.875 | 0.868 | 12 / 17 | 1.49 |
| 400 | 0.735 | 0.917 | 17 / 18 | 1.07 |
| 1600 | 0.667 | 0.865 | 12 / 13 | 0.97 |

Four things about this. (i) It is **incomplete**: 98 of an expected 180 rows, and
`13-coverage.csv` — the file the script writes on completion — does not exist, so the run
was killed. (ii) **AGHQ never reaches nominal**: best cell 0.917, and at n = 1600 it is
0.865 on 13 usable seeds. Against this project's own 0.95 bar with a 0.9486 precedent for
withholding, 0.865 is not a marginal shortfall. (iii) It is a **different DGP** (T = 4,
q = 1, lam_sd = 1.2) from the headline shape. (iv) Most importantly it is the **unpenalised**
AGHQ — `13-coverage.R` calls `ref_fit` only, never the ridge. **There is zero interval
evidence for the configuration that actually ships.**

That last gap is not cosmetic, because the shipped configuration has a structural interval
problem visible in the code. The ridge wraps only the optimiser's `fn`/`gr`
(`R/fit-multi.R:4874`); the finaliser evaluates the **unpenalised** objective at the
penalised optimum (`obj_try$fn(par_best)`, ~line 5399) and `TMB::sdreport(obj, par.fixed =
opt$par, ...)` (line 5492) inverts the **unpenalised** Hessian there. So with the default
`aghq_ridge = 2` a user gets:

- a **MAP point estimate reported with ML curvature** — an interval centred at a shrunken
  value with an unshrunken width. That is neither a valid frequentist Wald interval nor a
  posterior interval, and its coverage is unmeasured;
- a `logLik` evaluated at a **non-maximiser** of the likelihood it reports, so AIC is not
  AIC, and in a nested LRT the penalty pull is *larger* for the larger model (more
  loadings), so the bias does **not** cancel — it is systematically anti-larger-model by an
  unquantified amount;
- a convergence diagnostic that cannot fire on its own gradient leg: `g_cur` is the honest
  unpenalised gradient (line 5293) tested against `grad_tol = 1e-4` (line 5200), while at
  the ridge optimum that gradient equals λ/τ² = λ/4 per loading — ≈ 0.25 for λ ≈ 1, i.e.
  2500× the tolerance. Ridge-on fits must therefore always exit via the `f_tol` leg, and any
  downstream gradient-based convergence check will read them as unconverged.

A hostile referee reading "correct likelihood" next to a default that returns a MAP estimate
with ML standard errors and a log-likelihood off its own maximum will stop there.

---

## What I would accept

Not in dispute, and worth keeping: Laplace's default is untouched (`aghq = FALSE`); the
ridge is exactly rotation-invariant (`10-invariance-check.csv`, both identities to 1e-15);
the SE/SD diagnostic (0.73 → 0.97 at n = 1600) is a genuine and clean demonstration that
the AGHQ curvature is right where Laplace's is not; and the n = 1600 quadrature effect
survives the fair paired control at p < 0.001 on both σ and rho. **There is a real result
here.** It is: *AGHQ removes an O(1/T) integral error that no amount of data or penalty
removes, and that error is what wrecks Laplace's curvature; the small-sample gains
advertised alongside it belong to the ridge.* That is narrower than the claim and it is
defensible.

---

**VERDICT: NOT-DONE**

The claim is not merely over-stated; it attributes to the quadrature a gain that its own
954-fit dataset assigns to the penalty. The fair control (Laplace+ridge, `k = 1, tau = 2`)
is present in the data, was found, was written up as a retraction, and was then restored on
the ground that the control "is not a route anyone can currently run" — a coupling the
authors themselves created in 12 lines of `run_one`. Paired on shared seeds, the quadrature
is indistinguishable from zero on rho at n = 100, 200 and 400 and points the *wrong way* at
n = 100 on both metrics; the ridge alone takes runaways to 0% exactly as well as AGHQ+ridge
does; AGHQ *without* the ridge is worse than Laplace on runaways in the p = 4 shape; the σ
metric is anti-correlated with the failure it is meant to summarise (r = −0.21; diverged
fits at ‖Λ̂‖/‖Λ‖ ≈ 16 score σ = 0.80 while healthy fits score 0.92), so half the advertised
n = 100 effect is contamination; τ = 2 was adopted after τ = 1 was measured and sits on a
monotone sensitivity curve spanning 1.45–0.74 that was never run at any true loading scale
other than the one matching the prior; and the inferential half of the claim — "correct
likelihood, so LRTs/AIC/intervals rest on it" — has no evidence at all for the shipped
configuration, while the code shows that configuration returning a MAP estimate with ML
curvature, a `logLik` off its own maximum, and a gradient diagnostic that cannot converge.

**Smallest evidence that would flip me:** one 30-seed coverage cell for the **actually
shipped** configuration — AGHQ k = 9 **with** `aghq_ridge = 2`, p = 6, q = 2, at n = 400 and
n = 1600 — reporting Wald coverage of the Σ diagonal and off-diagonal against nominal 0.95
with MCSE, alongside the equivalent Laplace+ridge cell. One script, one Totoro run. It is
the single measurement that adjudicates the MAP-point/ML-curvature problem, it is what this
project gates on, and it is the only number that could make "correct likelihood" mean
something operational rather than rhetorical. (Non-evidential precondition, which no run can
supply: the user-facing sentence must name the comparator and drop "at every sample size" —
i.e. reinstate the first `decisions.md` retraction and delete the second.)
