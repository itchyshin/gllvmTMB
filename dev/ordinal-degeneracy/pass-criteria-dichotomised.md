# Pre-registered criteria — the DICHOTOMISED ordinal degeneracy check

**STATUS: FROZEN.** Written and committed BEFORE any fit of this cell runs.
Results land in a later, separate commit. Bands are not widened afterwards.

## Why this candidate exists

Four statistics computed from the fitted loading/cutpoint state have already
been eliminated (`pass-criteria-ordinal.md`): the absolute liability-scale
loading, the family-scoped relative loading, loading-over-cutpoint-span
(refused as circular), and the max/second-max spike ratio. None separates
degenerate from healthy ordinal fits at a usable operating point, and the
search on that information source was stopped deliberately to avoid
multiple testing.

This candidate uses a **different information source**, which is why it is
not a fifth draw from the same well. The S1 mechanism probe
(`probe-criteria.md`) established that ordinal degeneracy is **category-level
separation**, and measured, as one of its three discriminating tests, that
collapsing the ordinal response to binary at the middle cutpoint and running
the EXISTING binomial prevalence/loading detector flagged **24 of 24**
degenerate fits. That is a refit-based check, not a summary statistic.

## The load-bearing unknown this cell exists to measure

**The 24/24 is a SENSITIVITY figure only.** The S1 probe ran the
dichotomisation on degenerate fits; it never measured the check's
FALSE-POSITIVE rate on healthy ones. That matters more than usual here,
because the binomial detector this check borrows has its own measured
false-alarm problem — 232/928 (25%) on non-degenerate binomial fits, which
is the substance of issue #897's directive 2 ("a check that cries wolf a
quarter of the time gets switched off"). Inheriting that rate wholesale
would make this candidate useless in exactly the way the previous four
were, and possibly worse: it would fire confidently.

So the question this cell answers is **not** "does it detect?" (measured:
yes) but "**does it detect without crying wolf?**"

## Design

- Datasets: the same four pre-registered arms as the main ordinal campaign
  (`degenerate` sigma_lambda = 3, `healthy` 0.7, `transport` heterogeneous
  per-trait loading scales, `mixed` ordinal+gaussian), n in {100, 400},
  same seeds — so the labels transfer fit-for-fit and this candidate is
  scored on exactly the population that eliminated the other four.
- Procedure per dataset: fit the ordinal model as usual; collapse the
  response to binary at the middle cutpoint; refit as
  `binomial(link = "probit")` with the same latent structure; run
  `.gllvmTMB_binomial_prevalence_loading_row()` on the refit; record its
  verdict, which arms fired, and the refit's convergence/PD status.
- Truth label: unchanged — `rel_frob > 10` on the ORDINAL fit's
  `Sigma_B = Lambda Lambda^T` against the simulated truth.

## Frozen targets (identical rule to the main ordinal campaign)

Scored the same way, so the two candidates are directly comparable:

- **Sensitivity >= 90%** on the `degenerate` arm's `rel_frob > 10` fits.
- **Zero false positives** across `healthy` + `transport` + `mixed`
  combined, ARM-LEVEL (the check stays silent on every one of those fits,
  regardless of any fit's own rel_frob). This is the definition the main
  campaign's first verdict got wrong; it is restated here explicitly so the
  same substitution cannot recur.
- A fit whose binomial refit fails to converge or returns a non-PD Hessian
  is counted and reported separately, and excluded from both rates.

**If both targets are met**, the dichotomised check is the recommended route
to closing #897's detection gap, and the follow-up question is where it
belongs in the API (it costs one refit, so opt-in, not part of the default
`check_gllvmTMB()` sweep).

**If sensitivity holds but specificity fails**, the finding is that the
check inherits the binomial screen's false-alarm rate, and it must not ship
until that screen's own re-calibration (#897 directive 2, currently spun out
as a follow-up) is done. That would make the binomial re-calibration a
prerequisite rather than an independent nicety — a useful thing to learn.

**If sensitivity does not replicate** at 90% on this larger, four-arm
population, the S1 24/24 was optimistic on a 60-fit grid, and the candidate
is eliminated like the other four.

## Compute

315 ordinal fits are already characterised; this cell adds one binomial
refit each. Binomial probit fits are cheaper than the ordinal ones. D-139:
a timing pilot runs first and the projection is recorded here before the
full run; if it exceeds 30 minutes the grid is trimmed and the trim stated.

## VERDICT (2026-08-17) — FAILS, and it falsifies one leg of the S1 verdict

Grid: 315 cells, all four pre-registered arms, n = 100/400, same seeds as the
main ordinal campaign. Every cell produced a binomial refit verdict (0
excluded).

| frozen target | measured | result |
|---|---|---|
| sensitivity >= 90% on the degenerate arm | **97.6%** (40/41) | PASS |
| zero false positives, arm-level, healthy+transport+mixed | **86.3%** (220/255) | **FAIL** |

FP by arm: healthy 67.8%, transport 93.3%, **mixed 100.0%**. That is worse
than the binomial screen's own measured 25% (issue #897) and worse than every
loading statistic tested (best was 39.2%). **The check fires on nearly
everything.**

### Mechanism — the dichotomisation MANUFACTURES what the screen looks for

Direct inspection of three healthy-arm datasets: overall binary prevalence
after the collapse is benign (0.26-0.28), but the binomial refit itself comes
back **saturated** (`saturated_fit` 0.83-0.91) with **runaway loadings**
(`max_loading` 13.4 where the ordinal fit's are near truth). Collapsing K = 4
to binary at the middle cutpoint destroys enough information to create
quasi-separation IN THE REFIT that was never present in the data. The check
is not measuring the ordinal fit's health; it is measuring damage done by the
collapse.

### 🔴 This falsifies one leg of the S1 mechanism verdict

`probe-criteria.md` reached "category-level SEPARATION, not link saturation"
on three measurements, of which the third was *"24/24 dichotomised refits
fire the existing binomial detector -> shared quasi-separation geometry"*.
**That measurement carries essentially no information**: a check that fires
on 86% of healthy fits was always going to fire on 24 of 24 degenerate ones.
It cannot distinguish the hypotheses it was recruited to distinguish.

What survives, and it is still decisive for the NEGATIVE half:
**measurement 2, flat-row share EXACTLY 0 on all 24 degenerate fits**, which
cleanly refutes link saturation — the `gll_log_pnorm_diff` underflow is never
reached. Measurement 1 (directional derivative) was already reported as
landing in the pre-registered MIXED bucket.

**Corrected standing of the S1 verdict: "NOT link saturation" is solidly
evidenced; "therefore category-level separation" is now under-evidenced** —
it was the residual hypothesis rather than a positively demonstrated one, and
the measurement that appeared to demonstrate it does not. The mechanism
question is REOPENED to that extent, and `probe-criteria.md` carries a
pointer to this section.

### Consequence for the route to closing #897

The dichotomised check is **eliminated**, and the binomial re-calibration
(#897 directive 2) is **NOT** the prerequisite it would have been under a
"detecting-but-crying-wolf" result. Recalibrating the binomial screen would
not help here: the problem is not the screen's thresholds but that it is
being shown a dataset the collapse has already damaged. Any future
refit-based check must preserve the information the ordinal response carries
-- which a two-category collapse cannot.
