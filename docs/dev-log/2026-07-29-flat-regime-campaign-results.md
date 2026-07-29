# The flat-regime campaign — full results, 2026-07-29

**432,000 fits · 216 configs × 2000 seeds · Totoro, 150 cores · fit-health 1.0000**
(0 errors, 15 NA `par_shift` out of 432,000). Seeded shuffle, so every prefix was an unbiased
sample. Script `dev/aghq-evidence/23-flat-regime-campaign.R`. Raw results stay **LOCAL (D-50)** at
`~/h4_work/regime.csv` (113 MB).

This is the adjudication-scale test of S3's finding that the AGHQ "stall" is a genuinely near-flat
objective rather than an engine defect. Three competing explanations were separable by design.

## Verdicts

### H3 — quadrature artefact: **REFUTED**

| `aghq_k` | stall rate | 2·MCSE | n |
|---|---|---|---|
| 9 | 0.5455 | ±0.0026 | 143,995 |
| 25 | 0.5451 | ±0.0026 | 143,995 |
| 51 | 0.5451 | ±0.0026 | 143,995 |

**Flat across a 5.7× change in node count.** This was the hazard the grounded literature sweep
raised — the adaptive-quadrature literature reports that too few nodes flatten the log-likelihood
in the covariance parameters and produce spuriously *exactly zero* posterior SDs, numerically
indistinguishable from a true boundary. **It does not explain this stall.** Adding nodes changes
nothing.

### H1 — DGP `pmin(eta, 6)` cap artefact: **REFUTED**

Restricted to `lam_sd ≥ 2`, where the cap actually bites (`frac_capped` ≈ 0.0475, `eta_max` ≈ 15.2):

| `eta_cap` | stall rate | 2·MCSE | n |
|---|---|---|---|
| FALSE (uncapped) | 0.6069 | ±0.0030 | 107,985 |
| TRUE (capped) | 0.6005 | ±0.0030 | 108,000 |

The 0.0064 difference is marginally outside combined MCSE, so a *small* real effect exists — but it
runs in the **opposite direction** (uncapped stalls slightly *more*) and is 0.6 pp against a 60%
base rate. The cap is not the cause. S3 left this confound explicitly open; it is now closed.

### H2 — inherent regime: **SUPPORTED**

| `lam_sd` | stall rate | 2·MCSE |
|---|---|---|
| 0.5 | 0.4274 | ±0.0030 |
| 1.0 | 0.5460 | ±0.0030 |
| 2.0 | 0.5973 | ±0.0030 |
| 3.0 | 0.6101 | ±0.0030 |

Clean monotone dose-response in latent-signal strength, far outside MCSE. This is the
Rabe-Hesketh / Skrondal / Pickles (2002) prediction for discrete responses with small clusters and
high ICC.

## 🔴 The finding nobody predicted — family dominates

| family | stall rate | 2·MCSE | n |
|---|---|---|---|
| **binomial** | **0.0000** | ±0.0000 | 144,000 |
| poisson | 0.7401 | ±0.0023 | 143,985 |
| gaussian | 0.8956 | ±0.0016 | 144,000 |

**Binomial never stalls — zero times in 144,000 fits.** Gaussian stalls ~90% of the time.

This **refines S3's conclusion**. S3 wrote that *"the poisson stall is a misnomer — family is NOT
the discriminator"*, on 5 seeds per family under one DGP. At 144,000 fits per family the truth is
sharper: the *name* was wrong, but not because family is irrelevant — because family is an
**enormous** predictor and poisson is the middle case, not the worst. The correct statement is:

> It is not a poisson stall. It is a **gaussian-worst, poisson-middling, binomial-never** pattern
> that also strengthens monotonically with latent-signal strength.

Both the family axis and the `lam_sd` axis are real, and family is the stronger of the two
(0.00 → 0.74 → 0.90 across families, versus 0.43 → 0.61 across `lam_sd`).

## Sample size makes it worse, not better

| n | stall rate | 2·MCSE |
|---|---|---|
| 100 | 0.4739 | ±0.0026 |
| 200 | 0.5680 | ±0.0026 |
| 400 | 0.5938 | ±0.0026 |

Counterintuitive at first sight, and consistent with the mechanism: more data sharpens the
likelihood, so the adaptation converges sooner and the quadrature correction it could still make
gets smaller — which is exactly what the stopping rule reads as "settled". More data means *less*
for AGHQ to do, not more.

## Materiality

Among the 196,465 **non-stalled** fits: median `par_shift` = **0.399**, q90 = **6.05**, and only
**8.5%** fall below the 3e-4 materiality floor.

So the floor is not a general problem: **when AGHQ engages, it moves the estimate substantially.**
The materiality concern belongs specifically to the stalled cells, where the reported shift is
~1e-4 noise. The two populations are cleanly separated, which is itself reassuring — this is not a
continuum of marginal corrections but a bimodal "engaged / not engaged" split.

## What this settles, and what it does not

**Settled.** S3's verdict (C) holds at adjudication scale. The stall is a property of the
likelihood in a regime, not an engine defect, and neither quadrature resolution nor the DGP's
linear-predictor cap explains it. The multinomial deferral therefore rests on confirmed evidence.

**Not settled.** Why binomial is immune. A 0.0000 rate in 144,000 fits is not a small effect
needing explanation — it is a categorical difference, and the obvious candidates (bounded support,
the logit link's curvature, the absence of a free dispersion parameter) are untested speculation.
That is the question this campaign raises rather than answers, and it is worth more than another
sweep of the same grid.

**Also unexplained.** The small but real `eta_cap` effect runs the wrong way. It is 0.6 pp and does
not change any conclusion, but it is not noise and nothing here accounts for it.
