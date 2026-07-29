# VGH — a fast variational engine for gllvmTMB: what was measured, and what it means

**2026-07-29 · Claude · `claude/vgh-variational-20260729` · worktree `/private/tmp/gllvmtmb-vgh`**

**Status: RESEARCH PROBE.** Nothing promoted, nothing exported, no package file
modified. All code under `dev/vgh/`. Results LOCAL (D-50). This document is the
report, not a proposal.

---

## 0. The one-paragraph version

A variational engine built on block coordinate ascent — closed-form variational
covariance, free Newton step for the mean, and a response-wise decoupled M-step —
runs **8–15× faster than compiled TMB Laplace on gaussian and 7.7× on binomial**,
from interpreted R. Its objective is verified **identical to the package's own TMB
implementation to 4.7e-15**, so the speed gap is architectural and nothing else.
The closed form **survives structured priors** (phylo / animal / kernel /
pedigree): only the diagonal block of the structured precision enters. The
mathematics is not new; the diagnosis was already made in this repo on 2026-07-27
and left uncommitted. The honest open question is binomial recovery, and the
honest recommendation is *not* to ship VA as an estimator.

---

## 1. The problem, and why speed is the whole case

`gllvm`'s VA is much faster than its LA. In gllvmTMB the ordering is **reversed**.
`dev/three-engine-demo.md`, n=400 Bernoulli q=2: Laplace 3.66 s point-only, 5.78 s
*with* standard errors, existing VA **9.65 s point-only**. Laplace including
inference beats VA's bare point estimate.

That matters because VA is also *less* accurate than LA here. If it is not faster,
it has no case. Speed is not a nice-to-have; it is the entire argument.

## 2. Diagnosis — and it was already made, two days ago

`inst/tmb/gllvmTMB_va_r3.cpp` already implements the right ELBO: the
one-dimensional collapse is there as `v_it = ||L_i' lambda_t||^2`, with exact
Poisson log-normal, exact gaussian, Gauss-Hermite softplus (Golub-Welsch,
H in {15,25,61}, plus a heat-kernel branch for small `v`), and a Jaakkola-Jordan
bound. **The quadrature was never the problem.**

The problem is `R/va-r3-proto.R:1059`:

```r
TMB::MakeADFun(..., random = NULL, ...)
```

Every per-unit variational parameter — `N*(2q + q(q-1)/2)`, **26,985** at n=5397,
q=2 — goes into one flat vector for a quasi-Newton optimiser. Laplace declares `u`
as `random` and gets TMB's exact block-diagonal inner Newton solve. **The VA
discards the block structure Laplace exploits.**

**This was diagnosed on 2026-07-27**, with the decisive measurement — an
axis-crossover: N=800/q=3 (7,223 par) took 50.42 s while N=1600/q=2 (8,017 par)
took 46.82 s. Twice the data, less time: **cost tracks parameter count, not n**,
with per-iteration cost measured at O(p^2.27). The fix was named (`random=` /
`profile=`, collapsing 27,002 outer parameters to 17), and a closed-form CAVI for
the JJ arm was derived and verified (gradient 1.55e-15 at the fixed point).

**None of it was committed.** Those files sat untracked in a `/private/tmp`
worktree while the *committed* record read *"the scaling wall remains
unexplained"*, and the next morning both routes to a fast VA went onto the
do-NOT-do list. Both files are now preserved at
`docs/dev-log/recovered/`.

Independent confirmation that this is a real, general failure mode: Korhonen,
Nordhausen & Taskinen (2024, *WIREs*) Table 4 — Poisson-log, p=5, unstructured
`A_i`, n=200, m=50: **VA 1610.8 s vs LA 486.6 s**, i.e. LA 3.3× faster *in
`gllvm` itself*, with the cause named as the `n·p(p+1)/2` parameter count.

## 3. What VGH is

Three exact structural facts. Each verified, not asserted.

**(C1) The one-dimensional collapse.** Under `q(u_i) = N(a_i, A_i)`, `eta_ij` is
univariate normal with `m_ij = x_i'beta_j + a_i'lambda_j` and
`s2_ij = lambda_j' A_i lambda_j`. So the only intractable term is a **1-D**
integral whatever `d` is. *Not novel — already in the repo, and published by
Ormerod & Wand (2012).*

**(C2) Stein's lemma closes the variance block.** `dB/ds = s·E[b''(m+sZ)]`, so

```
A_i^{-1} = I_d + Lambda' W_i Lambda,     W_i = diag(E_q[b''(eta_ij)]/phi_j)
```

and the ELBO Hessian in `a_i` is exactly `-A_i^{-1}`, so the Newton step
`a_i <- a_i + A_i g_i` is free.

**(C3) The M-step decouples across responses.** Given the variational block, the
ELBO is a sum of `m` independent terms in `(beta_j, lambda_j)`. The expected
information in `lambda_j` is `sum_i B2_ij E_q[u_i u_i']` — the exact Fisher
information under `q`, so this is true Fisher scoring.

**No optimiser ever sees more than `(p+d)` parameters. No AD tape, no
log-determinant derivative, no third derivatives.**

## 4. Verification

### 4.1 Against the package's own TMB implementation — 4.7e-15

46 independent comparisons at fixed parameter points (binomial `n>1` and
Bernoulli, Poisson; q in {2,4,5}; H in {15,25,61}). Max **relative** difference
**4.74e-15**; max absolute 3.41e-12. Bisected: `Lambda` packing exact (0), `A_i`
4.44e-16, `mu` 8.88e-16, `v` 1.78e-15, KL 4.26e-14. Residual is summation order.

**The strongest single piece of evidence.** At H=15 the quadrature is *not
converged* — TMB alone differs from its own H=61 answer by 2.0e-5 — yet the two
implementations still agree to 3.4e-12 **at H=15**. They agree on the
discretisation *error*, which requires node-for-node identical rules.

**Negative controls confirm the test has power.** Injected errors on the R side
produced differences of 1.23 to 728.9: row-major `Lambda` packing, `L_i'L_i`
instead of `L_iL_i'`, flipped KL sign, missing `sqrt(2)` node scaling,
unnormalised weights. The grid was extended to q=4 and q=5 because at q<=3 the
row- and column-major orderings of a strict lower triangle coincide.
240/240 cells ran on the GH branch with min `v` = 4.7e-2.

**Consequence: the two engines compute the identical function, so the measured
speed gap cannot be an objective difference.** It is architectural, and only
architectural.

*Not covered:* gradients (`obj$fn` only, never `obj$gr`), the JJ arm, the gaussian
anchor, nbinom2, and **optima** — this shows the engines score the same points
identically, not that they converge to the same fit.

### 4.2 Against exact mathematics

| check | result |
|---|---|
| Gauss-Hermite rule, normal moments to k=6 | 3.6e-14 |
| C1: 1-D collapse vs 4e6-draw Monte Carlo at d=4 | 5.4e-05 |
| C2: Stein `dB/ds = s·E[b'']` vs central difference | 8.2e-11 |
| **Gaussian ELBO == exact marginal log-likelihood** | **1.26e-12** |
| Monotone ELBO — gaussian / poisson / binomial | all monotone |

The gaussian check is the strongest available oracle. For gaussian-identity the
true posterior *is* Gaussian, so the variational family **contains** it, the bound
is tight, and the ELBO must equal the exact marginal log-likelihood. It does. Any
error in the ELBO or the KL term would surface here.

### 4.3 Bugs this found — in my own code

* **Undamped Newton overshoot.** First run, Poisson monotonicity failed (min
  increment −0.43). The contraction condition is sharp: for d=1 Poisson,
  `|T'(A)| <= max_j lambda_j^2 / 8`, so the naive fixed point contracts only when
  `|lambda| < 2.83`. Fixed with per-unit backtracking along a path keeping the
  precision positive definite.
* **An `n*m` R-level loop** in the M-step, which produced a spurious superlinear
  jump at n=2000. Vectorised; validation unchanged, confirming behaviour was
  preserved.
* **A dishonest test.** The recovery gates were scoring the fits built for the
  *monotonicity* checks, deliberately run unconverged at `maxit=60, tol=0`. Poisson
  "FAIL 0.4498" was really **0.1371** once refit. Corrected.
* **An API gap.** `vgh_elbo()` has no `n_trials` argument — the binomial entry
  point is Bernoulli-only. Not fixed.

## 5. Speed

**Gaussian, m=20, d=2, vs installed gllvmTMB 0.5.0 Laplace.** Warm-up untimed.
Handicap runs against VGH: interpreted R vs compiled C++ with AD.

| n | Laplace | VGH | speedup |
|---:|---:|---:|---:|
| 200 | 7.30 s | 0.64 s | **11.5×** |
| 500 | 11.78 s | 1.41 s | **8.4×** |
| 1000 | 35.12 s | 2.40 s | **14.6×** |

**Binomial** (quadrature actually firing), n=250: Laplace 28.64 s, VGH 3.70 s —
**7.7×**.

**Scaling.** After the loop fix, per-sweep cost is linear in n. Runs truncated at
the background time limit, so no fitted exponent yet; over n=250→2000 (8× data)
time rose 3.8×, clearly sub-quadratic. For contrast, the existing VA was measured
**roughly quadratic and not completing at all beyond n ≈ 2500**.

**⚠ What the benchmark does NOT show.** It also reported VGH attaining a higher
exact log-likelihood (+6.2 to +10.0). **That is not evidence of a better optimum.**
Laplace fits **60** parameters, VGH **79** — per-trait `phi_j` against a single
shared gaussian `sigma`. A gain of that size on 19 extra parameters is roughly
what the extra parameters buy. **No equal-accuracy claim is established.**

## 6. Accuracy

| family | rel. Frobenius error on `Lambda Lambda'` |
|---|---|
| gaussian, n=300 | 0.109 |
| poisson, n=250 / 1000 / 4000 | 0.137 / 0.062 / 0.031 |
| **binomial, n=300** | **0.458 — reported, NOT gated** |

Binomial is the weak spot and it is the family that decides whether this is more
than an exploratory tool.

**A negative result that saves work: the quadrature order does not matter for
recovery.** Binomial, n=500, m=20, 3 seeds, Q in {9,15,21,31}: relative error
0.2738 and attenuation 0.9908 are **identical to four decimals at every Q**. Only
cost changes (2.37 s at Q=9 vs 6.11 s at Q=31). Sharpening the quadrature buys
accuracy in `B(m,s)`, which recovery does not depend on. **Use Q=9 — 2.6× cheaper
for an identical answer.** This is exactly what Design 109 predicts: *"tightness is
a level statement; bias is a derivative statement; no inequality connects them."*

**Provisional, and NOT a matched comparison.** Measured attenuation was **0.9908**
(moderate) and **0.9656** (high, max `v` 6.92) — very little loading shrinkage,
against 0.668 recorded for the JJ arm and 0.892 for Laplace in the three-engine
demo. If that survives a matched test it would mean exact-GH VGH does **not**
inherit the attenuation that motivates the whole VA-bias concern — which is what
Design 109 predicts, since the JJ gap literally *is* a shrinkage penalty on latent
variance while exact quadrature has no such gap. Different DGP, 20 traits vs 8,
different seeds. **Do not quote it as a matched comparison.**

## 7. Generality — does it survive structured random effects?

I claimed earlier in this session that phylo/spatial/animal tiers break this
architecture. **That was wrong and is withdrawn.** Design 106 Proposition 1 proves
`mu` and `v` accumulate additively across tiers, `eta` stays univariate Gaussian,
and *"the entire quadrature layer is untouched"* — textbook algebra, not a design
choice.

For the closed form specifically (which Design 106 never derives — it never
differentiates the ELBO with respect to `S`), the stationarity condition with a
structured prior precision `Q_p` is

```
S_g^{-1} = Q_gg + sum_{o in g} w_o a_o a_o'
```

**Only the diagonal block `Q_gg` enters.** It stays a small per-level solve — no
joint `(nd)×(nd)` inversion, no Takahashi. Off-diagonals vanish because they
multiply the off-diagonal blocks of `S`, which a level-factorised `q` sets to zero.
Cross-checks: with `Q_p = I` it reduces *verbatim* to the iid form; for a
standardised phylo field it becomes `[A^{-1}]_gg · I_C + data curvature`, consuming
exactly `diag(A^{-1})` — the same `n`-vector Design 106 §3.3 identifies from the
other direction.

**What erodes.** The *mean* does not decouple: `sum_h Q_gh m_h` pulls in the full
row of `Q`, so the free Newton step becomes a coupled sparse system. Cost is
modest and already priced by 106 as an `O(nnz)` sparse matvec, machinery the
package uses today.

**Spatial is genuinely harder.** The SPDE projection spans ~3 mesh nodes, so a
node-factorised `q` keeps the closed form but *mis-states `v` for every
observation*. The structurally-matched alternative needs a differentiable partial
inverse that 106 flags as *"an open engineering question, not a plan."* Design 106
records this as a **reversal** of Design 72, which had called spatial the easiest
structured VA win.

**Verdict: fast and general for phylo / animal / kernel / pedigree — the tier that
matters most. Spatial is a different problem.**

## 8. The check on enthusiasm

`dev/frontier/FRONTIER.md` is more sobering than Design 106's header suggests. The
"1.38 → 2.07" scaling win is **Poisson-only** — and Poisson is exactly where GH-VA
skips quadrature entirely via the closed form. **The Bernoulli half of the same
table runs the other way: Laplace is faster at every binary cell**, and against
`gllvm`'s JJ the tax runs 58× to **159×**. Design 106's header omits that half.

And Design 108 records that **Ayumi has no Poisson columns** — her surface is
gaussian, probit, ordinal probit, lognormal. So the one regime where the old VA
demonstrably wins is not the regime the programme targets. 108's conclusion:
*"Nothing in this programme should be sold on speed."*

Those numbers describe the **old** engine under the joint-optimisation
architecture. This is a different engine. But the comparison is not matched, and
until it is, 108's fence stands.

## 9. Prior art — the mathematics is not new

* **The 1-D collapse** is Ormerod & Wand (2012, *JCGS*), who define the same
  `B(mu, sigma^2)`, note the Poisson closed form, and use adaptive GH for
  Bernoulli-logit. Hui et al. (2017) **explicitly considered and declined** it for
  GLLVMs. `gllvm` 2.0.13's source has zero occurrences of `quadrature`/`hermite`/`ghq`.
* **The closed-form `A_i`** is in Ormerod & Wand's Appendix A.3, Opper &
  Archambeau (2009), and the natural-gradient line (Khan & Lin 2017; Khan & Rue
  2023) — and already in Hui et al. (2017) Step 3 for the probit special case.
* **The envelope-theorem gradient** is textbook (Milgrom & Segal 2002). The
  Laplace-cost side is published (Niku et al. 2019's `O(m^3)` log-det; Margossian
  et al. 2020 on mode-differentiation). No one states the VA-vs-LA comparison in
  this form, but that is framing, not a theorem.
* **`gllvm` does not use a Jaakkola-Jordan bound** — it uses Albert-Chib probit
  augmentation. JJ is the MIRT/GVEM line. gllvmTMB's `va_r3` went further than
  `gllvm` here.

**The one genuinely new step today** is narrow: Stein's lemma lifts the closed-form
`A_i` update **off the JJ bound and onto any family with a 1-D GH expectation** —
dissolving the exact objection on which this route was rejected on 2026-07-27
(*"per-family closed forms do not exist uniformly"*).

**A hard limit to name.** The collapse needs the conditional log-density to depend
on `u_i` through a **single** linear predictor. It does **not** hold for
delta/hurdle/zero-inflated families with two predictors sharing `u_i`, nor for
multinomial. "Works for any family" would be an overstatement.

## 10. Do not claim

* That VGH is more accurate than Laplace. Not measured; §5 explains why the
  likelihood column cannot support it.
* That the 1-D collapse or the closed-form `A_i` is novel. §9.
* Any interval or coverage property. Nothing in gllvmTMB has certified coverage.
* That this reopens VA as an estimator. §8.
* That attenuation is solved. §6 is provisional and unmatched.

## 11. What the evidence actually supports

**Not VA as an estimator.** The recorded freeze was on coverage — VA reaches 4 of
16 families — and speed does not change that.

**VA as a fast approach + Laplace/AGHQ finish.** Run VGH to convergence, take a few
Laplace or AGHQ steps from that point, report the **Laplace MLE with Laplace SEs**.
Every recovery number above then stops applying to the reported estimate. Binomial
is the family where AGHQ works flawlessly (0.0000 stall rate), so the finisher is
strongest exactly where the approach is weakest.

**VA as a screen — the argument Design 108 says survives, and it is not speed.**
*"8 of 20 Laplace fits (40%) diverged to a degenerate loading — off by 2–5 orders
of magnitude — while reporting a clean convergence code and `pdHess = TRUE`."* The
640-cell sweep found the same: 59 of 70 degenerate Laplace fits reported
`convergence = 0`, while VA never reported a clean status on a degenerate fit.
VA's KL-to-prior term is an implicit regulariser, and its health gates label its own
bad fits. **That is the prior/ridge trick already built into the objective.**

**VA for EDA.** The bias is largely a scale effect that preserves the ordination
configuration — the part exploration actually reads. Fences: no `logLik`/`AIC`/`BIC`
(the ELBO is a bound, not a likelihood; Design 85 §10 prohibits selecting `d` by
ELBO), and no intervals.

## 12. Governance items for the maintainer

1. **The do-NOT-do list of 2026-07-28 was written against a record that said the
   scaling wall was "unexplained".** The explanation existed at the time, uncommitted.
   That decision deserves revisiting. Maintainer's call.
2. **"Design 160" does not exist** — cited **eight times** across designs 106, 107
   and 108 as having settled the optimisation architecture. Three of those are
   vetoes aimed at the per-level coordinate-ascent scheme, i.e. at this engine
   (`106:586-588`). It is currently unfalsifiable. Either write the document or
   replace the citations with the actual evidence.
3. **A defect on `main`:** `R/va-r3-proto.R:210` admits Bernoulli (`n_trials >= 1`)
   but `grep -c separation` returns **0** — the guard written to make that widening
   safe never landed.
4. **A defect in what ships:** with large true loadings (`lam_sd = 3`) the Laplace
   default covers **0.023 at n = 1600**. Found only because someone varied the
   loading scale. This is more urgent than anything in this document.
5. **A free, exact lever:** making the `Psi` tier trait-diagonal is exact by Design
   106 Proposition 2 and cuts Ayumi's model from 2,034,669 coordinates to 280,644 —
   *"a 7.25× reduction bought with a proof rather than an assumption."*
