# The flat-regime campaign — full results, 2026-07-29

**432,000 fits · 216 configs × 2000 seeds · Totoro, 150 cores · fit-health 1.0000**
(0 errors, 15 NA `par_shift` out of 432,000). Seeded shuffle, so every prefix was an unbiased
sample. Script `dev/aghq-evidence/23-flat-regime-campaign.R`. Raw results stay **LOCAL (D-50)** at
`~/h4_work/regime.csv` (113 MB).

This is the adjudication-scale test of S3's finding that the AGHQ "stall" is a genuinely near-flat
objective rather than an engine defect. Three competing explanations were separable by design.

> ## 🔴 Scope correction, 2026-07-29 — read before any number below
>
> **Every "stall rate" in this document is a WARM-START stall rate.** The campaign derives its
> `stalled` column as `grepl("^STALLED", stop_reason)`
> (`dev/aghq-evidence/23-flat-regime-campaign.R:108`), which is case-sensitive and anchored. The
> engine emits **three** stuck-state messages and only one is uppercase:
>
> | `R/fit-multi.R` | message | counted here? |
> |---|---|---|
> | `:5482` | `stalled (no honest descent at cap N after backtracking)` | ✗ |
> | `:5524` | `STALLED at the warm start…` | ✓ |
> | `:5531` | `stopped: …objective stagnated, max\|grad\| exceeds tolerance` | ✗ |
>
> **The numbers are correct; the label was too broad.** An independent re-derivation reproduced
> this document's `stalled` column bit-for-bit — 431,985/431,985 non-NA rows, 0 mismatches — so no
> figure below changes. What changes is what they are a rate *of*.
>
> **The verdicts stand.** `:5524` is the defensible predicate for this campaign's question: its
> guard is `identical(par_cur, par_start_aghq) && g_cur >= grad_tol`, i.e. AGHQ returned the
> Laplace warm start bit-for-bit at a gradient above tolerance — precisely the flat-covariance
> pathology H1/H2/H3 were posed against. A three-lens D-43 panel considered two broader stall
> definitions and **rejected both**, 2-1: the broadest would relabel ~157,000–168,000 fits as
> "stalled" that moved the estimate by a median of 0.4.
>
> **One methodological caution the panel established:** this design is **PAIRED** — every DGP is
> fit once per `aghq_k` with `eta_max` byte-identical across levels. The unpaired `2·MCSE` columns
> below are therefore conservative for *between-`aghq_k`* comparisons, and any future between-node
> test should use McNemar rather than these bands. At N=144,000 a paired test flags essentially
> every contrast, so significance alone cannot adjudicate H3 either way.
>
> Full working: `docs/dev-log/2026-07-29-binomial-stall-interrogation.md`.

## Verdicts

### H3 — quadrature artefact: **REFUTED**

| `aghq_k` | warm-start stall rate | 2·MCSE | n |
|---|---|---|---|
| 9 | 0.5455 | ±0.0026 | 143,995 |
| 25 | 0.5451 | ±0.0026 | 143,995 |
| 51 | 0.5451 | ±0.0026 | 143,995 |

**Flat across a 5.7× change in node count.** This was the hazard the grounded literature sweep
raised — the adaptive-quadrature literature reports that too few nodes flatten the log-likelihood
in the covariance parameters and produce spuriously *exactly zero* posterior SDs, numerically
indistinguishable from a true boundary. **It does not explain this stall.**

> 🔴 **Corrected 2026-07-29.** This paragraph originally ended *"Adding nodes changes nothing."*
> **That sentence is too strong and is withdrawn**; the verdict above is not. Node count does move
> something — the *converged* rate rises monotonically with it (0.0259 / 0.0343 / 0.0399 at
> k = 9/25/51, a 7.5× margin), a signal that needs no stall definition at all. But it is
> **family-confined**: gaussian's converged count is 731/731/731 — *bit-identical* across node
> counts — and the entire pooled movement lives in binomial. The accurate statement is: **adding
> nodes does not dissolve the warm-start stall, and does not touch gaussian at all; it shifts
> binomial's terminal state, roughly half of that toward a different failure** (adaptation-failure
> rises 17×, from 108 to 1,865, across the same node range).

### H1 — DGP `pmin(eta, 6)` cap artefact: **REFUTED**

Restricted to `lam_sd ≥ 2`, where the cap actually bites (`frac_capped` ≈ 0.0475, `eta_max` ≈ 15.2):

| `eta_cap` | warm-start stall rate | 2·MCSE | n |
|---|---|---|---|
| FALSE (uncapped) | 0.6069 | ±0.0030 | 107,985 |
| TRUE (capped) | 0.6005 | ±0.0030 | 108,000 |

The 0.0064 difference is marginally outside combined MCSE, so a *small* real effect exists — but it
runs in the **opposite direction** (uncapped stalls slightly *more*) and is 0.6 pp against a 60%
base rate. The cap is not the cause. S3 left this confound explicitly open; it is now closed.

### H2 — inherent regime: **SUPPORTED**

| `lam_sd` | warm-start stall rate | 2·MCSE |
|---|---|---|
| 0.5 | 0.4274 | ±0.0030 |
| 1.0 | 0.5460 | ±0.0030 |
| 2.0 | 0.5973 | ±0.0030 |
| 3.0 | 0.6101 | ±0.0030 |

Clean monotone dose-response in latent-signal strength, far outside MCSE. This is the
Rabe-Hesketh / Skrondal / Pickles (2002) prediction for discrete responses with small clusters and
high ICC.

## 🔴 The finding nobody predicted — family dominates the WARM-START stall

| family | warm-start stall rate | 2·MCSE | n |
|---|---|---|---|
| **binomial** | **0.0000** | ±0.0000 | 144,000 |
| poisson | 0.7401 | ±0.0023 | 143,985 |
| gaussian | 0.8956 | ±0.0016 | 144,000 |

**Binomial never warm-start stalls — zero times in 144,000 fits, exact and flat across all 72
regime cells.** Gaussian does so ~90% of the time.

> 🔴 **Corrected 2026-07-29.** This section originally read *"binomial never stalls"* and framed
> the 0.0000 as categorical immunity. **Binomial never returns the Laplace warm start bit-for-bit —
> that part is exact and real. It is not free of trouble.** It reaches the other two stuck states
> at roughly **89%** (45.5% via `:5482`, 43.8% via `:5531`), and its fits run *longer* than
> gaussian's, not shorter. So "binomial is clean and fast" does not follow from the 0.0000 and was
> never measured.
>
> The `aghq_used` column rules out the obvious alternative: it is **TRUE for 144,000/144,000**
> binomial rows, so this is not a family silently routed to Laplace and scored as never-stalling.
>
> The open question is therefore narrower and still unexplained: **why does binomial never return
> the warm start unchanged when gaussian does so 89.6% of the time?** Design to separate the
> candidate mechanisms — bounded support and the logit link are perfectly confounded here, since
> only binomial has either — is at
> `docs/dev-log/2026-07-29-family-axis-campaign-design.md`.

This **refines S3's conclusion**. S3 wrote that *"the poisson stall is a misnomer — family is NOT
the discriminator"*, on 5 seeds per family under one DGP. At 144,000 fits per family the truth is
sharper: the *name* was wrong, but not because family is irrelevant — because family is an
**enormous** predictor and poisson is the middle case, not the worst. The correct statement is:

> It is not a poisson stall. It is a **gaussian-worst, poisson-middling, binomial-never** pattern
> that also strengthens monotonically with latent-signal strength.

Both the family axis and the `lam_sd` axis are real, and family is the stronger of the two
(0.00 → 0.74 → 0.90 across families, versus 0.43 → 0.61 across `lam_sd`).

## Sample size makes it worse, not better

| n | warm-start stall rate | 2·MCSE |
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

**Not settled.** Why binomial never returns the warm start unchanged. A 0.0000 rate in 144,000
fits is not a small effect needing explanation — it is a categorical difference, and the obvious
candidates (bounded support, the logit link's curvature, the absence of a free dispersion
parameter) are untested speculation. That is the question this campaign raises rather than answers,
and it is worth more than another sweep of the same grid.

> 🔴 **Updated 2026-07-29.** Two amendments, both from re-analysis of this same dataset — no new
> compute.
>
> **"Immune" is withdrawn.** Binomial is immune to the *warm-start* stall specifically. It reaches
> the other two stuck states at ~89%, so it is not trouble-free; the question is why its trouble
> never takes this particular form.
>
> **One candidate is already dead.** *Absence of a free dispersion parameter* cannot be the
> mechanism: poisson also lacks one and warm-start stalls 74% of the time. This needed no new fits
> — it follows from the family table above.
>
> The remaining two candidates — **bounded support** and **logit curvature** — are *perfectly
> confounded* in this design, because binomial is the only family here with either. No re-analysis
> can separate them. The design that can is at
> `docs/dev-log/2026-07-29-family-axis-campaign-design.md`; its decisive cell is `ordinal_probit`,
> which is bounded and discrete but **not** logit.

**Also unexplained.** The small but real `eta_cap` effect runs the wrong way. It is 0.6 pp and does
not change any conclusion, but it is not noise and nothing here accounts for it.
