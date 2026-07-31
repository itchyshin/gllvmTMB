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
