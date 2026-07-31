# Stage 1 result — and why it cannot say what it was designed to say

**2026-07-31 · Claude (Fable 5) · 12,000 fits on DRAC/fir · 2400/2400 tasks, 0 failures**
**Every claim below survived adversarial refutation by an independent agent that recomputed
it from the CSV. Ten claims went in; ten came back refuted AS PHRASED; what follows is the
corrected, narrower version of each. Results LOCAL (D-50). 🔴 No public claim without Shinichi.**

---

## The bottom line

**On the all-fits population, at large ‖Λ‖, the shipped AGHQ arm recovers trait correlations
substantially better than Laplace — and that is the only population that can carry a verdict,
because the two populations designed to isolate the *estimator* are both invalid.**

So the campaign answers a narrower question than it was built to answer. It measures the
**AGHQ package** (quadrature + multi-start + convergence behaviour) against the **Laplace
package**. It does **not** cleanly isolate "AGHQ the estimator", and the reason is worth more
than the headline.

---

## What survived, with the number that supports it

**1. Three cells (not four) show AGHQ HELPS at σ_λ = 3, on all fits.**

| n | paired Δ (laplace − aghq) | margin over δ = 0.02 |
|---|---|---|
| 100 | +0.115 | 19.1 MCSE |
| 400 | +0.146 | 25.2 MCSE |
| 1600 | +0.169 | 27.2 MCSE |

All three clear a Bonferroni correction over **all 54** pre-registered contrasts (z = 3.31),
not merely over 18. Multiplicity is not a threat to these.

**2. The all-fits population is complete and precise.** 12,000/12,000 fits `ok`, zero missing
ρ-MAE, MCSE 0.0040–0.0060, and `3 × MCSE < δ` in 6/6 cells.

**3. The mechanism is the runaway.** At σ_λ = 3 Laplace runs away in 98–99% of fits at every n
(‖Λ̂‖/‖Λ‖ medians 8.65 / 6.10 / 5.75); the shipped AGHQ arm runs away in 1–11%.

**4. Today's #843 multi-start fix is load-bearing, not incidental.** The pre-fix arm
(`aghq_single`) runs away in 98–99% at σ_λ = 3 with **0% convergence**. Without it the AGHQ arm
is useless in precisely the regime where AGHQ wins.

**5. The quadrature is genuinely active here.** `par_shift > 1e-6` in 99–100% of fits, median
shift 1.3–63. No bit-for-bit-Laplace problem in binomial.

---

## 🔴 Why the estimator question is NOT answered

The design named three populations so the estimator could be separated from the optimiser.
Verification found **both filter populations are broken** — and in opposite directions.

**Converged-only is not like-for-like.** `converged` is TRUE for **4800/4800** Laplace-family
fits — including **49.1% that ran away**. The Laplace flag carries *no information*; it is not
the same criterion as the AGHQ one. Comparing "converged AGHQ" against "converged Laplace" is
comparing a filtered arm against an unfiltered one.

**Non-runaway is asymmetric, and stacked.** Between **58.9% and 100%** of dropped pairs involve
a *Laplace* runaway, and in all three σ_λ = 3 cells the AGHQ-only drops are **zero**. The filter
removes Laplace's failures and keeps AGHQ's, then asks which arm is better.

That is why the populations disagree in sign at σ_λ = 1 (all-fits +0.057, non-runaway −0.012 at
n = 100). **The disagreement is not noise and it is not resolved — it is an artefact of a filter
that cannot be applied symmetrically.** Reporting it is mandatory; resolving it silently would
have been the worst available option.

---

## Other things verification corrected in my own reporting

- **The normal 95% CI is adequate for 13 of 18 contrasts** (|skew| ≲ 2). For the rest the paired
  differences are too skewed and the interval should be bootstrapped before it is quoted.
- **My δ = 0.02 justification was weak.** The practical-threshold reasoning I wrote into the
  design does not hold up as stated. δ is still a *pre-registered* threshold, which is what
  matters for avoiding post-hoc tuning — but it is not independently motivated, and I should
  not present it as if it were.
- **ρ-MAE's aggregation is safe only where checked**: for `laplace − aghq` on all fits, the gain
  is positive on all 15 off-diagonal entries with no entry above 1.57× its cell mean. That is
  one contrast on one population, not a general property.

---

## What a reviewer attacks first

The converged-only column, because it looks like the estimator answer and is not. Second, the
σ_λ = 1 sign flip. Both are now stated in the open above rather than buried.

## The permitted sentence

> In binomial stacked-trait GLLVMs at p = 6, q = 2, σ_λ = 3, on the loadings-only grammar, over
> all fits, the shipped multi-start AGHQ arm recovers the latent trait correlations
> substantially better than Laplace (paired Δ ρ-MAE 0.115–0.169, ≥19 MCSE above δ = 0.02), and
> the mechanism is a 98–99% → 1–11% reduction in loading runaway.

Not "AGHQ is better". Regime **and** population, both required.

## Not done

Stage 2 (gaussian/poisson controls) is submitted and queued on fir — scheduler-bound, not
blocked. Nothing in the above turns on it; it is a generality check.

---

# ADDENDUM — three corrections from the full verification (17 agents, 1.9M tokens)

The consolidated verification landed after the above was written and **corrects it in three
ways that change the characterisation, not the arithmetic**. Recorded here rather than
silently edited in.

## C1. The effect is a runaway-avoidance signal, not a broad accuracy gain

This is the biggest correction. The paired mean is carried by a **handful of replicates**:

| cell, contrast | dbar | median d | share of dbar from 20 of 400 replicates |
|---|---|---|---|
| n=400 σ_λ=1, laplace−aghq | +0.0226 | **+0.00014** | **79%** |
| n=1600 σ_λ=1, laplace−aghq | +0.0254 | +0.0104 | 65% |
| n=1600 σ_λ=1, aghq_single−aghq | +0.0096 | 0 (**50.75% of pairs exactly zero**) | 100.5% |

At n=400 σ_λ=1 **exactly 50.0% of replicates favour each arm**. At σ_λ=3 the pairs where
"Laplace runs away and AGHQ does not" contribute **91% / 99% / 99%** of dbar.

So the honest mechanism statement is stronger than "the mechanism is runaway": **the paired
difference very nearly *is* the runaway-frequency difference.** On replicates where neither
arm runs away, the arms are close to indistinguishable. Any sentence implying AGHQ is broadly
more accurate is wrong.

## C2. Four of the ten "AGHQ HELPS" tags are multi-start verdicts wearing a quadrature label

The `aghq_single − aghq` contrast has **AGHQ on both sides** — it isolates the *start rule*,
not the quadrature. The summariser prints "AGHQ HELPS" for it, which is a **labelling defect
in my own tooling**. The numbers are right; the label is not. Of 18 contrasts: 10 HELPS, of
which 4 are this contrast.

## C3. The replicate budget under-delivered its own pre-registration

Design §D.3 assumed pilot `sd(d) = 0.0624`, promising `3×MCSE = 0.0094`, "comfortably below
δ = 0.02". Realised `sd(d)` on the primary unpenalised contrast is **0.0806–0.1203 — 1.29× to
1.93× the pilot** — so realised `3×MCSE` reaches **0.0181, i.e. 0.9δ, not 0.47δ**.

Consequence: the two INCONCLUSIVE cells are inconclusive **on precision, not on effect**.
To resolve them would need **B = 857** (n=1600 σ_λ=1) and **B = 6,338** (n=400 σ_λ=1). The
second is effectively unreachable, and that is a fact about the estimand's variance, not about
the compute budget.

**The pilot was drawn from one cell and did not generalise.** A single-cell pilot is not a
sound basis for a multi-cell MCSE budget — my error, and a reusable one.

## What the verification CONFIRMED (worth stating, since so much was corrected)

- **Pairing exact**: 2400 unique (cell, seed) keys × 5 arms, 0 duplicates, 0 failures, 0 NA.
- **The primary measure reconstructs from raw Λ̂** to `max|diff| = 1.8e-08` over all 12,000 rows.
- **MCSE is correct *and* robust**: against 20,000 bootstrap resamples per contrast the normal
  SE agrees to ≤1% and CI endpoints to ≤4e-4, *despite* skew to 6.4 and kurtosis to 49.
- **Multiplicity is not a threat**: minimum decisive margin 3.94 MCSE against a Bonferroni-54
  requirement of 3.29. No verdict changes.
- **ρ-MAE hides nothing at entry level**: gain positive on all 15 entries in all 6 cells, in
  every |ρ_true| stratum, no entry above 1.57× its cell mean.

## An unresolved disagreement between lenses, left unresolved

One lens computed measure-scale benchmarks (rank-1 collapse → ρ-MAE 0.3625, all-zero → 0.6375,
independent draw → 0.8120) and concluded **δ = 0.02 IS defensible**, since observed arm means
0.10–0.31 sit in a discriminating range. A refuter concluded the opposite. **I am not
adjudicating this.** δ's role as a *pre-registered* threshold is unaffected either way.

## Also flagged, and it is a tooling defect

The non-runaway sensitivity at σ_λ=3 retains **5/400, 5/400, 7/400 pairs (1.2–1.8%)** and the
summariser prints them as `dbar ± MCSE` **with no flag**. They should be suppressed or marked
NOT REPORTABLE. I flagged this in prose; the tool should flag it itself.
