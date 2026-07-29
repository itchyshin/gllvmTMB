# A fast variational route for gllvmTMB — measured, with the claim fenced

**2026-07-29 · Claude · lane `claude/vgh-variational-20260729` · worktree `/private/tmp/gllvmtmb-vgh`**

Status: **RESEARCH PROBE. Nothing promoted, nothing exported, no package file touched.**
All code lives under `dev/vgh/`. Results are LOCAL (D-50).

---

## 1. The question

`gllvm`'s VA is much faster than its LA. In gllvmTMB the ordering is **reversed** —
`dev/three-engine-demo.md` measures, at n=400 Bernoulli q=2:

| arm | point only | point + SE |
|---|---:|---:|
| Laplace | 3.66 s | 5.78 s |
| existing VA (JJ) | **9.65 s** | none available |

Laplace *including standard errors* is faster than the VA engine's bare point estimate.
If VA cannot win on speed there is little reason to carry it, because VA is also *less*
accurate than LA — so speed is the entire case.

## 2. Diagnosis — why the ordering reversed

Not because VA is slow. Because of how the existing prototype is optimised.

`inst/tmb/gllvmTMB_va_r3.cpp` already implements the right ELBO — the one-dimensional
collapse (`v_it = ||L_i' lambda_t||^2`), exact Poisson log-normal, exact gaussian, GH
softplus, and a Jaakkola–Jordan bound. That mathematics is not the problem. The problem is
the **optimisation architecture**:

```r
TMB::MakeADFun(..., random = NULL, ...)      # R/va-r3-proto.R:1059
PARAMETER_MATRIX(m); PARAMETER_MATRIX(log_L_diag); PARAMETER_MATRIX(L_off);
```

Every variational parameter — `N * (2q + q(q-1)/2)` of them — goes into **one flat vector
handed to `nlminb` / L-BFGS-B**. The code's own comment records n=5397, q=2 as
**26,985 variational parameters** in a single quasi-Newton problem. Laplace, meanwhile,
declares `u` as `random` and gets TMB's exact block-diagonal Newton inner solve.

**The VA discards the block structure that Laplace exploits.** That is the whole gap.

## 3. What was built — VGH

`dev/vgh/vgh-engine.R`, pure base R (Golub–Welsch quadrature included), ~330 lines.
Three exact structural facts, each verified rather than asserted:

**(C1) One-dimensional collapse.** Under `q(u_i) = N(a_i, A_i)`, `eta_ij` is univariate
normal with `m_ij = x_i'beta_j + a_i'lambda_j` and `s2_ij = lambda_j' A_i lambda_j`. So the
only intractable term is `B(m,s) = E[b(m + sZ)]` — a **1-D** integral whatever `d` is.
*Not novel; already in the repo. Verified here against 4-dimensional Monte Carlo.*

**(C2) Stein's lemma closes the variance block.** `dB/ds = s·E[b''(m+sZ)]`, so the
stationarity condition for `A_i` is the closed form

```
A_i^{-1} = I_d + Lambda' W_i Lambda,     W_i = diag(E_q[b''(eta_ij)] / phi_j)
```

and the ELBO Hessian in `a_i` is exactly `-A_i^{-1}` — so the Newton step
`a_i <- a_i + A_i g_i` costs nothing beyond `A_i`, which we already have.

**(C3) Every block is a GEMM, and the M-step decouples over responses.** Given the
variational block, the ELBO is a **sum of m independent terms** in `(beta_j, lambda_j)`.
So the M-step is m tiny Fisher-scoring problems of dimension `(p+d)`. The expected
information in `lambda_j` is `sum_i B2_ij (a_i a_i' + A_i)/phi_j = sum_i B2_ij E_q[u_i u_i']`
— the exact Fisher information under q, so this is true Fisher scoring, not a heuristic.

**No optimiser ever sees more than `(p+d)` parameters at once. No AD tape, no
log-determinant derivative, no third derivatives.**

## 4. Validation (`dev/vgh/vgh-validate.R`) — all gated checks pass except one

| check | result |
|---|---|
| GH rule integrates normal moments to k=6 | max err **3.6e-14** |
| **C1** 1-D collapse == d-dim expectation (d=4, vs 4e6 MC draws) | diff **5.4e-05** |
| **C2** Stein `dB/ds = s E[b'']` vs central difference | diff **8.2e-11** |
| **Gaussian exactness**: ELBO == exact marginal loglik | rel **1.26e-12** |
| Monotone ELBO — gaussian / poisson / binomial-logit | all monotone |
| Recovery, gaussian `LL'` rel Frobenius | 0.109 |
| Recovery, poisson `LL'` rel Frobenius, n=250→1000→4000 | 0.112 → 0.062 → 0.031 |

The gaussian check is the strongest: for a gaussian-identity GLLVM the true posterior *is*
Gaussian, so the variational family **contains** it and the ELBO must be tight. It equals
the exact marginal log-likelihood to 1.3e-12. Anything wrong in the ELBO or the KL term
would show up here.

**A real bug this found.** First run, Poisson monotonicity FAILED (min increment −0.43) and
recovery was 0.69. Cause: undamped Newton in `a_i` overshooting through `exp()`. The
contraction condition is sharp — for `d=1` Poisson, `|T'(A)| <= max_j lambda_j^2 / 8`, so
the naive fixed point is guaranteed to contract **only when `|lambda| < 2.83`**. Fixed with
per-unit backtracking along a path that keeps the precision positive definite,
`P(t) = (1-t)P + tP*`; because the variational objective separates over units, every unit
backtracks independently and the search stays vectorised.

**EVA quantified as a Taylor truncation.** EVA replaces `E[b(m+sZ)]` by
`b(m) + (s^2/2)b''(m)`. Its error against exact quadrature, logit cumulant:

| s | 0.25 | 0.5 | 1.0 | 1.5 | 2.0 | 3.0 | 4.0 |
|---|---|---|---|---|---|---|---|
| max\|EVA − exact\| | 6e-05 | 9e-04 | 0.012 | 0.049 | 0.125 | 0.424 | 0.943 |

Negligible for `s <~ 0.5`; unusable by `s = 3`. Note this is exactly the projected-variance
domain the existing gate polices (`max v_it <= 4`).

**GH order needed** (logit cumulant, vs Q=80 reference): Q=15 gives max\|dB\| 2.0e-03,
Q=21 gives 5.5e-04, Q=31 gives 9.7e-05.

## 5. The measured speed result

`dev/vgh/vgh-bench.R`, gaussian, m=20, d=2, against the installed gllvmTMB 0.5.0 Laplace.
Warm-up untimed. **Handicap runs against VGH: interpreted R vs compiled C++ with AD.**

| n | Laplace (s) | VGH (s) | **speedup** | sweeps |
|---:|---:|---:|---:|---:|
| 200 | 7.30 | 0.64 | **11.5×** | 59 |
| 500 | 11.78 | 1.41 | **8.4×** | 59 |
| 1000 | 35.12 | 2.40 | **14.6×** | 53 |

### What this does NOT show — read this before quoting the table

The benchmark also reported VGH attaining a higher exact log-likelihood (+6.2 to +10.0).
**That is not evidence of a better optimum.** Parameter counts differ: Laplace fits **60**
parameters, VGH **79** — per-trait `phi_j` (m of them) against a single shared gaussian
`sigma`. A +6 to +10 gain on 19 extra parameters is roughly what the extra parameters buy
on their own. **The models are not matched, so no equal-accuracy claim is established.**

Consequently the honest reading of the table is: *the timing gap is large and consistent,
and it is not explained by VGH stopping early — but a clean equal-accuracy statement needs
a matched dispersion parameterisation, which has not been run.* n=2000 and n=4000 did not
complete in this session.

## 6. A negative result worth keeping — the exponential-tilting identity

`dev/vgh/tilt-probe.R`. With one covariate profile (the pure-ordination setting, and the
setting of the simulation campaign):

```
log p(y_i | u) = kappa_i + t_i'u - B(u) + c(y_i),
   t_i = Lambda' D_phi^{-1} y_i  in R^d      <- the data enter ONLY here
   B(u) = sum_j b(c_j + lambda_j'u)/phi_j    <- contains no y at all
```

So the data enter each unit's likelihood through only **d numbers**, and
`p(y_i) = exp(kappa_i + c(y_i)) * M_nu(t_i)` — one shared measure's MGF sampled at n points.
Discretise `nu` once and every unit's marginal log-likelihood is **one `(n x d)(d x G)` GEMM
plus a log-sum-exp**: no per-unit mode-finding, no Hessian, no log-determinant, no AD. If
accurate, this is not an approximation to Laplace — it is the **exact** marginal likelihood
computed without Laplace.

**Verified:** the shared-grid GEMM reproduces the per-unit grid computation to **1.4e-13**.
The algebra is right.

**Defeated, at realistic tilts.** Poisson, n=400, m=25, mean count 3.9: the tilt magnitudes
are `||t_i||` **median 29.3, max 510.9**. A tilted measure at `||t|| = 511` concentrates far
outside any fixed shared grid, so the shared-grid rule cannot be accurate there. Widening
the grid (`tau > 1`) with importance reweighting was numerically unstable and, at
`tau = 1.5, 3`, buggy (node-matching fails under floating point). Measured speed advantage
over a vectorised per-unit loop was only 3.2×.

**Verdict: mathematically exact, numerically unusable in this form.** The identity may still
be worth exploiting the *other* way the brainstorm suggested — tabulating the Laplace map,
since `u_hat_i` and `log det(I + Lambda'W Lambda)` are smooth functions of `t_i` alone,
which would accelerate **Laplace itself** and needs no VA. Untested.

## 7. Two findings that belong to other lanes

**(a) The AGHQ stall number may be a stopping-rule artefact — LANE 1 should check this.**
The stall ordering (gaussian 0.8956, poisson 0.7401, binomial 0.0000) is exactly the
ordering of *how exact Laplace already is*. For gaussian-identity the joint log-density is
quadratic in `u`, so **Laplace is exact and AGHQ has nothing to find**:
`l_AGHQ - l_Lap = O(1e-13)`, a relative-improvement test never fires, and the optimiser
reports non-convergence. Binomial is where Laplace is genuinely wrong, AGHQ has real signal,
and the stall rate is 0.0000.

Falsifiable for near-zero cost, over stored fits: **regress the stall indicator on
`|l_AGHQ - l_Lap|` at the Laplace optimum.** If stalls concentrate where that difference is
below the optimiser's `ftol`, the fix is a stopping rule (absolute objective tolerance plus a
gradient-norm test), not an algorithm. This bears on the withheld AGHQ claim.

**(b) A defect on `main`.** `R/va-r3-proto.R:210` admits `n_trials >= 1` (Bernoulli), but
`grep -c separation R/va-r3-proto.R` on `main` returns **0**. The `.va_r3_check_separation()`
guard written specifically to make that widening safe never landed — it lives only on
`claude/va-implementation-20260725`. Sparse binary fixtures routinely produce all-zero trait
columns, i.e. genuine separation, and `glm.fit` reports `converged = TRUE` at `|eta| = 18.57`
on a separated design, so a bare magnitude threshold demonstrably misses it.

## 8. What this does and does not change about the VA decision

The recorded decision is *"Invest in Laplace + AGHQ. Freeze VA where it is"* — taken on
**coverage**, not speed: AGHQ is a refinement layer on the Laplace objective and inherits all
16 families, phylogeny, spatial and missing data; VA reaches 4 of 16 and covered 2 of Ayumi's
27 responses.

**This work changes the speed input to that decision and nothing else.** An infinitely fast
VA still reaches 4 of 16 families. And the coverage limit is structural, not an engineering
gap: as soon as `Cov(u) = Sigma != I` with cross-unit coupling (`phylo_latent`,
`spatial_latent`, `animal_*`), the per-unit factorisation that makes C2 and C3 work dies —
`A^{-1} = Sigma^{-1} + blkdiag(Lambda'W_i Lambda)` becomes an `(nd) x (nd)` object needing
Takahashi selected inversion to get the diagonal blocks. **The design's advantage evaporates
exactly where gllvmTMB differentiates itself from `gllvm`**, and TMB already does that linear
algebra for free in the Laplace route.

**The route that survives all of this** is VA-as-a-preconditioner: run VGH to convergence,
then take a few Laplace/AGHQ outer iterations from the VGH point and report the **Laplace
MLE with Laplace SEs**. The answer is then the Laplace estimate, so the entire VA-bias
literature — and Design 109's finding that a *looser* bound recovered `Sigma_B` better on
20 of 20 paired seeds — becomes irrelevant to the claim. Untested here.

## 9. Prior art — the mathematics is NOT new, and the incumbent's failure mode IS documented

A literature check was run specifically to stop a false novelty claim. Result: **none of the
three ingredients is new.**

- **The 1-D collapse** is Ormerod & Wand (2012, *JCGS* 21(1), 2–17,
  [10.1198/jcgs.2011.09118](https://doi.org/10.1198/jcgs.2011.09118)), who define exactly this
  `B(mu, sigma^2) = int b(sigma x + mu) phi(x) dx`, note the Poisson closed form, use adaptive
  GH for Bernoulli-logit, and already argue the dimension-independence. It is also **explicitly
  considered and declined** for GLLVMs by Hui et al. (2017, *JCGS* 26(1), 35–43): they note the
  logit case "would involve numerical integration" and go the closed-form-augmentation route
  instead. `gllvm` 2.0.13 source contains zero occurrences of `quadrature`/`hermite`/`ghq`.
- **The closed-form `A_i`** is in Ormerod & Wand's Appendix A.3 verbatim, in Opper &
  Archambeau (2009), and in the natural-gradient / Bayesian-learning-rule line (Khan & Lin 2017;
  Khan & Rue 2023). It is already in Hui et al. (2017) Step 3 for the probit special case,
  `A_i = (I_d + sum_j lambda_j lambda_j')^{-1}` — the degenerate case where augmentation makes
  `b''` constant. **Also: `gllvm`'s VA does not use a Jaakkola–Jordan bound** (that is the MIRT
  GVEM line, Cho et al. 2021); it uses Albert–Chib probit augmentation. gllvmTMB's `va_r3` JJ
  branch went further than `gllvm` here.
- **The envelope-theorem gradient** is textbook (Danskin; Milgrom & Segal 2002). The
  Laplace-cost side is published (Niku et al. 2019 give the `O(m^3)` log-det; Margossian et al.
  2020 on mode-differentiation and third derivatives). No one states the VA-vs-LA comparison in
  this form, but that is framing, not a theorem. **Do not claim it as one.**

**What the check DID hand us — independent confirmation of §2.** Korhonen, Nordhausen &
Taskinen (2024, *WIREs Comput. Stat.*, [10.1002/wics.70005](https://doi.org/10.1002/wics.70005)),
Table 4, Poisson-log, p=5 LVs, unstructured `A_i`, median seconds:

| n, m | VA | LA | EVA |
|---|---:|---:|---:|
| 50, 50 | 81.6 | 103.4 | 81.4 |
| **200, 50** | **1610.8** | **486.6** | 1623.7 |
| 200, 150 | 3106.7 | 4136.7 | 3117.5 |

At n=200, m=50, **LA is 3.3× faster than VA in the incumbent package**, and the review names
the cause: the variational parameter count `n·p(p+1)/2` under unstructured `A_i`, where
"the optimization process can get hindered by the swiftly increasing additional parameter
count." That is the same diagnosis as §2, arrived at independently, and it is exactly what
the closed-form `A_i` fixed point removes.

**The defensible position, conservatively phrased.** Not "a new variational method." Rather:
*an exact-ELBO variational approximation for GLLVMs, obtained by applying Ormerod & Wand's
one-dimensional quadrature collapse to the factor-loading structure with the
Opper–Archambeau fixed point for `A_i`* — contributing (i) restoration of the lower-bound
property that EVA gives up, (ii) coverage of families where `gllvm` must fall back to EVA or
LA (binomial logit/cloglog, Tweedie, beta, ordinal-logit), and (iii) removal of `A_i` from the
outer parameter vector, the documented cause of the timing collapse above. Korhonen et al.
(2023) list "the effect of using higher order Taylor expansions could be explored" in their
Discussion — a quotable motivation.

**A hard limit that must be named.** The 1-D collapse requires the conditional log-density to
depend on `u_i` through a **single** linear predictor. It does **not** hold for
delta / hurdle / zero-inflated families with two linear predictors sharing `u_i`, where
`(eta1_ij, eta2_ij)` is bivariate normal under q and a 2-D quadrature is needed. gllvmTMB
carries delta and hurdle families, so "works for any family" would be an overstatement.

## 10. Do not claim

- That VGH is more accurate than Laplace. Not measured; §5 explains why the likelihood
  column cannot support it.
- That the 1-D collapse or the closed-form `A_i` is novel. Both are in the literature and
  the collapse is already in `inst/tmb/gllvmTMB_va_r3.cpp`. What is new here is the
  **optimisation architecture**, and even that needs a prior-art check.
- Any interval or coverage property. Nothing in gllvmTMB has certified coverage.
- That this reopens VA. It does not; §8.
