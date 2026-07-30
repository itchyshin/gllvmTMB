# The gaussian collapse test — the log-likelihood gap was degrees of freedom

Date: 2026-07-30. Author: Claude. Lane: `claude/vgh-pluralism-20260730`.
Evidence: `dev/vgh/gaussian-collapse.{R,csv}`, analysis `dev/vgh/gaussian-collapse-analyse.R`.
Design: T = 20 traits, d = 2, n ∈ {200, 800}, **12 paired seeds each = 24 cells**, homoscedastic
gaussian truth. Every arm in a cell fits the identical dataset. Laplace multi-started
(`n_init = 5`).

## The question

`dev/vgh/vgh-bench-gaussian.csv` recorded VGH attaining a higher exact marginal
log-likelihood than Laplace — `d_ll` from +6.23 to +12.31 across n = 200…4000. The
2026-07-29 documents correctly called this *"not evidence of a better optimum"* and *"roughly
what the extra parameters buy"*, because VGH fits per-trait `phi_j` (79 parameters) against
Laplace's single shared `sigma_eps` (60). **This run turns "roughly" into a measurement, and
tests the claim two independent ways.**

## Integrity gates — nothing below is interpretable without these

| gate | result |
|---|---|
| yardstick: `max abs(exact_ll(laplace) − logLik(laplace))` | **2.0e-10** |
| parameter counts matched (Laplace == pooled VGH) | **24 of 24** |
| pooled `phi` genuinely flat across traits | **24 of 24** |
| VGH cells hitting the sweep cap | **0** |
| Laplace non-convergences | **0** |

The yardstick matters more than it looks. An adversarial review flagged that comparing
`stats::logLik(laplace)` against a locally-computed `exact_ll(vgh)` would be **fatally
invalid** if the two carried different additive constants. So every arm is scored by the *same*
local `exact_ll()`, and that function is checked against `stats::logLik()` in every cell rather
than assumed equivalent. It agrees to 2e-10.

## Result A — the gap collapses when the parameterisations match

| n | cells | median `d_ll` unpooled | median \|`d_ll`\| pooled | max \|`d_ll`\| pooled | collapse factor |
|---|---|---|---|---|---|
| 200 | 12 | 9.354 | 5.3e-08 | 2.1e-07 | **4.4e+07×** |
| 800 | 12 | 9.964 | 4.4e-07 | 8.3e-07 | **1.2e+07×** |

Overall max \|`d_ll` pooled\| = **8.3e-07**, against a median unpooled gap of **9.96**. Pool
VGH's dispersion to one shared estimated value — matching Laplace at 60 free parameters — and
the entire log-likelihood advantage disappears into optimiser tolerance.

**And the two matched arms agree on the estimates, not merely on the objective:**

| quantity | Laplace | pooled VGH | max abs difference |
|---|---|---|---|
| `rel_frob` vs known truth | 0.1130 | 0.1130 | 5.8e-05 |
| residual SD | 0.9971 | 0.9971 | 1.9e-06 |
| `Sigma_B` relative Frobenius difference | — | — | median 5.2e-05, max 7.9e-05 |

Recovery against truth is **identical to four decimal places in both arms**. This is what
"same objective, same MLE" looks like when you actually measure it, and it is simultaneously
the **cross-implementation check of the TMB gaussian path** that the settled-position note
names as VGH's one unexploited use — *"a genuinely independent implementation of the same
likelihood … a software test, not a statistical instrument."* A pure-R reimplementation
reproduces the compiled C++ template's gaussian estimates to ~5e-05 relative.

**That 5e-05 is the RESOLUTION of the check, not a measured discrepancy.** The objective is flat
here: a relative `Σ_B` perturbation of 1.4e-05 costs only 2.1e-07 in log-likelihood — the size
of the residual gap itself — so **a genuine template discrepancy below roughly 1e-05 to 5e-05
relative would be invisible to this design.** The check is real but its sensitivity is bounded,
and the scope is narrow: intercept-only, loadings-only, no ψ, no covariates, no missing data.
Do not quote it as "the template is correct to 5e-05"; it is "this design could not have seen an
error larger than that."

### One systematic detail — measured, after my first explanation of it was wrong

The residual pooled gap is **negative in 24 of 24 cells**. My original reading was that VGH
reached the slightly worse optimum, with the sign attributed to optimiser asymmetry, and I
deferred settling it "pending a multi-start VGH". **An adversarial pass showed that was
unnecessary and directionally wrong.**

What it actually is: a **stopping-tolerance artifact**, and the direction is set by whichever
tolerance is looser. `|d_ll_pooled|` measures **0.17–3.46×** (median 1.56×) VGH's own stopping
threshold `1e-11·(|ELBO|+1)`, and monotone ascent halted one step short always lands *below*
— so the sign is forced by the threshold, not by the engine. The decisive test takes seconds:
**re-run the pooled arm at `tol = 1e-14` and the sign reverses in 24 of 24 cells** (VGH then
sits *above* Laplace by ≤4.3e-07). Meanwhile Laplace's five restarts buy it at most **2.5e-07**
over `n_init = 1` — the same order as the gap, so the restart asymmetry cannot manufacture a
24/24 pattern either.

**So the residual is the joint numerical floor of the two optimisers, and it is not a VGH ELBO
or M-step bias.** If anything, once VGH is tightened it is *Laplace* that sits a hair short.

Two further objections were also closed empirically rather than deferred:

- **The collapse is not inherited from the shared init.** VGH's start is a deterministic
  eigendecomposition of the residual covariance, which raised the possibility that agreement
  came from the starting point rather than from reaching a common optimum. Run from **8 random
  starts per cell** across all 12 n=200 seeds (`Beta ~ N(0,3)`, Λ scale `U(0.05,3)`, random
  `amean`, `φ ~ U(0.2,5)`), the attained `exact_ll` spread is **7.3e-11 to 5.1e-10**, and no
  random start ever beat the default by more than 3e-10.
- **The pooled update is the exact constrained maximiser, not merely a fixed point of a
  modified algorithm.** Setting `dELBO/dφ = 0` under `φ_1 = … = φ_T` gives
  `φ = mean_ij[(Y−M)² + S2]`, which is literally `vgh_update_phi(..., pool = TRUE)`
  (`dev/vgh/vgh-engine.R:344-348`). Had it not been, the collapse would have been a coincidence.

## Result B — the unpooled gap is what 19 parameters buy, distributionally

Laplace's model is VGH's under `phi_1 = … = phi_T`, so the two are strictly **nested**. The DGP
is homoscedastic by construction, so the constraint is **true**. Both log-likelihoods are
exact. Therefore `2·d_ll` is a likelihood-ratio statistic distributed `χ²₁₉`.

The df is 19 and not 20: effective loading dof is 39 on both sides — Laplace constrains the
strict upper triangle (`src/gllvmTMB.cpp:875-899`), VGH is unconstrained at 40 raw but only 39
identified, the likelihood being exactly flat in the remaining rotational direction. Confirmed
empirically by the S0 gate (Laplace 60 = 20 + 39 + 1; VGH 79 = 20 + 39 + 20).

| n | observed mean `d_ll` | observed sd | null predicts | cells p < 0.05 | KS vs χ²₁₉ | t-test vs 9.5 |
|---|---|---|---|---|---|---|
| 200 | **9.396** | 2.435 | mean 9.5, sd 3.082 | **0 of 12** | D = 0.173, **p = 0.810** | **p = 0.885** |
| 800 | **9.268** | 2.562 | mean 9.5, sd 3.082 | **0 of 12** | D = 0.153, **p = 0.901** | **p = 0.760** |

The **whole distribution** of `2·d_ll` is indistinguishable from `χ²₁₉` at both sample sizes,
not merely the mean. This is the evidence the adversarial review said was missing: the original
five bench cells were single draws, and `sim()` there redrew `Lambda` and `beta` at every n, so
they were five draws from five *different* truths.

**This BOUNDS a residual advantage; it does not exclude one.** A second adversarial pass
quantified the design's power, and the honest reading is weaker than "confirmed":

- At 12 cells the **80%-power MDE is 2.74 log-likelihood units** (5.47 on the `2·d_ll` scale);
  pooling all cells, 1.84. KS power against a `+3` shift in `2·d_ll` is only **0.32** at k=12.
  So a genuine VGH advantage of up to ~29% of the measured 9.4 gap would pass unnoticed.
- **χ²₂₀ also fits these data** (KS p = 0.256; t-test against its mean p = 0.194). So the
  df = 19 rests on the **parameter-count argument**, not on this measurement — the data cannot
  distinguish 19 from 20. The count itself is solid (`np_vgh_unpool − np_laplace = 19` in all 24
  CSV rows, and `src/gllvmTMB.cpp:884-885` fixes the loading dof at 39 on both sides), and the
  conclusion is unchanged at either df, but the measurement corroborates the *magnitude*, not
  the df.
- **The 24 cells carry only 12 truths.** `sim_cell()` seeds on `20260730 + 977*seed` with **no n
  dependence** (`gaussian-collapse.R:69`), so each seed's Λ and `b0` are *identical* at n=200
  and n=800; `cor(d_ll)` across n = 0.197. A design defect in my script. "0 of 24 cells" and the
  pooled statistics therefore overstate independence.
- One hole the original write-up did not address, now closed: **the unpooled arm really is at
  its unconstrained maximum** — multi-start plus `tol = 1e-14` improves `ll_vgh_unpooled` by at
  most 2.5e-07 across all 12 n=200 cells. So the mean's 0.34 shortfall from 19 is sampling
  noise, not an optimiser deficit.

**The n-trend corollary below, by contrast, is well powered and survives strongly.**

### A corollary that kills the apparent n-trend

The bench's `d_ll` appeared to grow with n — 6.23, 6.67, 9.99, 11.96, 12.31. Under a nested
null the statistic's distribution **does not depend on n**, so that trend should not exist.
With a proper replicated design it does not: the mean is **9.396 at n = 200 and 9.268 at
n = 800** — flat, and if anything very slightly lower at the larger n.

**So the apparent growth was an artifact of redrawing the truth at every n**, exactly as
suspected. Nothing should be read into it.

**And here the shared-truths design defect flagged above turns into an advantage.** Because
each seed's Λ and `b0` are identical at n=200 and n=800, the two blocks are **paired**, which is
the more powerful comparison. Paired over the 12 shared truths: mean difference **−0.128**,
p = 0.892, `sd(diff)` = 3.168, paired MDE 2.81 — and **power 0.962** against the bench's own
+3.76 growth from n=200 to n=800. So this design does not merely fail to detect the trend; it
**excludes** it. Unlike the χ² comparison above, this corollary is well powered.

## Timing — recorded, but not a benchmark

| n | Laplace (5 restarts) | pooled VGH | unpooled VGH |
|---|---|---|---|
| 200 | 21.92 s | 0.21 s | 0.22 s |
| 800 | 126.47 s | 0.53 s | 0.54 s |

**Do not quote these as a speed comparison.** Laplace runs five restarts to VGH's one, so
per-fit Laplace is ~4.4 s and ~25 s; the machine was concurrently running other jobs; and the
standing caveat applies — this is interpreted R against compiled C++ with AD, and the speed
advantage is regime-specific (large m, large n) and reverses at small binomial problems, where
VGH is ~20–25% *slower*.

## What this establishes, and what it does not

**Established.** On gaussian, the reported log-likelihood advantage of VGH over Laplace is
**degrees of freedom, not accuracy**. Matched at 60 parameters the two engines return the same
fit to ~5e-05, recover truth identically, and agree on the residual SD to 2e-06. The
same-objective claim in `dev/vgh/vgh-bench.R:3` is confirmed by direct measurement.

**Not established.** That the two engines are *exactly* equivalent — a high p-value is absence
of evidence against the null, not proof of it. Nor that VGH's optimiser is as good as Laplace's:
the 24/24 negative sign says it is uniformly a hair worse, at a magnitude consistent with
tolerance rather than bias, and separating those needs a multi-start VGH.

**Scope.** All of this is gaussian, T = 20, d = 2, homoscedastic, n ∈ {200, 800}. Nothing here
transfers to binomial or Poisson, where the variational bound is *loose* and the engines
genuinely differ — that is where the measured 0/148-vs-50/148 degeneracy gap lives, and it
stands untouched.

## Limitations

- **VGH is single-start** and cannot be multi-started without editing the engine. This is the
  one live thread from the adversarial review that remains open.
- **12 seeds per cell.** Enough for the distributional tests above; not enough to resolve the
  ~1e-7 systematic sign.
- **Two n values, one T, one d, one heteroscedasticity level (none).** The heteroscedastic cells
  were cut when the arc was re-scoped, because on gaussian both engines share an MLE and the
  as-shipped VGH's extra parameters are a model-selection question rather than an engine
  comparison.
- **`$elbo` staleness does not affect this run.** `gaussian-collapse.R` deliberately never reads
  `fit$elbo`; it recomputes `exact_ll()` from the returned parameters. That matters because the
  dev engine's `$elbo` was found stale by one sweep on the convergence path, which does affect
  other scripts — see the separate stale-ELBO work.
