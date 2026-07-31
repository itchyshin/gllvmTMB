# Are we using gllvm's EVA incorrectly? — a misuse probe

**Date:** 2026-07-31
**Agent:** Gauss (numerical-correctness specialist)
**Worktree:** `/private/tmp/gllvmtmb-va-in-06` (read-only against `dev/totoro-grid/`; all new
code under `dev/eva-probe/`)
**Package under test:** `gllvm` 2.0.13 (`/Users/z3437171/Library/R/arm64/4.6/library/gllvm`)
**Prior:** default to "we are at fault". The evidence had to overcome that, and on the
central question it did.

---

## 0. Verdict

**GENUINE METHOD BEHAVIOUR.** The gllvm EVA fit for Bernoulli–logit converges to a
*degenerate mode that its own objective genuinely prefers to the truth*. The
reconstruction line in `run-grid.R:109-110` is byte-identical to gllvm's own
`getLoadings()` extractor; the link is live and correct; `num.lv` and the intercept
structure match the DGP; and no starting-value or restart setting escapes the mode —
restarts make it **worse**, because gllvm selects the restart with the best EVA objective
and the degenerate mode *has* the best EVA objective.

Two secondary findings **are** ours, and both are reporting defects rather than
measurement defects:

1. We discarded gllvm's own degeneracy signal (`fit$sd` collapses to the scalar `FALSE`
   on these fits) and never flagged it.
2. `median(attenuation) = 4.8e7` is a mixture statistic over a **bimodal** distribution.
   It is arithmetically correct and it is not a "point-estimate error of 7 orders of
   magnitude" — it is a 67.7 % degenerate-mode rate crossed with an otherwise-ordinary
   estimator. Reporting it as a single accuracy number conflates the two.

---

## 1. What was recomputed

Everything cited below I computed in this session. The DGP was copied verbatim from
`dev/totoro-grid/run-grid.R:49-58` (bernoulli branch) into
`dev/eva-probe/common.R`, so the data are comparable cell-for-cell.

Baseline re-derived from `dev/totoro-grid/results/grid.csv` (2880 rows):

| arm (bernoulli) | finite rows | median attenuation | max | % with attenuation > 10 |
|---|---:|---:|---:|---:|
| `gllvm_eva` | 300 | **4.819e+07** | 5.452e+09 | **67.7 %** (203/300) |
| `gllvm_va` | 300 | 0.9159 | 3.129 | 0.0 % |
| `gtmb_jj` | 320 | 0.9477 | 3.135 | 0.0 % |
| `gtmb_gh` | 320 | 1.460 | 15.14 | 0.9 % |
| `gtmb_laplace` | 281 | 1.226 | 1.524e+06 | 24.9 % |

The 203 count in the brief is exactly the `attenuation > 10` count. `gllvm_eva` also has
20 hard ERROR rows (all "Calculating starting values failed") and 43 `not_converged`; the
degeneracy is **not** explained by non-convergence — restricted to the 257 rows gllvm
itself labels `converged`, the median attenuation is still **7.62e+06** and 164/257 exceed
2.

The poisson `gllvm_eva` rows are all honest ERROR rows
("poisson not implemented with method 'EVA'"); there is no silent fallback. The whole
phenomenon is a Bernoulli phenomenon.

---

## 2. Hypothesis 1 — the `Sigma_B` reconstruction. **REFUTED.**

`run-grid.R:109-110` does `as.matrix(theta) %*% diag(sigma.lv, q, q)`.

gllvm's own extractor `gllvm:::getLoadings.gllvm` does:

```r
sploads <- object$params$theta
sploads[, (ncol-num.lv+1):ncol] <- sploads[, (ncol-num.lv+1):ncol] %*%
                                     diag(tail(object$params$sigma.lv, object$num.lv))
```

For a plain `num.lv`-only model (`num.lv.c = 0`, `num.RR = 0`, `quadratic = FALSE` — all
true here, verified on the fitted object) these are the same operation. Measured on the
worst reproduced cell:

```
grid-line vs getLoadings identical:  TRUE   (method = VA)
grid-line vs getLoadings identical:  TRUE   (method = EVA)
```

**The reconstruction is EVA-agnostic and it is gllvm's own.** EVA does *not* return
`theta`/`sigma.lv` on a different scale or normalisation — the same extractor is used by
gllvm for both, with no method branch anywhere in `getLoadings.gllvm` or
`getResidualCov.gllvm`.

I also checked the *target*. `gllvm::getResidualCov()` returns `LLᵀ + (π²/3)·I` — the
diagonal addition measured as `3.2898681` against `π²/3 = 3.2898681`, with zero
off-diagonal difference. That extra term is the link-implicit logistic residual variance,
which our DGP's `Sig_true = Lt Ltᵀ` does not contain. So `run-grid.R`'s choice of `LLᵀ`
(not `getResidualCov`) is the **correct** like-for-like comparator. The metric is right.

---

## 3. Hypothesis 3 — the family/link path. **REFUTED. The link is live.**

`gllvm::gllvm` contains, in the family-object branch:

```r
if (inherits(family, "family")) { link <- family$link; family <- family$family }
```

so `family = binomial()` sets `link <- "logit"` unconditionally, *before* any
method dispatch. Verified three ways on the same cell:

| call | recorded `fit$link` | logL | attenuation |
|---|---|---:|---:|
| `family = binomial()`, EVA | `logit` | -327.404 | 8.814e+08 |
| `family = "binomial", link = "logit"`, EVA | `logit` | -327.404 | 8.814e+08 |
| `family = "binomial", link = "probit"`, EVA | — | *fails*: "Algorithm converged to infinity" | — |

The first two are identical to the last printed digit; the probit path diverges into a
hard failure. **The link is not a no-op for EVA** — changing it changes the fit
qualitatively. There is no silent probit fallback on our logit-generated data.

(Note for the record: gllvm's `?gllvm` documents the top-level `link=` as applying to
"binomial family if `method = "LA"` and beta family". That documented restriction is what
produced the earlier "silent no-op" finding in this lane. It does **not** apply when the
link is carried in on a `family` object, which is the route `run-grid.R` uses. Our usage
is on the safe side of that trap.)

**Bonus verification that settles the sister worry.** `gllvm`'s `vignette1.Rmd` family
table lists Bernoulli-logit as `EVA/LA` only, implying `method="VA"` might not really be
VA for our arm. It is. I reconstructed the Jaakkola–Jordan / Pólya-Gamma bound
independently and evaluated it at gllvm's VA solution:

```
gllvm's reported VA logL      = -478.54886
my independent JJ bound value = -478.54886      (exact to 5 dp)
my EVA surrogate at same point = -467.50189      (different)
```

So `gllvm_va` really is the JJ bound, `gllvm_eva` really is the Taylor surrogate, and the
grid's arm labels are honest.

---

## 4. Hypothesis 4 — `num.lv` semantics and row effects. **REFUTED.**

On the fitted object: `num.lv = 4`, `num.lv.c = 0`, `num.RR = 0`, `row.eff = FALSE`,
`dim(theta) = 20 x 4` (= p x q), `params = (theta, sigma.lv, beta0)` with
`length(beta0) = p`, `dim(lvs) = 40 x 4` (= n x q). gllvm's LVs are standard normal with
scale carried by `sigma.lv`; our DGP draws `u ~ N(0, I_q)` and puts the scale in `Lt`.
The fitted model is exactly the generating model: `eta_ij = beta0_j + u_i' lam_j`. No row
effect, no extra intercept structure, correct `y` orientation (n x p). Nothing here.

---

## 5. Hypothesis 2 — starting values and restarts. **REFUTED, and the sign is backwards.**

Cell `n=40, p=20, q=4, seed=7`, `method="EVA"`, all else default:

| variant | EVA logL | converged | attenuation | max abs sigma.lv |
|---|---:|---|---:|---:|
| default (`starting.val="res"`, `n.init=1`) | -327.404 | FALSE | 8.814e+08 | 1.92e+03 |
| `n.init = 5` | **-312.481** | FALSE | **9.207e+08** | 2.08e+03 |
| `n.init = 10` | -312.481 | FALSE | 9.207e+08 | 2.08e+03 |
| `starting.val = "zero"` | **-309.352** | FALSE | 6.399e+08 | 1.25e+03 |
| `starting.val = "random"`, `n.init = 5` | -360.119 | **TRUE** | 8.552e+08 | 81.6 |
| **`start.lvs = ` the TRUE latent variables** | -329.001 | FALSE | **1.508e+09** | 242 |
| `max.iter = maxit = 50000` | -327.356 | **TRUE** | 3.364e+08 | 2.11e+03 |
| `control.va$Lambda.start = 1.0` | -312.088 | FALSE | **1.239e+09** | 1.28e+03 |
| `control.va$Lambda.start = 2.0` | -326.553 | FALSE | 1.895e+09 | 1.89e+03 |
| `control.va$Lambda.struc = "diagonal"` | -328.469 | FALSE | 8.949e+08 | 1.44e+03 |
| `control.va$diag.iter = 0` | -313.712 | FALSE | **5.338e+10** | 6.75e+02 |
| `control.start$start.struc = "all"` | -327.404 | FALSE | 8.814e+08 | 1.92e+03 |
| **VA reference (same data)** | **-478.549** | **TRUE** | **1.639** | **1.79** |

Three things to read off this table.

**(a) Handing EVA the true answer does not save it.** `start.lvs = u`, the actual latent
variables that generated the data, still lands at attenuation **1.508e+09** — the worst
result of the whole set. A method that walks away from the truth when placed on it is not
suffering from bad starting values.

**(b) The degenerate mode is reachable *with* `convergence = TRUE`.** Two variants
(`starting.val="random", n.init=5` and `max.iter=50000`) converge cleanly at attenuation
8.55e+08 and 3.36e+08. This kills the reading that the catastrophe is merely unflagged
non-convergence — and it matches `grid.csv`, where the 257 rows gllvm labels `converged`
still have median attenuation 7.62e+06.

**(c) Better objective, worse estimate.** `n.init = 5` buys 15 nats of EVA objective and
4 % more attenuation. `diag.iter = 0` buys 14 nats and multiplies attenuation by 60. This
is the signature of an estimator faithfully optimising a defective objective, not of an
optimiser that is failing. It also explains why restarts cannot be the fix *in principle*:
gllvm selects among `n.init` restarts by the EVA objective, and the degenerate mode
maximises it. Adding restarts is a more thorough search for the wrong optimum.

---

## 6. The crux (brief item 5) — is the fit degenerate, or only the derived quantity?

**The fit itself.** Raw parameters, same cell, same data, VA vs EVA:

| | VA | EVA |
|---|---:|---:|
| `logL` (own objective) | -478.549 | -327.404 |
| convergence | TRUE | FALSE |
| `sigma.lv` | 1.795, 0.851, 1.029, 0.463 | **1915.7, 1.10, 1390.8, 1020.2** |
| max abs `theta` | 2.99 | **1153.7** |
| range `beta0` | -0.82 .. 1.69 | -0.65 .. **547.0** |
| range `lvs` | -1.98 .. 1.85 | -1.46 .. 1.69 |
| max abs fitted `eta` | 4.82 | **44 447** |
| mean abs fitted `eta` (true = 0.910) | 1.167 | **964.3** |
| `fit$sd` | list(theta, sigma.lv, beta0), all finite | the scalar `FALSE` |

Note `lvs` stays O(1) in **both** fits. The blow-up is entirely in the loadings, the LV
scales, and the intercepts. `Sigma_B` is absurd because the *parameters* are absurd. This
is not a reconstruction artefact; there is nothing to repair downstream.

One further nail in hypothesis 1: **which factor carries the blow-up varies.** In the cell
above it is mostly `sigma.lv` (1915.7) with `theta` at 1153.7. In cell
`n=40, p=20, q=4, seed=1` it is the reverse — `max abs theta = 7.53e+03` with
`max abs sigma.lv = 0.38`. Any hypothesis in which EVA normalises `theta` and `sigma.lv`
differently from VA would predict a consistent direction. It is their *product* that is
degenerate, which is exactly what `Lambda Lambda^T` is a function of, and exactly what
`getLoadings()` returns.

---

## 7. Mechanism — why the EVA objective prefers this

I reconstructed the EVA surrogate for Bernoulli–logit
(Korhonen, Nikula & Hui form; the functional form is **AGENT-INFERRED**):

```
EVA(Lam, b0, M, A) = sum_ij [ y_ij*eta_ij - log(1+exp(eta_ij)) - 0.5*b''(eta_ij)*V_ij ]
                     + sum_i [ 0.5*log|A_i| - 0.5*tr(A_i) ] - 0.5*sum(M^2) + n*q/2
    eta_ij = b0_j + m_i' lam_j ,  V_ij = lam_j' A_i lam_j ,  b''(x) = s(x)(1 - s(x))
```

**It is validated, not assumed:** evaluated at gllvm's own returned EVA solution it gives
**-327.38162** against gllvm's reported **-327.40432** (difference 0.023, ~7e-5 relative).
The companion JJ reconstruction reproduces gllvm's VA logL exactly (§3). So the surrogate
below is gllvm's, to within round-off.

**The decisive comparison.** All three points evaluated under the *same* EVA objective,
same data:

| point | EVA objective | attenuation |
|---|---:|---:|
| gllvm's runaway EVA solution | **-327.38** | 8.814e+08 |
| the VA solution | -467.50 | 1.64 |
| **the true parameters** (`Lam = Lt`, `M = u`) | **-618.56** | **1.00** |

The degenerate solution beats the truth by **291 nats** under EVA's own objective. Under
the JJ bound the ordering reverses completely: -4 821 926 at the runaway point versus
-478.55 at the VA solution and -630.39 at the truth. **VA rejects the runaway; EVA
rewards it.**

**Why.** The only term in EVA that penalises a large latent variance is
`0.5*b''(eta)*V`, and `b''(eta) = s(eta)(1-s(eta))` decays like `exp(-|eta|)`. Scanning a
ray that scales the fitted loadings and intercepts by `s` (variational `M`, `A` held
fixed):

| s | EVA objective | data term | **variance penalty** | attenuation |
|---:|---:|---:|---:|---:|
| 1e-4 | -1 531.7 | -531.7 | 958.4 | 8.81 |
| 1e-2 | -4 610 057 | -425.5 | 4.61e+06 | 8.81e+04 |
| 0.1 | -48 139 448 | -349.7 | **4.81e+07** | 8.81e+06 |
| 0.3 | -737 819 | -314.4 | 7.37e+05 | 7.93e+07 |
| **1** | **-327.4** | -261.1 | **24.7** | 8.81e+08 |
| 3 | -425.2 | -289.7 | 93.9 | 7.93e+09 |
| 100 | -11 513 | -6 764.6 | 4 707 | 8.81e+12 |

The penalty is **non-monotone**: it rises to 4.8e7 and then *collapses to 24.7*. Once
`|eta|` is large enough that every observation is saturated, the second-order Taylor
penalty evaluates to essentially zero **even though the latent variance it is meant to
price is of order 1e9**. The objective has a barrier the optimiser can tunnel through, and
a spurious mode on the far side that is better than the truth. A ray from the truth
outward (not shown in full, computed in `dev/eva-probe/p4b-objective.R`) decreases
monotonically from -587.4 at `s=0.5` to -148 620 at `s=1000` — confirming the runaway is a
genuinely *separated* second mode, not the tail of a monotone ramp.

This is the classic separation pathology, with the EVA-specific twist that the Taylor
surrogate becomes vacuous exactly in the region where it is most needed. It is structural.
No `gllvm` argument bounds it.

**Regime dependence — the failure is not uniform.** Fraction of `gllvm_eva` bernoulli
fits with attenuation > 10, from `grid.csv`:

| p \ q | 2 | 4 |
|---|---:|---:|
| 8 | 1.000 | 1.000 |
| 20 | 0.825 | 1.000 |
| 40 | 0.100 | 0.933 |
| 80 | 0.150 | 0.325 |

EVA holds together when there are many traits per latent dimension and breaks when the
model is flexible relative to the binary information available. Even in its best regime
(`p >= 40, q = 2`) it degenerates in 12.9 % of cells with a max of 8.5e8; `gllvm_va` on the
identical subset has median 1.045 and max 2.49.

---

## 8. Where we *are* at fault

Stated plainly, because the prior was that we would be.

1. **We threw away gllvm's own alarm.** On these fits `fit$sd` is not a list of standard
   errors but the scalar `FALSE`, and gllvm prints "Standard errors for parameters could
   not be calculated, due to singular fit" / "Hessian calculation produced na/nan's".
   `run-grid.R:82` muffles every warning and the harness never records `fit$sd`.

   `is.list(fit$sd)` is a **clean, cheap degeneracy flag**, and it is not simply "EVA
   always fails" — it tracks the mode, and it fires where `convergence` does not:

   | cell | method | attenuation | `convergence` | `is.list(fit$sd)` |
   |---|---|---:|---|---|
   | n200 p40 q2 s1 | EVA | 1.030 | TRUE | **TRUE** |
   | n100 p80 q2 s1 | EVA | 1.426 | TRUE | **TRUE** |
   | n200 p80 q2 s2 | EVA | 1.105 | TRUE | **TRUE** |
   | **n40 p8 q2 s1** | **EVA** | **1.229e+07** | **TRUE** | **FALSE** |
   | n40 p20 q4 s7 | EVA | 8.814e+08 | FALSE | **FALSE** |
   | (all five) | VA | 0.85 - 1.74 | TRUE | TRUE |

   Note row 4: gllvm reports `convergence = TRUE` on a fit with attenuation 1.2e+07, and
   `sd` still catches it. The harness's `status` column (built from `convergence` alone)
   is therefore the wrong guard, which is why 257 `converged` rows in `grid.csv` carry a
   median attenuation of 7.62e+06.
2. **`median(attenuation)` is the wrong summary for a bimodal arm.** Split at
   `attenuation > 10`: the degenerate mode is 67.7 % of finite `gllvm_eva` rows, and the
   remaining 32.3 % have **median attenuation 1.2111** — squarely comparable to
   `gtmb_laplace` (1.10) and `gtmb_gh` (1.45). Reporting one median silently multiplies a
   *failure rate* by an *accuracy*, and then presents the product as an accuracy.
3. **Minor framing.** `?gllvm` describes EVA as for use "when VA is not applicable", and
   VA *is* applicable for Bernoulli–logit (verified: `gllvm:::gllvmFML_allowed` permits
   `binomial|VA|logit`, and §3 confirms it really runs the JJ bound). gllvm's
   `vignette1.Rmd` family table contradicts this by listing Bernoulli-logit as `EVA/LA`
   only. The two gllvm sources disagree; we followed neither deliberately. Worth one
   sentence of qualification in any write-up, but it does not soften the finding — EVA is
   a *documented, permitted* option here, and it fails.

None of these change the point estimates. They change how the numbers should be reported.

---

## 9. Corrected numbers

There is **no usage fix**. Nine settings were tried (§5) and every one stayed in the
degenerate mode; the better ones went further into it. The corrected reporting is:

| statistic | as recorded | corrected framing |
|---|---:|---|
| `gllvm_eva` bernoulli median attenuation | 4.819e+07 | keep, but label it a **mixture over a bimodal arm**, not an accuracy |
| degenerate-mode rate | not reported | **67.7 %** (203/300 finite rows; `attenuation > 10`) |
| median attenuation, non-degenerate fits only | not reported | **1.2111** |
| hard-failure rate | 20 ERROR rows | 20/320 starting-value failures (6.3 %) |
| gllvm's own degeneracy flag | discarded | `fit$sd` is `FALSE` (not a list) on degenerate fits |

So the honest one-line replacement for "median attenuation 4.8e7" is:

> On Bernoulli data, gllvm's EVA converges to a scale-degenerate mode in **67.7 %** of
> cells (rising to 100 % at `p = 8` and falling to 10 % at `p = 40, q = 2`); on the
> remaining fits its median attenuation is **1.21**, comparable to Laplace. The degenerate
> mode is preferred by EVA's own objective — at the reproduced worst cell it beats the
> true parameters by 291 nats — so restarts do not escape it and no `gllvm` setting
> bounds it.

The literature's "competitive with VA and Laplace" claim and this result are not in
contradiction over *point estimates* in the regimes where EVA holds (`p >= 40`,
`median attenuation 1.25-1.31`). They are in contradiction over the **degenerate-mode
rate**, which our design exposes and which is the thing worth reporting. And the brief's
instruction stands vindicated: the "uncertainty for `B` but not `Lambda Lambda^T`" quote
does **not** explain any of this — the defect is in the point estimate and in the
objective that produces it.

---

## 10. Limitations

- Reproduction was on macOS/arm64 R 4.6, single-threaded BLAS; `grid.csv` was produced on
  Totoro/Linux. The worst cell (`n=40, p=20, q=4, seed=7`) recorded attenuation
  **4.459e+09 / converged** there and **8.814e+08 / not-converged** here. Same phenomenon,
  same order-of-magnitude class, different exact optimiser trajectory. Every number in
  §§2-7 is from this machine; every number in §§1, 7-9 tagged "from `grid.csv`" is from
  the recorded run.
- The EVA objective's functional form is **AGENT-INFERRED** from the standard EVA
  construction, not read out of gllvm's C++ source. It is validated numerically against
  gllvm's own reported `logL` at gllvm's own solution to 7e-5 relative, and its JJ sibling
  matches gllvm's VA `logL` exactly, so I treat it as verified for the purpose it is used
  for. It is **not** a claim about gllvm's internal implementation details.
- Four cells were probed for starting values (`n=40 p=20 q=4 s7` completely; three others
  in progress at write time). The regime table in §7 is from the full 300-row recorded
  grid, which is the broader evidence.
- I did not read the EVA source paper. The framing of "what the literature claims" is
  taken from the brief, not independently checked.

## 11. Artefacts

All under `/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/`:

- `common.R` — verbatim DGP copy from `run-grid.R:49-58`
- `p1-anatomy.R` / `p1.rds` — VA vs EVA fit anatomy, three reconstructions compared
- `p2-link-anchor.R` — link-liveness anchor
- `p3-starts.R` / `p3.log` — starting values and restarts
- `p4b-objective.R` — validated EVA/JJ objective reconstruction and the scaling rays
- `p5-knobs.R` / `p5.log` — `control.va` / `control.start` / optimiser knobs

Nothing in `R/`, `src/`, or `dev/totoro-grid/` was modified.
