# 09 — Where does the AGHQ small-*n* upward bias actually come from?

**Script:** `dev/aghq-evidence/09-bias-mechanism.R`
**Data:** `09-bias-mechanism.csv` (one row per Λ element per fit, 13 cells),
`09C-truthstart.csv`, log `09-bias-mechanism.log`
**Instrument:** `dev/aghq-r-reference.R` (pure-R AGHQ; Laplace **is** k = 1 of the same code path)
**Cell:** binomial-logit GLLVM, p = 4 traits, q = 1; anchors at `lam_sd = 1.2`, 40 seeds; signal sweep 16–20 seeds
**Wall time:** 43.7 min for the main run + ~2 min for Part C. **Over the ~15 min guidance** — the n = 800 cells cost ~2.5 min/fit. Output was written per cell, so nothing was at risk.

---

## Verdict

**(b) heavy tail from runaways** — but with three corrections to how that was framed,
each of which changes the remedy:

1. The "tail" is **the majority of fits**, not a rare event: 68% of AGHQ fits at
   n = 100 have some loading above 5 when the largest true loading is 1.70.
2. The runaway is **elementwise** — ~97% of the squared error sits in *one* of four
   loadings, and *which* one is close to arbitrary. The **median loading is
   shrunk, not inflated**, in the very same fits whose norm ratio is 2.66.
3. It is **not (c) separation-driven**, and it is **signal-dependent in the
   opposite direction to (d) as posed**: the AGHQ bias is **worst at the weakest
   true signal** and largely gone at the strongest. That is the signature of a
   flat likelihood ridge under weak identification, not of a boundary problem.

**Laplace and AGHQ fail by two different mechanisms with opposite signal
dependence, and only AGHQ's is a bias.**

| | Laplace (k = 1) | AGHQ (k = 15) |
|---|---|---|
| median ratio, n = 100 | 0.996 | 2.663 |
| what that median hides | **two disjoint populations**: 30 converged fits at **0.810**, 10 **non-converged** blow-ups at **13.6**, with a **gap between 1.52 and 10.57** | **one continuous** distribution, **39/40 converged**, median among converged **2.612** |
| fits with any \|η̂\| > 10, n = 100 | **12/40**, ρ(ratio, sep) = **0.80** | **1/40**, ρ = 0.27 |
| worst at | **strong** signal (`lam_sd` 2.0 → **5.108**, 12.3% separated cells) | **weak** signal (`lam_sd` 0.4 → **6.844**, 0% separated cells) |
| where its flat bias lives, n = 800 | **entirely in the largest loading**: ranks 1–3 ratio **0.991**, rank 4 alone **0.675** | nowhere: ranks 1–3 **1.057**, rank 4 **0.945** |
| is it the MLE? | blow-ups are optimiser failures (all 10 `conv≠0`) | **yes** — Part C: truth-start ties the objective in **40/40** |

The brief's "two errors cancelling" reading of Laplace's small-*n* adequacy is
right in spirit and **wrong in mechanism**: it is not two errors cancelling
*inside* each fit, it is **two failure populations mixing across fits**. That
matters, because a mixture median is not repairable by a bias correction.

---

## Method, and the one step that is load-bearing

Λ is identified only up to a q × q rotation; for q = 1 that is a **sign**. A fit
returning −Λ_true is a *perfect* fit, but a naive elementwise error would score
it as a catastrophic −2Λ_true. Every elementwise number below is therefore
computed after an **orthogonal Procrustes alignment** of Λ̂ to Λ_true (SVD form,
so it is also correct for q > 1, though q > 1 is never exercised here).

- `err_out` = sign(Λ_true) · (Λ̂_aligned − Λ_true). **Positive = the loading moved
  *away from zero***, the direction the upward norm bias requires.
- `rank_true` = rank of |Λ_true| within a fit; **1 = smallest, 4 = largest**. Λ_true
  is redrawn per seed, so element *index* means nothing across seeds; rank does.
- `max_share` = share of total squared elementwise error in the single worst
  element. **Null calibration, measured not assumed** (4 iid mean-zero errors, no
  runaway at all): **median 0.598**. With only four elements the null is already
  high, so 0.598 — not 0.25 — is the number to beat.
- `sep10` = fraction of cells with |η| > 10 **at the fitted conditional modes**.

### Breaking the check on purpose

Alignment is the one step that, if wrong, inverts the elementwise conclusion.
`selftest()` guards it; `BREAK_ALIGN=1` swaps `align_lambda()` for the identity.
Both were run:

```
--- NORMAL (must pass) ---
SELFTEST: flip=TRUE signrule=TRUE outward=TRUE inward=TRUE share1=TRUE share4=TRUE
exit=0
--- BROKEN: alignment disabled (must FAIL) ---
SELFTEST [BREAK_ALIGN=1]: flip=FALSE signrule=TRUE outward=FALSE inward=TRUE share1=TRUE share4=TRUE
Error in selftest() : selftest FAILED: flip, outward
Execution halted
exit=1
```

It goes red, and on the two assertions that matter — `flip` (a sign-flipped
perfect fit must align back to truth) and `outward` (a sign-flipped *inflated*
fit must read as outward on every element).

**Honest note:** the other four assertions stayed green under the break.
`signrule`'s test input already has a positive sign; `inward` happens to read
correctly either way; the two `share` assertions never touch alignment. So the
suite is **2 of 6 sensitive** to the defect it exists to catch. The run aborts,
which is what is needed — but this is not an "all six turned red" story and I am
not going to report it as one.

---

## Q1. Elementwise: is every loading pushed outward?

**No — the opposite.** At n = 100 with AGHQ the *typical* loading is **shrunk**,
and the entire norm inflation comes from one element per fit.

| engine | n | rank | med `err_out` | med rel | frac `err_out` > 0 | med \|Λ_true\| |
|---|---|---|---|---|---|---|
| AGHQ15 | 100 | 1 | +0.036 | +0.065 | 0.525 | 0.243 |
| AGHQ15 | 100 | 2 | −0.047 | −0.067 | 0.475 | 0.635 |
| AGHQ15 | 100 | 3 | −0.251 | −0.246 | 0.325 | 1.086 |
| AGHQ15 | 100 | 4 | −0.123 | −0.086 | 0.375 | 1.697 |
| AGHQ15 | 800 | 1 | +0.030 | +0.072 | 0.600 | 0.243 |
| AGHQ15 | 800 | 2 | −0.035 | −0.035 | 0.450 | 0.635 |
| AGHQ15 | 800 | 3 | +0.055 | +0.033 | 0.600 | 1.086 |
| AGHQ15 | 800 | 4 | −0.096 | −0.055 | 0.425 | 1.697 |
| LAPLACE | 100 | 1 | −0.081 | −0.423 | 0.400 | 0.243 |
| LAPLACE | 100 | 2 | −0.285 | −0.373 | 0.350 | 0.635 |
| LAPLACE | 100 | 3 | −0.383 | −0.402 | 0.225 | 1.086 |
| LAPLACE | 100 | 4 | −0.465 | −0.329 | 0.250 | 1.697 |
| LAPLACE | 800 | 1 | +0.044 | +0.151 | 0.625 | 0.243 |
| LAPLACE | 800 | 2 | −0.008 | −0.012 | 0.475 | 0.635 |
| LAPLACE | 800 | 3 | −0.096 | −0.092 | 0.325 | 1.086 |
| LAPLACE | 800 | 4 | **−0.495** | **−0.325** | **0.050** | 1.697 |

Read the `frac > 0` column for AGHQ at n = 100: **only 32–53% of loadings move
outward**, i.e. the median loading moves *inward* at every rank but the smallest.
The pooled median relative outward error is **−0.117** — while the median **norm**
ratio for those same fits is **2.663**. A norm summary and an elementwise summary
of the same fits point in **opposite directions**. That is exactly the failure a
norm was always going to have, and it is why this slice exists.

**Concentration.**

```
null (4 iid errors, no runaway): median max_share = 0.598
AGHQ15  n=100   med 0.966   q90 0.996   frac > 0.8 = 0.70
AGHQ15  n=800   med 0.800   q90 0.987   frac > 0.8 = 0.50
LAPLACE n=100   med 0.721   q90 0.999   frac > 0.8 = 0.45
LAPLACE n=800   med 0.807   q90 0.976   frac > 0.8 = 0.53
```

**0.966 against a 0.598 null**: in the median AGHQ fit at n = 100, ~97% of the
squared elementwise error is in **one** of four loadings; 70% of fits exceed 0.8.

**It is not a scale effect.** If the worst element were simply the largest loading
scaling up, the worst-element rank would be 4 in all 40 fits. Observed counts
(ranks 1/2/3/4): **AGHQ n=100 → 4 / 8 / 10 / 18**; Laplace n=100 → 4 / 6 / 12 / 18.
Mildly tilted toward large loadings, far closer to uniform than to scale-driven.
**Which loading runs away is close to arbitrary.** (By contrast Laplace at n = 800
is 0 / 2 / 4 / **34** — a genuine scale effect, and a different phenomenon; see Q5.)

**Magnitude.** Median max|Λ̂| = **5.75** (q90 8.10, max 103.0) against median
max|Λ_true| = **1.70**; **68% of AGHQ fits at n = 100 have some loading above 5**.
Not a rare tail — the modal behaviour.

**Selection-free confirmation.** Subsets are chosen by |Λ_true| **rank**, not by
error, so there is no selection bias. (A leave-the-worst-out ratio is biased
downward by construction; it is reported in the log for completeness and is *not*
what the conclusion rests on.)

```
                all four   ranks 1-3   rank 4 alone   ranks 1-2
AGHQ15  n=100     2.663      1.506        0.914         1.334
AGHQ15  n=800     1.084      1.057        0.945         1.015
LAPLACE n=100     0.996      0.981        0.671         1.198
LAPLACE n=800     0.798      0.991        0.675         1.047
```

Dropping *any* fixed subset drops the AGHQ n = 100 ratio a long way, because the
runaway is not in a fixed place.

---

## Q2. Tail or shift?

**AGHQ: a continuous upward shift with a heavy tail on top. Laplace: a
two-population mixture, not a tail at all.**

| engine | n | q10 | q25 | q50 | q75 | q90 | q99 | >1.5 | >2 | >5 |
|---|---|---|---|---|---|---|---|---|---|---|
| AGHQ15 | 100 | 0.956 | 1.432 | **2.663** | 3.573 | 4.715 | 23.06 | 29/40 | **26/40** | 3/40 |
| AGHQ15 | 800 | 0.876 | 0.940 | **1.084** | 1.370 | 2.749 | 5.496 | 9/40 | **7/40** | 1/40 |
| LAPLACE | 100 | 0.626 | 0.753 | **0.996** | 12.047 | 14.106 | 39.041 | 13/40 | **12/40** | 12/40 |
| LAPLACE | 800 | 0.650 | 0.691 | **0.798** | 0.914 | 0.951 | 12.816 | 2/40 | **2/40** | 2/40 |

The raw sorted ratios make the difference in *kind* unmissable:

```
LAPLACE n=100: 0.49 0.54 0.57 0.59 0.63 0.67 0.69 0.70 0.72 0.73 0.76 0.78 0.79 0.80
               0.81 0.81 0.85 0.88 0.95 0.98 1.01 1.03 1.04 1.09 1.12 1.14 1.17 1.52
             | 10.57 12.02 12.14 12.45 12.53 12.78 13.54 13.67 18.06 23.33 26.98 46.75
LAPLACE n=800: 0.55 ... 0.95 0.95 1.03 | 11.24 13.82
AGHQ15  n=100: 0.65 0.83 0.86 0.94 0.96 1.15 1.16 1.20 1.21 1.24 1.50 1.63 1.79 1.85
               2.37 2.42 2.45 2.52 2.56 2.61 2.71 2.84 2.85 2.94 3.03 3.13 3.17 3.24
               3.31 3.56 3.61 3.72 3.76 3.77 4.30 4.71 4.72 6.00 7.56 32.97
AGHQ15  n=800: 0.83 0.87 0.87 0.87 0.88 0.90 0.92 0.93 0.93 0.94 0.94 0.96 0.98 0.99
               1.02 1.03 1.04 1.06 1.07 1.08 1.09 1.12 1.13 1.13 1.13 1.16 1.20 1.20
               1.26 1.35 1.44 1.54 1.65 2.18 2.64 2.68 3.38 3.96 4.17 6.34
```

Laplace has a **gap** — 1.52 → 10.57 at n = 100, 1.03 → 11.24 at n = 800 — with
**nothing in between at either sample size**. That is two different things
happening, not one heavy tail. AGHQ is a single continuous distribution shifted
upward, with the shift shrinking from 2.663 to 1.084 as n goes 100 → 800 while a
thinner tail persists (7/40 above 2 at n = 800).

**Caveat, plainly:** with 40 seeds the q99 column is essentially the maximum and
carries no resolution. Treat it as "the largest thing seen", not a quantile. No
MCSE was computed on any median here.

---

## Q3. Is it separation-driven?

**For Laplace, yes. For AGHQ, no.** This is the most decision-relevant result in
the slice.

| engine | n | med sep10 | max sep10 | frac any \|η̂\|>10 | ρ(ratio, sep10) | ρ(ratio, sep6) |
|---|---|---|---|---|---|---|
| AGHQ15 | 100 | 0.0000 | 0.1625 | **0.03** | 0.271 | 0.524 |
| AGHQ15 | 800 | 0.0000 | 0.0000 | **0.00** | — | — |
| LAPLACE | 100 | 0.0000 | 0.1950 | **0.30** | **0.800** | 0.781 |
| LAPLACE | 800 | 0.0000 | 0.1628 | 0.05 | 0.378 | 0.377 |

Splitting each cell on whether the fit shows any separated cell:

```
AGHQ15  n=100   no-sep: 39 fits, med ratio 2.612 | sep:  1 fit,  32.97
AGHQ15  n=800   no-sep: 40 fits, med ratio 1.084 | sep:  0 fits
LAPLACE n=100   no-sep: 28 fits, med ratio 0.801 | sep: 12 fits, med 13.16
LAPLACE n=800   no-sep: 38 fits, med ratio 0.793 | sep:  2 fits, med 12.53
```

**Laplace's blow-ups are exactly its separated fits** (ρ = 0.80; 12 separated
fits, 12 fits above ratio 2, at n = 100). **AGHQ's bias is not**: remove the single
separated fit and the median is still **2.612**. A boundary control repairs
Laplace's right-hand population and does essentially nothing to AGHQ.

### The mechanism: Λ inflates, the modes shrink to compensate

```
AGHQ15  n=100  med max|η̂| 4.18 (q90  7.90, max 71.45) | med max|η_true| 4.68
AGHQ15  n=800  med max|η̂| 2.52 (q90  4.16, max  6.12) | med max|η_true| 5.69
LAPLACE n=100  med max|η̂| 1.99 (q90 28.46, max 35.92) | med max|η_true| 4.68
LAPLACE n=800  med max|η̂| 1.55 (q90  2.47, max 28.86) | med max|η_true| 5.69
```

The median AGHQ fit at n = 100 has a largest linear predictor **smaller than the
truth's** (4.18 vs 4.68) while its largest loading is **3.4× the truth's largest**
(5.75 vs 1.70). Those two facts are compatible only one way:

> **AGHQ inflates Λ and the conditional modes ẑ shrink to compensate.** The
> product Λ̂ẑ stays near the observed scale, so the fitted likelihood never enters
> a separated region — but the **implied marginal** latent variance is far too big.

Quantified: under the fit, η_ij ~ N(b̂_j, Λ̂_j²) across sites, so the fit *implies*
a rate of |η| > 10 cells.

```
AGHQ15  n=100  IMPLIED-by-fit 0.0205 | implied-by-truth 0.000000 | OBSERVED-at-modes 0.0000
AGHQ15  n=800  IMPLIED-by-fit 0.0000 | implied-by-truth 0.000000 | OBSERVED-at-modes 0.0000
LAPLACE n=100  IMPLIED-by-fit 0.0000 | implied-by-truth 0.000000 | OBSERVED-at-modes 0.0000
LAPLACE n=800  IMPLIED-by-fit 0.0000 | implied-by-truth 0.000000 | OBSERVED-at-modes 0.0000
```

**The AGHQ fit at n = 100 asserts that ~2% of cells should have |η| > 10. The
truth implies 0.0000%, and the data shows 0.0000%.** The fit makes a claim about
the marginal latent scale that its own conditional modes contradict. That, not
separation, is what the norm ratio is measuring. (This implied rate ignores b̂ and
treats elements independently — it is an approximation, see limitations.)

### Is the blow-up an optimiser failure?

```
AGHQ15  n=100  conv=0: 39 fits, med 2.612, 25 above 2 | conv≠0:  1 fit, 32.97
AGHQ15  n=800  conv=0: 40 fits, med 1.084,  7 above 2 | conv≠0:  0 fits
LAPLACE n=100  conv=0: 30 fits, med 0.810,  2 above 2 | conv≠0: 10 fits, med 13.61, 10 above 2
LAPLACE n=800  conv=0: 39 fits, med 0.793,  1 above 2 | conv≠0:  1 fit,  13.82
```

**All 10 non-converged Laplace fits at n = 100 are blow-ups**; the 30 converged
ones sit at 0.810, the flat downward bias undisturbed. **AGHQ's inflation is what
clean, converged optimisation returns** (39/40 and 40/40 converged).

---

## Q4. Does it depend on the true signal? — and it goes the *other* way

**Yes, strongly — and the two engines depend on it in opposite directions.**

| engine | n | `lam_sd` | q25 | **median** | q90 | >2 | med sep10 |
|---|---|---|---|---|---|---|---|
| AGHQ15 | 100 | 0.4 | 4.762 | **6.844** | 12.32 | 18/20 | 0.0000 |
| AGHQ15 | 100 | 0.8 | 2.964 | **3.909** | 5.840 | 16/20 | 0.0000 |
| AGHQ15 | 100 | 1.2 | 1.432 | **2.663** | 4.715 | 26/40 | 0.0000 |
| AGHQ15 | 100 | 2.0 | 0.984 | **1.248** | 2.684 | 6/20 | 0.0000 |
| AGHQ15 | 800 | 0.4 | 1.123 | **1.296** | 9.480 | 4/16 | 0.0000 |
| AGHQ15 | 800 | 0.8 | 0.985 | **1.072** | 2.726 | 2/16 | 0.0000 |
| AGHQ15 | 800 | 1.2 | 0.940 | **1.084** | 2.749 | 7/40 | 0.0000 |
| AGHQ15 | 800 | 2.0 | 0.937 | **1.050** | 2.059 | 2/16 | 0.0000 |
| LAPLACE | 100 | 0.4 | 1.391 | **1.724** | 3.054 | 8/20 | 0.0000 |
| LAPLACE | 100 | 0.8 | 0.846 | **1.007** | 1.839 | 1/20 | 0.0000 |
| LAPLACE | 100 | 1.2 | 0.753 | **0.996** | 14.11 | 12/40 | 0.0000 |
| LAPLACE | 100 | 2.0 | 0.939 | **5.108** | 11.33 | 12/20 | **0.1225** |
| LAPLACE | 800 | 1.2 | 0.691 | **0.798** | 0.951 | 2/40 | 0.0000 |

**AGHQ at n = 100 is monotone *decreasing* in the true signal: 6.844 → 3.909 →
2.663 → 1.248.** The bias is worst where the true loadings are *smallest*, with
zero separation at every level. That is the opposite of the separation
prediction, and it is the signature of **weak identification**: when Λ is small
the profile likelihood in Λ is nearly flat, the data cannot pin the loading down,
and the ML estimate wanders far up the ridge. (The absolute scale confirms it is
not a small-denominator artefact: at `lam_sd = 0.4`, ‖Λ_true‖ ≈ 0.8 and a ratio of
6.8 means ‖Λ̂‖ ≈ 5.5 — genuinely huge loadings.)

**Laplace at n = 100 goes the other way**: fine at moderate signal (1.007, 0.996),
and it **explodes at strong signal** — `lam_sd = 2.0` gives median **5.108**, with
**12.25% of cells separated** (the only cell in the whole study with non-zero
median separation), `max_share` 0.994, and only 13/20 converged.

**Consequence for the "Laplace is adequate at small n" claim: it is
regime-specific and it inverts.** At T = 4, n = 100, `lam_sd` = 2.0, Laplace
(5.108) is *four times worse* than AGHQ (1.248).

---

## Q5. Sanity — does the diagnostic reproduce the known-good end?

**Yes.** At n = 800 the AGHQ elementwise bias is ~0 at every rank: median relative
outward error **+0.072 / −0.035 / +0.033 / −0.055**, with `frac > 0` of
**0.600 / 0.450 / 0.600 / 0.425** — straddling 0.5, as an unbiased estimator must.
Pooled median relative outward error **+0.006**. Median ratio **1.084**, and the
selection-free subsets are flat (all four 1.084, ranks 1–3 1.057, rank 4 0.945).
The same holds at every signal level in the sweep (+0.007 / −0.019 / +0.006 /
−0.004). The diagnostic reproduces the known-good end.

**It also localises Laplace's flat bias, which is a bonus finding.** At n = 800:

```
LAPLACE n=800   all four 0.798 | ranks 1-3 0.991 | rank 4 alone 0.675 | ranks 1-2 1.047
                rank 4: med rel err -0.325, and only 2/40 fits move it outward (frac>0 = 0.050)
                worst-element rank counts 1..4: 0 / 2 / 4 / 34
```

**Laplace's ~20% flat downward bias lives almost entirely in the single largest
loading** (0.675), while the other three are essentially unbiased (0.991), and it
does not shrink with n. That is a much sharper target than "a flat 21% on the
norm".

---

## Part C. Is the converged AGHQ runaway the MLE, or a local optimum?

The fixed start `rep(0.3, p)` could plausibly walk into a bad local mode while
still reporting convergence. Refitting all 40 n = 100 seeds **from the true
parameters**:

```
PART C truth-start check, n=100 k=15 lam_sd=1.2, 40 seeds
  med ratio  default-start  2.663 | truth-start  2.663
  objective: default BETTER (d_obj < -1e-4) in 0/40 ; truth-start BETTER in 0/40 ; tie in 40
  among fits with ratio_default > 2 (n=26): truth-start ratio med 3.205, truth-start BETTER in 0
```

**40/40 ties on the objective, identical median ratio, and among the inflated
fits the truth-started optimiser walks *away* from the truth to a median ratio of
3.205.** The inflation is not a start artefact and not a local optimum — **it is
the genuine AGHQ maximum-likelihood answer for these data.**

---

## What could possibly work — and what could not

**Cannot work for AGHQ:**

- **A boundary / separation control** (η bounds, jittering, a Firth-type penalty
  on the *binomial* linear predictor). AGHQ has 1/40 separated fits at n = 100 and
  0/40 at n = 800; strip the one and the median is still 2.612. It would, however,
  substantially repair **Laplace** (12/40 separated at n = 100, ρ = 0.80; and the
  `lam_sd = 2.0` cell at 12.25% separated). **Route it to Laplace, not AGHQ.**
- **A uniform multiplicative shrinkage of Λ̂.** The median AGHQ element is already
  unbiased-to-shrunk (−0.117 at n = 100, +0.006 at n = 800) while the norm is
  2.663. A uniform correction would damage the ~50% of elements that are fine and
  barely dent the one that ran away.
- **More quadrature nodes.** Already established elsewhere (integration error
  1.2e-09 at k = 25), and Part C independently confirms the target: this *is* the
  k = 15 MLE, so refining the integral cannot move it.
- **Anything keyed to the optimiser** (better starts, multi-start, tighter
  tolerances). Part C: 40/40 objective ties from the truth start. Worth doing for
  **Laplace**, where all 10 blow-ups at n = 100 are `conv ≠ 0`.

**Could work for AGHQ — in rough order of fit to the evidence:**

1. **A penalty or proper prior on Λ itself** (Slice B's territory: ridge / normal
   prior / a proper prior on the loading scale). The evidence points here more
   than anywhere: the failure is a **flat likelihood ridge under weak
   identification** (worst at `lam_sd = 0.4`, 6.844; monotone down to 1.248 at
   `lam_sd = 2.0`; it *is* the MLE; it is one arbitrary element per fit). A flat
   ridge is precisely what a penalty is for, and a scale-limiting penalty
   attacks the runaway element without touching the ~50% that are already fine.
2. **A correction targeting the tail rather than the centre** — e.g. reporting a
   penalised/regularised Λ̂ or a shrinkage estimator, with the honest statement
   that at n ≲ 400 and weak loadings the loading is **not identified well enough
   to report unregularised**.

**Probably will not work, and Slice C should know before spending on it:**

- **Firth-type bias reduction applied to Λ.** Firth removes the O(1/n) *first-order*
  bias, i.e. a **shift**. The AGHQ problem is **not a shift** — the median element
  is unbiased at both n = 100 and n = 800 while the norm is inflated by a
  single-element runaway. Firth on the *binomial* side may still help **Laplace's**
  separation population (its classic use), which is a different and legitimate
  target. I have not tested either; this is an inference from the mechanism, not
  a measurement.

**For Slice D (crossover vs T):** the crossover is **not a function of T alone**.
At fixed T = 4 and n = 100, the AGHQ/Laplace ordering *inverts* across the signal
sweep — Laplace wins at `lam_sd` 0.8–1.2 and loses 4:1 at `lam_sd` 2.0. Any
crossover map that varies only T and n will be reporting one slice of a surface
that also moves in `lam_sd`. **Sweep signal strength alongside T.**

---

## What I could NOT verify

- **q > 1 is never exercised.** The Procrustes machinery is written for general q
  but every cell here is q = 1, where alignment degenerates to a sign flip. Whether
  the "one arbitrary element runs away" picture survives a genuine rotation is
  untested.
- **My headline numbers are larger than the orchestrator's.** I get median ratio
  **2.663** at n = 100, AGHQ, against the brief's **1.893**. The signal sweep shows
  `lam_sd` alone spans 1.25–6.84 at n = 100, so a DGP-scale difference plausibly
  explains it — but I **did not** verify against the TMB engine, and an
  engine difference is not excluded.
- **No MCSE anywhere.** 40 seeds at the anchors, 16–20 in the sweep. Medians of a
  heavy-tailed quantity at n = 20 are not precise; the `>2` counts are the more
  robust column. The q99 column is the maximum in disguise.
- **The Laplace signal sweep was run only at n = 100.** The `lam_sd` ∈ {0.4, 0.8,
  2.0} cells at n = 800 for k = 1 were dropped for time. So "Laplace explodes at
  strong signal" is measured at one sample size only.
- **`sep10` is measured at the fitted conditional modes**, which is the right
  diagnostic for "is this fit separated" but is not the marginal η scale. The
  implied-marginal calculation added to compensate ignores b̂ and treats elements
  independently.
- **Part C used one alternative start (the truth).** A 40/40 objective tie is
  strong evidence against a local-optimum artefact but is not a proof of global
  optimality; a third mode neither start reaches is not excluded.
- **Not tested:** whether the runaway element correlates with trait prevalence
  (extreme `colMeans(Y)`), which would be the obvious next elementwise question and
  would sharpen a penalty design. b̂ was not stored per fit, so it cannot be
  recovered from the CSV.
- **One DGP shape throughout**: p = 4, q = 1, binomial-logit, balanced,
  loadings-only, `b ~ N(0.3, 0.4²)`. Nothing here speaks to other families, to
  T ≠ 4, or to models with Ψ.
