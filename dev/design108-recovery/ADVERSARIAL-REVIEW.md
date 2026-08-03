# Adversarial review — the Design-108 VA-vs-Laplace recovery verdict

**Reviewer:** Rose (closeout/claims review), fresh context, adversarial prior.
**Date:** 2026-08-03.
**Working tree:** `/private/tmp/gllvmtmb-d108-recovery` (read-only + scratch under `dev/`).

**Claim under review:**

> "VA does not recover the two-tier `Sigma_B` better than the shipped Laplace engine.
> Stages 3/5 are not worth ~7 days."

## VERDICT: DOES NOT HOLD

Not because the arithmetic is wrong — **every number in the brief reproduces exactly** — but
because the two arms were **fit to different models**, giving them different achievable floors on
the scoring metric. In 3 of 4 cells a *perfect* VA fit would still have "lost". The test could not
return the outcome "VA wins", so its returning "VA loses" is not evidence about VA.

Two of the three headline facts collapse under this:

- The **tier-1 gap reverses sign** once the floors are accounted for.
- The **66% non-completion is a harness defect**, reproducibly not a property of the estimator.

**What does survive**, and survives well: VA's structured tier-2 estimates are *degenerate in every
fit that returned* — and §12 shows this is **not** a starting-value artifact (`n_starts = 4`
reproduces the same numbers at 4× the cost, and the engine's own health gate rejects the fits even
with four starts). That is a real single-arm finding about the prototype's current state. It is not
the comparative claim, and it does not by itself carry the 7-day decision.

---

## 0. What reproduces (arithmetic is sound)

Recomputed from `dev/design108-recovery/pilot-results/campaign_grid.csv` (80 rows):

| quantity | brief | recomputed |
|---|---|---|
| VA tier-2 completion | 27/80 | **27/80** ✔ |
| Laplace completion | 80/80 | **80/80** ✔ |
| VA t2 medians (N500q1, N1000q1, N500q2, N1000q2) | 1.450 / 3.860 / 8.520 / 10.816 | **identical** ✔ |
| LAP t2 medians | 0.737 / 0.561 / 0.764 / 0.614 | **identical** ✔ |
| 2·MCSE bands | see brief | **identical to 3 dp** ✔ |
| degeneracy k/n | 1/8, 2/7, 2/6, 3/6 | **identical** ✔ |

Nothing below is a numerical correction. Everything below is about **what was measured**.

---

## 1. THE FATAL FINDING — the two arms fit different models

This is not in the brief, and it is not in `PILOT-FINDINGS.md`. Both describe the campaign as
"**gaussian** … both arms on the SAME data" (`PILOT-FINDINGS.md:466-467`, and the brief's own
grid description). **The Laplace arm is not gaussian.**

**The DGP is binomial probit.**
`dev/design108-recovery/dgp.R:167`

```r
Y <- matrix(stats::rbinom(N * T, n_trials, as.vector(p)), N, T)
```

with `p = pnorm(eta)` and the planted truth `Sigma_B_loadings = Lambda2 %*% t(Lambda2)` living on
the **eta (probit) scale**.

**The Laplace arm fits that model correctly.**
`dev/design108-recovery/harness.R:404-405`

```r
family = stats::binomial(link = "probit"),
weights = dat$n_trials,
```

**The VA arm does not.** `/tmp/totoro_grid.R:15,19-23`

```r
yv <- as.numeric(scale(sim$data$y)); d <- sim$data
...
va <- tryCatch(gllvmTMB:::.va_r3_fit(y=yv, ..., family="gaussian_anchor", link="identity",
        ..., n_starts=1L, ...)
```

So the campaign paired **(correct model + Laplace)** against **(a gaussian identity-link model
fitted to standardized binomial counts + VA)**. The harness's *own* VA wrapper does it correctly —
`.d108_fit_va()` passes `y = dat$y` with `family = "binomial_probit", link = "probit"`
(`harness.R:302-303`). **The campaign script bypassed that wrapper and inlined its own call.**

### 1a. The consequence: the arms have different floors

Because `y` was standardized and fit with an identity link, the VA arm targets the structure of
`scale(y)`, which is the eta-scale structure attenuated by the per-trait slope
`k_t = cov(y_std, eta)/var(eta)`. A *perfect* gaussian-identity fit recovers `D Σ D`
(`D = diag(k_t)`), not `Σ`, and therefore scores `rel_frob(D Σ D, Σ) > 0` against the planted
truth. Laplace, correctly specified, has floor 0.

Measured (`dev/design108-recovery/rose-adv-estimand.R`, `rose-adv-floor.R`; no fitting, pure
simulation + regression, all 80 cells):

- per-trait attenuation `k_t` ∈ [0.368, 0.766] at N=500 q=1 seed 1 — a **2.08×** spread, so this is
  a trait-heterogeneous diagonal congruence, **not** a correctable scalar;
- **median VA oracle floor, tier 2: 0.709 / 0.772 / 0.717 / 0.782** across the four cells;
- median VA oracle floor, tier 1: 0.720–0.802;
- Laplace floor: **0**.

**Could a perfect VA have won?** (`rose-adv-floor.R` output)

| cell | median VA floor (t2) | median LAP observed (t2) | perfect VA |
|---|---|---|---|
| N=500 q=1 | 0.717 | 0.737 | wins (barely) |
| N=1000 q=1 | 0.709 | 0.561 | **LOSES ANYWAY** |
| N=500 q=2 | 0.782 | 0.764 | **LOSES ANYWAY** |
| N=1000 q=2 | 0.772 | 0.614 | **LOSES ANYWAY** |

**In 3 of 4 cells the campaign could not have returned "VA wins" no matter how good VA is.** A test
whose negative outcome is guaranteed by construction is not evidence for that outcome. This is the
single strongest argument against the verdict.

### 1b. The tier-1 result REVERSES under floor correction

Decomposing each arm's error into (floor it cannot beat) + (excess over its own floor):

| cell | VA obs | VA floor | **VA excess** | LAP obs | LAP floor | **LAP excess** |
|---|---|---|---|---|---|---|
| N=500 q=1 | 0.801 | 0.739 | **0.074** | 0.186 | 0 | **0.186** |
| N=1000 q=1 | 0.818 | 0.720 | **0.096** | 0.101 | 0 | **0.101** |
| N=500 q=2 | 0.886 | 0.790 | **0.034** | 0.180 | 0 | **0.180** |
| N=1000 q=2 | 0.828 | 0.802 | **0.041** | 0.122 | 0 | **0.122** |

**VA's excess-over-floor is SMALLER than Laplace's in all four cells.** The campaign's
"**LAPLACE BETTER on both tiers. Tier 1 by 8x**" (`PILOT-FINDINGS.md:483-484`) is, on tier 1,
**an artifact of the specification mismatch**. On the tier where both engines are actually
recovering something, VA is performing essentially at the best its (mis-specified) model allows.

### 1c. Tier 2 — a real deficit survives, much smaller than reported

| cell | VA excess (t2) | LAP excess (t2) |
|---|---|---|
| N=500 q=1 | 0.781 | 0.737 |
| N=1000 q=1 | 3.049 | 0.561 |
| N=500 q=2 | 7.814 | 0.764 |
| N=1000 q=2 | 9.989 | 0.614 |

At N=500 q=1 the two are within 6% of each other — effectively a tie. In the other three, VA is
genuinely worse. And VA never once scored below its own floor of ~0.70: the **minimum** VA tier-2
value across all 27 surviving fits is **≈1.000** (see §2). So VA's tier-2 behaviour is genuinely
degenerate. **That is a real, single-arm finding.** It is not the comparative claim.

---

## 2. Attack 1 — the 66% non-completion is a HARNESS property (settled, with evidence)

**This was the most dangerous confound and it does not survive.**

The campaign swallowed every VA failure into `NA` with no message
(`/tmp/totoro_grid.R:23,41` — `error=function(e) NULL`, then `error=function(e) data.frame(...NA...)`),
so the CSV cannot distinguish an engine failure from a scripting failure. I re-ran cells with the
error **captured and classified** (`dev/design108-recovery/rose-adv-attack1.R`):

| N | q | seed | campaign CSV | Rose re-run (`n_starts=1`, single-threaded) |
|---|---|---|---|---|
| 500 | 1 | 1 | 0.999999999999987 | **OK, va_t2 = 1.000000** (exact reproduction) |
| 500 | 1 | 2 | **NA** | **OK, va_t2 = 1.000000**, 83.4 s |
| 500 | 1 | 3 | **NA** | **OK, va_t2 = 9.193294**, 59.7 s |
| 500 | 1 | 4 | **NA** | **OK, va_t2 = 16.534597**, 67.7 s |

**3 of 3 tested `NA` cells complete when re-run outside the campaign's parallel harness.** Seed 1
reproduces the campaign's value *exactly*, which confirms the probe is a faithful replica and the
difference is not a version or parameterisation drift.

**Mechanism.** The campaign ran `mclapply(..., mc.cores = 40L)` (`/tmp/totoro_grid.R:44`) and
called `gllvmTMB:::.va_r3_fit()` directly from inside the fork. The harness documents a **required**
protocol for exactly this (`dev/design108-recovery/harness.R:103-110`):

> `.d108_build_va_r3_dll_stash(source)`: call ONCE, in the orchestrator, before dispatching any
> worker. … `.d108_seed_va_r3_dll(dll_stash)`: call in EVERY worker, before its first
> `.va_r3_fit()`/`.va_r3_load_dll()` call

**The campaign script calls neither.** With no stash, each of 40 forked workers must compile/load
the separate `gllvmTMB_va_r3` DLL into a `tempdir()`-keyed build directory itself — 40-way
concurrent, caught by the inline `tryCatch` and silently turned into `NA`.

This also explains the completion **asymmetry** that the brief leans on: the Laplace arm uses the
main package DLL, already loaded before the fork, so it needs no per-worker compile — hence
80/80. **The 34%-vs-100% contrast measures which arm needed a DLL warm-up under fork, not which
estimator converges.**

Corroborating evidence, both pointing at a per-worker startup race rather than data difficulty or
resource exhaustion:

- Failures are **seed-random, not seed-consistent** — only seed 14 survives in all four cells;
  seeds 3, 6, 10, 20 survive in none; no cell-independent seed pattern.
- The completion rate is **flat in problem size**: 0.375 at N=500 vs 0.300 at N=1000
  (Fisher p = 0.637), and 0.350 vs 0.325 across q (Fisher p = 1.0). An OOM or time-limit mechanism
  under 40-way parallelism would produce a sharp size effect — the bigger fits would fail far more
  often. They do not. A DLL-load race is independent of problem size, which is what is observed.

**Secondary finding — the engine's own admission gate was never applied.** Every VA fit in my probe
returned `status = failed_health_gate`. With `n_starts = 1` this is *by construction*: admission
requires ≥3 healthy starts (`R/va-r3-proto.R:2152-2156`, "n_starts = 1 … cannot pass the
three-start agreement gate — status stays failed_health_gate so the bypass is visible"). The
campaign scored parameters out of fits the engine itself declines to admit, so degenerate and
runaway fits entered the medians unfiltered. The package's own comment says `n_starts = 1`
reaches the same optimum (`R/va-r3-proto.R:1995-2000`), so this is **not** a claim that
`n_starts = 1` caused the bad numbers — it is that the gate that would have *flagged* them was
switched off.

Note on optimizer-effort fairness: `gllvmTMBcontrol()` has `n_init = 1`, so on number of starts the
arms were matched. `n_starts = 1` is therefore **not** the handicap; the DLL race is.

---

## 3. Attack 2 — selection bias in the surviving 27

**Tested and negative.** If VA only returned on favourable data, Laplace (on the same data) should
look better there too. It does not:

| cell | LAP t2 median, VA-survived | LAP t2 median, VA-failed |
|---|---|---|
| N=500 q=1 | 0.655 (n=8) | 0.811 (n=12) |
| N=1000 q=1 | 0.528 (n=6) | 0.562 (n=14) |
| N=500 q=2 | 0.751 (n=7) | 0.768 (n=13) |
| N=1000 q=2 | 0.614 (n=6) | 0.576 (n=14) |
| **pooled** | **0.704 (n=27)** | **0.679 (n=53)** |

Wilcoxon **p = 0.863**. No detectable difference in cell difficulty. Given §2, this is expected —
a DLL race is independent of the data.

The residual selection channel (VA returns only when its own optimization succeeded) biases
**toward** VA, so it cannot manufacture the observed direction. **Attack 2 does not damage the
verdict** — but with §2 established, it also no longer defends it, because the 53 missing cells are
missing for a reason unrelated to either estimator.

---

## 4. Attack 3 — the two INDETERMINATE cells

The verdict's *direction* survives restriction to the two band-excludes-zero cells (N=500 q=1,
N=500 q=2), and survives far more robustly under a sign test: **26 of 27 pairs favour Laplace,
exact binomial p = 4.17e-07**, with positive median `d` in all four cells.

So attack 3 fails on its own terms — but note that the brief's framing understates its own case,
and the objection that both determinate cells sit at the *smaller* N is real: the two cells where
the mean-based band excludes zero are N=500, and the N=1000 cells are indeterminate purely because
runaways inflate the variance there.

**However**, §1 makes this moot: a 26/27 sign pattern on a metric where VA's floor is 0.70 and
Laplace's is 0 is exactly what you would observe *if both engines were equally good*. The
robustness of the direction is not in question; its **interpretability** is.

---

## 5. Attack 4 — is the cell informative at all?

**The precondition fails, and `PILOT-FINDINGS.md:575-579` already says so.** Laplace tier-2 medians
are 0.561–0.764 against a stipulated 0.5 threshold. Stronger than the brief states: **11 of 80**
Laplace tier-2 fits are `> 1`, i.e. worse than simply estimating zero.

**Does this invalidate the comparison, or only bound it?** It bounds it, in a specific way:

- The precondition exists to stop `d ≈ 0` being read as equivalence. `d` here is large and
  one-directional, so that specific error is not being made.
- But because *neither* arm recovers tier 2 to the stipulated standard, the finding is **"VA's
  non-recovery is worse than Laplace's non-recovery"**, not "Laplace recovers and VA does not."
  The campaign's framing ("does structured VA recover the phylogenetic tier better than Laplace")
  presupposes a recovery regime that this grid never reached.
- Combined with §1, the tier-2 contrast is a comparison between two failure modes, on two
  different scales, in a regime where the target is not identified well by either engine.

---

## 6. Attack 5 — scope

The brief's stated scope limits are correct as far as they go (gaussian VA arm, T=10, N≤1000, not
Ayumi's 5397×probit), but **understate the gap**, because "gaussian" was never a property of the
*cell* — only of the VA arm (§1). `PILOT-FINDINGS.md:584` records "**Gaussian**, not Ayumi's
probit" as a *designed scope limit*; in fact the Laplace arm remained probit throughout, so the
design is not "gaussian", it is **mixed-family**, which is not a scope limit but a confound.

What the evidence is actually a verdict about: *the current VA prototype, mis-specified as a
gaussian identity-link model on standardized binomial counts, fit through an unseeded DLL under a
40-way fork, with its admission gate bypassed, at N≤1000, T=10, on a structured phylo tier that
neither engine recovers to the stipulated standard.* It does not transfer to Ayumi's regime, and it
does not transfer to a like-for-like engine comparison.

---

## 7. Attack 6 — mean vs median

For a paired contrast with this tail (VA tier-2 max 61.5, 9 exact collapses), the **median and the
sign test are the right summaries** and the mean/2·MCSE framing is the weaker one: the two
INDETERMINATE cells are indeterminate only because runaways inflate the SE. Under medians the
direction is uniform across all four cells; under the sign test it is p = 4.17e-07.

**So the choice does not change the answer — it makes the measured direction stronger.** That is
worth stating plainly because it removes attack 6 as a defence: the verdict does not fall to a
summary-statistic quibble. It falls to §1 and §2, which no summary statistic can repair.

---

## 8. The `Sigma_B` distribution of VA's surviving values

All 27 surviving VA tier-2 values, sorted:

```
1.000 ×9   1.899  3.365  4.199  4.749  5.061  5.578  6.721  7.368  8.520
9.768 10.618 13.189 16.883 23.835 26.439 30.609 59.917 61.541
```

**Not one value is below 1.0.** `rel_frob(0, Σ) = 1` exactly (verified, `rose-adv-estimand.R`), so
the nine at 1.000 are collapses to zero, and the other 18 are all worse than estimating nothing.
Against VA's own floor of ~0.70, **every surviving fit is degenerate**. This is the part of the
campaign that is real and should be kept — as a statement about the VA prototype's current state on
a structured tier, not as a comparison.

---

## 9. PR #919 — the unconstrained loadings diagonal: NOT a problem for this campaign

Checked on `origin/main` (`e45a11fb`, "docs: the loadings diagonal is unconstrained — correct the
claim everywhere"; between `ff70b5e8` #918 and `dbd0b2d5` #920). **It does not change what
`Sigma_B = Lambda Lambda'` means, and it does not invalidate a relative-Frobenius comparison of two
`Sigma_B` estimates.**

- #919 is **docs/comments only** — 7 files, no `R/` or `src/` changes. It corrects a false claim in
  `docs/design/04-random-effects.md:128-131` that Λ is parameterised with a **positive diagonal**
  via `exp()`. The engine writes the packed value straight in (`src/gllvmTMB.cpp:902,909`), so the
  diagonal is **unconstrained** and Λ carries a residual discrete **sign/reflection** indeterminacy
  (2^K modes) on top of the rotation that the lower-triangular zeros already fix.
- The affected object is **Λ itself**, not `Λ Λ'`. #919's own new text states: the quantities the
  package gates on "are all sign-invariant and therefore unaffected: Σ_unit, correlations,
  communalities, and ICC. What *is* affected is Λ itself — individual loadings are sign-arbitrary."
  This is forced algebraically: `(ΛQ)(ΛQ)' = ΛΛ'` for any orthogonal `Q`, sign flips included.
- The repo already relied on this **before** #919 and in files #919 did not touch, e.g.
  `dev/aghq-r-reference.R:166-168` — relative Frobenius is used precisely because it "is computed
  on Sigma = Lambda Lambda' and never on Lambda".
- The VA and Laplace routes use the **same** Λ convention (unconstrained diagonal);
  `docs/design/85-highdim-nongaussian-va-formal-contract.md` §6 had already flagged the Design-04
  error and pinned the VA prototype to the engine's actual convention. Λ's **scale** is pinned by
  the spherical `N(0, I_K)` latent-score prior, so it is not a free symmetry either.

**Conclusion: the estimand and the metric are sound; #919 raises no objection to this campaign.**
The scale problem in §1 is a separate and more basic one, and is *not* an identifiability issue —
it is that the VA arm was fitted to a differently-transformed response, so its `Λ Λ'` lives on an
attenuated scale. Whatever `Λ Λ'` means, the two arms are not estimating the same one here.

One adjacent caveat worth carrying, pre-existing and untouched by #919
(`R/extract-sigma.R`, ~lines 458-486): the `"shared"` vs `"unique"` partition is *"only weakly
identified … different optimiser starts can flow trait t's variance more into the shared or unique
component, with the same total likelihood."* The campaign scores `part = "shared"` (`Λ Λ'` alone),
so some of VA's tier-2 spread may be shared/unique reallocation rather than misfit. This does not
rescue values of 10-60, but it is a further reason not to read the tier-2 magnitudes literally.

---

## 10. What the claim should be narrowed to

**Publishable sentence:**

> In a mixed-family pilot (N ≤ 1000, T = 10, q ∈ {1,2}, 20 seeds) the VA prototype produced
> degenerate estimates of the structured phylogenetic tier in every fit that returned — nine of 27
> collapsed to zero and the remaining 18 exceeded the error of estimating nothing, a pattern that
> multi-start does not repair and that the engine's own health gate rejects — so the prototype does
> not currently recover a structured phylo tier. The pilot does **not**, however, support a
> comparison against the Laplace engine: the two arms were fitted under different response models
> with different achievable error floors (so a perfect VA would have "lost" in three of four cells),
> and the VA arm's non-completions trace to an unseeded TMB DLL under a 40-way fork rather than to
> the estimator.

**What must NOT be said:** "Laplace recovers the two-tier `Sigma_B` better than VA"; "Laplace is 8×
better on tier 1" (this reverses under floor correction); "VA completes only 34% of fits"; or
anything of the form "VA cannot do structured phylogenetics".

**Decision recommendation on Stages 3/5.** This evidence **cannot** retire ~7 days. But neither
does it clear VA. The correct next move is a **corrected re-run, roughly one day, not seven**:

1. Use the harness's own `.d108_fit_va()` (`harness.R:280`) — `family = "binomial_probit"`, raw
   `y` — so both arms fit the same model and both floors are 0.
2. Seed the DLL per worker via `.d108_build_va_r3_dll_stash()` / `.d108_seed_va_r3_dll()`
   (`harness.R:103-110`), or drop `mc.cores` to 1 for a subset.
3. Log the failure *reason*, not `NA` — the campaign's single most costly omission.
4. Record `status` / `admitted`; do not score `failed_health_gate` fits silently.
5. Reach an N where tier 2 is informative for *both* arms, or state that the comparison is
   suspended until one exists.

Only after (1)-(2) does a "VA vs Laplace" sentence become available at all. **Retiring the arc on
the present evidence would be retiring it on a confound.**

---

## 11. Unresolved / honest limits

- **I could not verify the Totoro-side copies.** The grid sourced `harness.R`/`dgp.R` from
  `$D108_ROOT` on Totoro; I read this worktree's copies, which are committed and unmodified
  (`git status` clean for `harness.R`, HEAD `c20fb681`). If the Totoro copies differed, §1 would
  need re-checking. I judge this unlikely but it is not verified.
- **The DLL-race mechanism is inferred, not directly observed.** What is *observed* is that 3/3
  `NA` cells complete single-threaded, that the campaign bypassed the documented per-worker DLL
  protocol, and that the surviving arm needed no per-worker compile. I did not reproduce the
  failure under a 40-way fork to catch the error text. The conclusion "harness property, not VA
  property" rests on the reproduction, which is solid; the *specific* mechanism is the best-supported
  explanation, not a measured one.
- **The oracle-floor calculation is a linearization.** `k_t` is the best linear coefficient of the
  standardized response on `eta`; a gaussian-identity fit is not guaranteed to attain exactly
  `D Σ D`. The floor is therefore an estimate. But it is ~0.70-0.78 across all 80 cells with little
  spread, and the qualitative conclusions (tier-1 reversal; 3/4 cells unwinnable) hold for any floor
  above ~0.19 (tier 1) / ~0.56-0.76 (tier 2), so they are not sensitive to the approximation.
- **The `n_starts = 4` re-run is reported in §12** and does not change the verdict.

---

## 12. The `n_starts = 1` sub-attack FAILS — multi-start does not rescue VA

The brief flags `n_starts = 1` and "unrefined starting values" as candidate explanations for VA's
poor numbers. **They are not.** Re-running the same four cells at `n_starts = 4` (the harness's own
`.d108_fit_va` default, `harness.R:281`):

| N | q | seed | `n_starts = 1` | `n_starts = 4` | change |
|---|---|---|---|---|---|
| 500 | 1 | 1 | 1.000000 | 1.000000 | identical |
| 500 | 1 | 2 | 1.000000 | 15.905192 | **worse** (collapse → runaway) |
| 500 | 1 | 3 | 9.193294 | 9.193337 | identical to 5 s.f. |
| 500 | 1 | 4 | 16.534597 | 16.534597 | identical |

Cost: 257-283 s vs 60-83 s (≈4×), for no improvement. Two cells reproduce to machine precision,
one is unchanged, and one degrades. **The degeneracy is not a starting-value artifact.**

Two further observations:

1. Seed 2 moving from an exact zero-collapse to a runaway of 15.9 under a different start is direct
   evidence that **collapse and runaway are two faces of one badly-behaved surface**, not two
   distinct failure modes.
2. **All four fits returned `status = failed_health_gate` even at `n_starts = 4`.** At 4 starts this
   is no longer the by-construction bypass described in §2 — it means fewer than three starts were
   healthy, or they failed to agree to 1e-6 (`R/va-r3-proto.R:2148-2156`). The engine's own
   admission gate genuinely **rejects** these fits. That is a real engine-side signal.

**Caveat on (2):** this is still the mis-specified gaussian-on-standardized-counts model of §1, and
a mis-specified likelihood can have a pathological surface for reasons that have nothing to do with
the VA approximation. The health-gate failure is therefore genuine but **not yet attributable** to
VA rather than to the specification. The corrected re-run in §10 is what would separate them.

**Net effect on the verdict:** this section *strengthens* the single-arm finding (VA's structured
tier-2 estimates are degenerate, and not for want of starts) while leaving §1 and §2 — which are
what defeat the comparative claim and the completion claim — untouched.

---

# APPENDIX — second, independent adversarial panel (2026-08-03, later session)

**Why this exists.** A later session, rehydrating from
`docs/dev-log/handover/2026-08-03-claude-handover.md`, found this file absent from
`origin/claude/d108-recovery-campaign` and re-dispatched the review as **five fresh adversaries
in independent contexts** — selection/survivorship, degeneracy accounting, informativeness
precondition, estimand + DGP, and decision generalisation — each with a default of NOT-HOLDING.
The original review then landed mid-session. Both panels are retained.

**All five returned REFUTED, and they converge with §§1–12 above.** The convergence is
evidentially meaningful: the **scale mismatch (§1)** was found independently by two of the five,
and the **collapse-scored-as-success defect (§8)** by a different two — none of whom could see
this document or each other.

Below are only the findings **not already covered above**.

## A1. PROTOCOL violation — the mandated `d_prop` metric was never used

`PROTOCOL.md:894` (Orchestrator Decision 1, 2026-08-02) states: *"The pilot must report
`SD(d_prop)`, **not** `SD(d)` in raw `rel_frob` units."* §2 of PILOT-FINDINGS reports raw `d`
only. On the mandated scale, mean `d_prop` = −3.418 / −12.832 / −17.673 / −40.688 and **all four
2·MCSE bands exclude zero**: [−6.31, −0.52], [−20.23, −5.43], [−35.23, −0.12], [−79.07, −2.31].

**The INDETERMINATE verdict exists only on the metric the protocol explicitly forbade.** (This is
independent of §1 — it says the *reported* analysis was not the *specified* analysis. §1 still
governs whether either analysis is interpretable.)

## A2. The 2·MCSE band is the wrong instrument, and it produces a FALSE POSITIVE

At n = 6, `2·SE` has normal-theory coverage **0.898**, not 0.95 (`2*pt(2,5)-1`); the correct
multiplier is `t(5,.975) = 2.571`.

**N=500 q=1's "Laplace better" verdict rests on a lower bound of 0.004.** With the correct
`t(7,.975) = 2.365` the band is **[−0.415, 5.019] — it includes zero.** That verdict does not
survive its own method applied correctly.

This *adds* to §7: §7 shows the median/sign-test framing makes the direction stronger; A2 shows
the mean/2·MCSE framing was also mis-calibrated in the other direction. Skew is 0.45–1.30 and one
observation carries 43–52% of each cell's sum.

## A3. The 0.5 gate's cited ancestry does not exist

`PROTOCOL.md:69-73` claims: *"`dev/design108-stage8/analyse-silent-divergence.R` lines 78–85
already implements this gate exactly — reused verbatim."* Those lines contain **no `rel_frob` gate
at all** — they are a silent-divergence *rate* check — and `grep -c "0\.5"` over that entire file
returns **0**. Its only `rel_frob` threshold is `degenerate := rel_frob > 10`, twenty times larger
and a different construct.

So the level's only real referent is a function default (`harness.R:662`,
`rel_frob_gate = 0.5`) which *is* the level. **Circular, with a false external citation.**

## A4. The precondition IS satisfiable — the design was fixable, not doomed

§5 establishes the precondition fails. It does not establish whether it *could* have been met.
It could: the campaign's own `pilot-results/job1b_floor_corrected.rds` — same DGP, same estimand,
same N, but **T = 20** — gives tier-2 medians **0.460 / 0.416 / 0.382 / 0.449**, clearing 0.5 in
**all four cells**. At replicate level, **17 of 80 Laplace fits already clear 0.5** (6/20, 6/20,
3/20, 2/20).

So "no arm achieves acceptable tier-2 recovery" is an artifact of applying the precondition to a
**20-seed median**, whereas its first use (`PILOT-FINDINGS.md:126-138`) applied it **per (N, seed)** —
the granularity changed between the document's two uses of its own gate. `:584` lists "T=10, not
20–30" as a scope limit without noticing that **T=20 is exactly where its own control cleared the
gate it then declares unmeetable.**

*Caveat:* job1b's arm is `gaussian_control`, which replaces the response with
`eta_true + rnorm(n, 0, gauss_sd)` (`harness.R:472-473`) — it observes eta almost directly. It
proves the planted signal is recoverable in principle; it does not prove the probit Laplace arm
reaches 0.5 at T=10.

**Consequence for planning:** a corrected re-run (§10) should raise T, not only fix the arms.

## A5. The "~7 days" denominator is itself wrong by 3–5×

§10 concludes this evidence cannot retire ~7 days. Stronger: **the 7-day figure is inflated and
self-contradicted.** It is sourced to one sentence
(`docs/dev-log/handover/2026-08-02-claude-handover-gate-a-closed.md:156`) and has **no derivation
anywhere** — searched `docs/`, full history via `git log --all -S`, and `~/.claude/plans/`. Both
governing documents cost the stages at **1.5–2.5 d**:

| source | Stage 3 | Stage 5 | sum |
|---|---|---|---|
| `docs/design/108-va-parity-programme.md:195,197` | **0.5 d** | **1–2 d** | **1.5–2.5 d** |
| the same handover, `:164,:157` | **0.5 d** | **1–2 d** | **1.5–2.5 d** |
| the decision's denominator | — | — | **~7 d** |

A two-day agent campaign plus an 80-cell Totoro grid was spent to avoid 1.5–2.5 days of
implementation. The arithmetic was never done, and the inflation runs in the direction that makes
cancellation attractive. Stage 3 is **0.5 d and EXACT** — cheaper to implement than to keep
debating.

## A6. Reproducibility — the driver is not in the repository

`campaign_grid.csv` was produced by `/private/tmp/totoro_grid.R`, **untracked scratch, not in the
worktree**. No number in the "THE CAMPAIGN'S ANSWER" or "TOTORO GRID" sections can be re-derived
from the repository as committed — and the arm specification that §1 shows to be defective is
precisely what is missing. **Action: commit the driver.** (This is adjacent to §11's honest limit
about the Totoro-side copies, but distinct: the *driver itself* is unversioned.)

## A7. The positive-control gate reads the wrong column

`harness.R:506-517` added `S1L`/`S2L` to the control specifically so its `rel_frob` would not be a
silent `NA` and "the control gate" would not "pass VACUOUSLY". But
`.d108_positive_control_gate()` (`harness.R:664-667`) filters on `rel_frob_tier1` /
`rel_frob_tier2` — the **total** columns — and never touches `rel_frob_loadings_tier*`, which
`harness.R:566-567` names as the PROTOCOL estimand that "the analysis reads". **The fix is not
consumed by the gate it was written to protect.**

## A8. The medians line mixes denominators and re-orders cells

VA medians are over n = 8/7/6/6; the Laplace medians printed beside them are over **all n = 20** —
an unpaired comparison inside a paired section. The paired-subset Laplace medians are
0.655 / 0.751 / 0.528 / 0.614 and do not match the reported figures. The line is also in q-major
order while the table three lines above is N-major, so a reader matching positionally mis-assigns
the two middle cells in both arms.

This repeats the document's own recorded lesson at `:359-361`: *"Any rate computed with
`na.rm = TRUE` needs its denominator reported beside it."*

## A9. Checked and CLEAN — recorded so no one re-audits these

- **DGP Kronecker structure.** `dgp.R:154-156` draws one GMRF column per trait over the same
  `Ainv`, scaled per trait — covariance `diag(psi2_base) ⊗ A`, i.e. `Ψ_phy ⊗ A`. **The earlier iid
  bug has NOT recurred.** Verified numerically: `solve(Ainv)[tips,tips]` matches
  `ape::vcv(tree, corr=TRUE)` to `max |Δ| = 4.7e-14`, unit tip marginals to `4.7e-14`.
- **All 16 `score()` pairings inside `run_cell()`** (`harness.R:595-645`) pair total-with-total and
  loadings-with-loadings across the gllvm control, Laplace, VA-augmented and VA-tips-only arms.
  **No crossing.** `part="shared"` confirmed to be `Λ_phy Λ_phy'` and `part="total"` to add
  `diag(sd²)` (`R/extract-sigma.R:1236-1246`).
- **Tier index arithmetic.** Tiers are 1 = ordinary dense, 2 = ordinary ψ, 3 = phylo dense,
  4 = phylo ψ; `.d108_va_tier_sigma(par, layout, 3L, 4L, T0)` reads the **phylo** tier correctly.
  Offsets verified (`R/va-r3-proto.R:576-587, 608-609`); `harness.R:188-189`'s `stopifnot` fails
  closed on any reordering that changes tier kinds.
- **The PR #919 estimand question** — independently re-derived, agreeing with §9. `ΛΛ'` is exactly
  invariant under a column sign flip (`S = diag(±1)`, `SS' = I_q` since `s_k² = 1`) and under any
  orthogonal `Q`: `(ΛS)(ΛS)' = ΛSS'Λ' = ΛΛ'`. Confirmed over all `2^q` modes at T=6, q=3 —
  difference **exactly 0** (not rounding); general `Q` to 1.78e-15. The sign group is precisely the
  *diagonal* subgroup of an invariance the estimand already enjoys over all of `O(q)`.
- **Selection/survivorship**, tested independently and **negative**, matching §3: Laplace tier-2
  error on VA-success seeds 0.6762 vs VA-failure seeds 0.7153, Wilcoxon p = 0.863.

## A10. Panel conclusion

Nothing in the second panel overturns §§1–12; it **corroborates** them from independent contexts
and adds A1–A8 as further defects and A9 as a clean bill on four things worth not re-auditing.

The publishable sentence at §10 stands. So does its decision recommendation: **a corrected re-run
of roughly one day** — fixing the arms (§1), seeding the DLL per worker (§2), logging failure
reasons, recording `status`/`admitted`, **and raising T (A4)** — not a seven-day cancellation of
work that its own design doc costs at 1.5–2.5 days (A5).
