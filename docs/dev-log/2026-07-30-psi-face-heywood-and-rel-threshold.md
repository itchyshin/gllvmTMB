# The other face of the Heywood case, and the threshold that was already there

Date: 2026-07-30. Author: Claude. Lane: `claude/heywood-gate-20260730` (Arc B).
Companion to `2026-07-30-heywood-gate-false-positive-sweep.md` (Arc A, the loading face).

Provenance: **MEASURED** in this lane unless marked. Scripts:
`dev/heywood/psi-regime-probe.R`, `dev/heywood/psi-shipped-coverage.R`,
`dev/heywood/psi-heterogeneous-fp.R`. Data: the matching `.csv` files.

---

## 1. What Arc A could not see

Arc A fixed the loading face: one trait's loading runs away under quasi-complete
separation. Every fit in its 7,200-fit calibration used `latent(unique = FALSE)`
at the **true** latent rank — so there was **no `Psi` in the model to collapse**,
and no over-factoring. It measured *loading recovery*, and its finding of "zero
degenerate gaussian fits" is a statement about that, not about Heywood cases.

The classical Heywood case is a **unique variance driven to the boundary**. It
needs `Psi` to exist, and its textbook generator is **over-factoring** — fitting
more latent axes than the data supports. Arc A's design excluded both.

## 2. The psi face is real, common, and completely silent

**MEASURED**, 360 fits, gaussian and Poisson, p = 6 traits, true rank q = 1,
fitted rank d in {1, 2, 3}, n in {40, 80, 150}, true unique variances 0.4:

| fitted rank | gaussian | poisson |
|---|---|---|
| d = 1 (true) | 8.3% | 18.3% |
| d = 2 | 68.3% | 75.0% |
| d = 3 | **81.7%** | **96.7%** |

*(share of fits driving a unique SD below a tenth of its true value; 58.1% overall,
minimum reached 6.5e-50)*

**Every conventional signal says the fit is fine.** Among the 209 collapsed fits:
`convergence == 0` in **208**, `pdHess = TRUE` in **190**. That is not an
optimiser failure — `psi = exp(theta)`, so the boundary sits at
`theta -> -Inf`, an *interior* point of the transformed space where the Hessian
is perfectly well behaved. The same mechanism is recorded in the sister repo for
the Gaussian factor-analytic engine
(`hsquared/docs/design/42-fa-calibration-diagnosis.md`:
*"All-converged-yet-mis-recovered is the boundary signature"*).

### 2.1 Why recovery-based labelling is blind to it

**MEASURED:** among the collapsed fits, relative Frobenius error on `Sigma`
spans only **[0.074, 0.880]** — every one of them is "healthy" by the criterion
Arc A used, and **0 of 360** reach the `rel_frob >= 5` bar.

The reason is structural: when `psi_t -> 0`, that trait's loading absorbs the
variance, so `Sigma = Lambda Lambda' + Psi` is still recovered. **What is
destroyed is the decomposition, not the covariance.** Any label built on
`Sigma` recovery therefore cannot see this face, and using one is a category
substitution.

### 2.2 The loading gate cannot see it either

**MEASURED:** `relative_loading` on the collapsed fits spans **[1.16, 10.54]**;
**0 of 209** reach the shipped threshold of 25, and its AUC against the
psi-collapse label is **0.489** — a coin flip. Arc A's instrument is the right
one for its own face and useless for this one.

## 3. `communality > 1` is structurally unreachable — do not wire it

The literal classical Heywood criterion was the obvious candidate, and
`extract_communality()` already computes the quantity (`R/extractors.R`).

**It cannot fire.** `psi = exp(theta) >= 0` always, so
`c^2 = diag(Lambda Lambda') / diag(Sigma)` can approach 1 but never exceed it.
**MEASURED over all 360 fits: maximum communality exactly 1.000, count above 1
= 0.** Wiring it would have shipped a gate keyed on an impossible event — the
same defect Arc A spent the day removing.

`c^2 -> 1` from below does occur (94 fits above 0.999) and does discriminate
(AUC 0.853), but it is **not additive**: for Poisson the link-implicit residual
is added to the denominator, so sensitivity on severe cases is **1.000 for
gaussian and 0.000 for poisson**. It is the wrong instrument to add.

## 4. The right instrument already ships, and was tuned too tight

`near_zero_psi_<level>` fires when the smallest fitted unique SD is below
`psi_thresh` (absolute) **or** below `psi_rel_thresh` times the largest
(relative). Running it — not reasoning about it — on the collapsed fits:

| | result |
|---|---|
| collapsed fits reported | **154 / 209 (73.7%)** |
| severe cases (`min sd < 1e-4`) reported | **56 / 56 (100%)** |
| healthy fits reported | **0 / 151** |
| by family | gaussian 71.6%, poisson 75.4% |

So the row **is** the psi-side detector and it works. Its blind spot is narrow
and specific: **55 fits whose smallest unique SD is 0.09%–8.5% of truth** but
which clear both arms. On 52 of those 55, `check_gllvmTMB()` returns a
completely clean bill of health.

### 4.1 Retuning the relative arm

**MEASURED**, absolute arm held at 1e-4:

| `psi_rel_thresh` | sensitivity | false positives | missed |
|---|---|---|---|
| 0.001 *(old default)* | 0.737 | 0 / 151 | 55 |
| 0.003 | 0.914 | 0 / 151 | 18 |
| **0.01 (new default)** | **0.962** | **0 / 151** | 8 |
| 0.03 | 0.981 | 0 / 151 | 4 |
| 0.1 | 1.000 | 2 / 151 | 0 |

### 4.2 The transport test, which decides it

Sensitivity measured against a **homogeneous** truth (every trait's unique
variance 0.4) proves nothing about a fit whose unique variances genuinely
differ — there a small min/max ratio is *correct*. This is the exact trap Arc A
fell into with homogeneous loadings, so it was tested before proposing anything.

**MEASURED**, 480 fits at the true rank, true unique variances spread over up to
three orders of magnitude; false-positive rate on fits that recovered their
smallest component:

| true spread | 0.001 | **0.01** | 0.03 | 0.1 |
|---|---|---|---|---|
| homogeneous | 0.0000 | **0.0000** | 0.0000 | 0.0000 |
| 10x | 0.0000 | **0.0000** | 0.0000 | 0.0337 |
| 100x | 0.0000 | **0.0000** | 0.0000 | 0.1622 |
| 1000x | 0.0000 | **0.0000** | 0.0128 | **0.1923** |

**The value with the best sensitivity does not transport.** At 0.1 the row would
flag 19% of healthy fits whose unique variances genuinely differ by 1000x.
**0.01 holds at zero across every spread**, with a 2.1x margin to the worst
healthy fit observed (min/max = 0.021).

## 5. Decision

**`psi_rel_thresh` 0.001 → 0.01.** No new row, no new statistic, no new
argument — a single default on an instrument that was already correctly
designed. Sensitivity 73.7% → 96.2%; measured false positives zero on 151
healthy homogeneous fits and 359 healthy heterogeneous ones.

**This is a behaviour change**: fits that previously passed will now warn. On
this evidence they are fits with a genuinely boundary-pinned component, but it
is a maintainer decision, not a self-merge.

## 6. What this does not establish

- **One DGP family.** p = 6, true q = 1, gaussian and Poisson, unique variances
  drawn from a fixed spread pattern. Not swept: p, true q > 1, binomial with
  `unique = TRUE`, other tiers (`unit_obs`, `phylo`, `spatial`), missing data.
- **8 collapsed fits are still missed** at the new default, and the residual
  band has no instrument.
- **The 58% incidence is a property of this design**, chosen to *generate* the
  pathology by over-factoring. It is not an estimate of how often real analyses
  hit it — though users do routinely guess the latent rank.
- **No claim about `Sigma` accuracy.** These fits recover `Sigma` well; what is
  unreliable is the split into shared and unique variance, and therefore
  communality, ICC, and any per-trait variance interpretation.
