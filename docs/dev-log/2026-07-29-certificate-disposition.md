# D-43 disposition — Gaussian `Sigma_unit` diagonal profile interval

**CERTIFY — 3 lenses reported, 0 withheld** (statistical CERTIFY/high, reproducibility CERTIFY,
claims CERTIFY). Rule: fewer than two withholds → CERTIFY.

**This authorises nothing by itself.** No register row moves, no `NEWS.md` text changes, no public
surface flips as a consequence of this panel. The panel's output is evidence that a correctly-worded
certificate *would be* supportable. **The flip is the maintainer's act, and only the maintainer's.**

## The result

| cell | coverage | n_reps | n_attempted | n_failed | 2·MCSE band | gate 0.94 |
|---|---|---|---|---|---|---|
| gaussian d1-n150 | 0.9467169 | 19,372 | 20,000 | 628 | **0.9434896** | clears |
| gaussian d2-n150 | 0.9467216 | 19,888 | 20,000 | 112 | **0.9435366** | clears |

Recomputed from raw by all three lenses independently: d1 91,699/96,860; d2 94,142/99,440.
180 shards, contiguous `20001:40000`, no gaps, no overlaps, 0 duplicate `(d, rep)`.

Chain of custody: pre-registration `8121f377` committed 10:44:35, run directory created 10:47:10 —
the pre-registration strictly precedes every byte of data. `dev/m3-grid.R` on Totoro is
sha256-identical to the committed post-fix version.

**The band is conservative, not liberal.** The rep-level MCSE (0.0016) is ~2.1× the honest
rep-clustered SE (0.00076); design effect 1.12, ICC ≈ 0.03. The gate was cleared with the wider
instrument.

## The scope sentence — adopted verbatim from the panel

> Under simulation from a known Gaussian data-generating process with n_units ≥ 150 and d ≤ 2, the
> **internal, unexported** profile route `.profile_ci_total_variance()` (χ²₁ profile on log V_t)
> produced **two-sided** intervals for the **diagonal** elements V_t = (ΛΛᵀ)[t,t] + ψ[t] of
> `Sigma_unit` meeting a **pre-registered ≥ 0.94 gate — not nominal 95%** (0.9467 in both cells;
> 2·MCSE lower bands 0.9435 / 0.9435; 20,000 replicates per cell), computed **among converged fits
> only (96.9% d1, 99.4% d2)**. It is a **marginal average** over the simulated V_t distribution and
> does **not** hold in the smallest-V_t decile/ventile (d1 0.9259, d2 0.9369 at the lowest ventile).
> The interval is **not equal-tailed** (upper-tail misses ≈1.53× lower), so **one-sided use is
> invalid**. The two cells **share 19,000 of 20,000 seeds** and are therefore not independent
> replicates of each other. The route is **not exported**; the exported `bootstrap_Sigma()` route
> for the same estimand covered at **0.78** in this campaign. No novelty is claimed (SAS PROC
> GLIMMIX `COVTEST … CL / TYPE=PLR`; Jennrich & Schluchter 1986).

## 🔴 The caveat that matters most to a reader

**The certified route is not reachable by users.** `.profile_ci_total_variance()`
(`R/profile-derived.R:813`) has no exported entry point; the harness reaches it via `gllvmTMB:::`.
The route a user *can* call for this estimand, `bootstrap_Sigma()`, covered **0.7774 (d1) / 0.7810
(d2)** in this same campaign.

So this certificate closes a gap in the *evidence* surface without closing it in the *capability*
surface. Any wording that omits this is, in the claims lens's phrase, "a lie by implication."

## NOT covered — the full list

binomial (fenced; ψ=0 boundary, 0.77–0.92) · n_units = 50, and everything between 50 and 150 ·
poisson, nbinom1/nbinom2, Gamma, Beta, tweedie, lognormal, student, truncated families,
betabinomial, delta/hurdle, ordinal, multinomial · off-diagonal `Sigma_unit` and all correlations ·
**the ψ target, which was measured on this same run and FAILS: 0.9384 (d1), 0.8653 (d2)** ·
`phylo_*` / `spatial_*` / `animal_*` / `kernel_*` / `meta_V` tiers · **nominal 0.95** (both cells sit
≈3.3 honest cluster SEs below it) · one-sided intervals and any test of V_t = 0 · d > 2 · **every
exported interval route** · the small-V_t sub-regime · non-converged fits (~3.1% d1, 0.6% d2 get no
guarantee) · **any real dataset — this is one DGP**.

## Findings recorded as binding conditions, not footnotes

1. **Cross-cell seed aliasing — a NEW defect, same class as the one that withheld v1.**
   `rep_seed = seed_base + 1000*d + 100000*family_index + r` is non-injective across `d`: v2-d1 rep
   `r` and v2-d2 rep `r−1000` share a seed. **19,000 of 20,000 seeds are shared between the two
   cells**, and RNG replay confirms d1's Λ is exactly column 1 of d2's Λ at a shared seed. Measured
   dependence: cor(truth) 0.43–0.60, cor(covered) 0.021–0.127. Per-cell MCSE is unaffected and no
   point estimate is biased, but **"both cells clear" is not two independent hurdles — roughly 1.1
   cells of corroboration, not 2.** *Required: offset the `d` multiplier before any future cell is
   added.*
2. **A residual accounting gap in a diagnostic row.** `wald_t_logsd` d2 reports `n_reps` = 19,888
   while coverage is computed over 19,730 reps' worth of rows (790 converged-but-CI-unavailable).
   **The certificate row is clean** — `profile_total` has zero `ci_failed` and zero unavailable rows
   in both cells, `n_reps` = rows/5 exactly — but this is the same defect class that withheld v1 and
   should be fixed.
3. **Fence 4 closed with v2-native evidence.** Failure is informative in true V_t (d1 6.75% → 1.15%
   across deciles, p < 2.2e-16), but IPW reweighting over 40 V_t strata shifts coverage by −4.2e-5
   (d1) and +1e-7 (d2); even the worst-observed-stratum bound leaves unconditional bands at 0.9426 /
   0.9434, still clearing. This no longer depends on v1's contaminated data.

## v1 → v2: legitimate correction, not seed-shopping

The panel ruled on this directly, because it is the obvious objection.

Seed-shopping is a *failing* attempt followed by a *passing* one. **v1 also passed arithmetically**
(bands 0.9447 / 0.9433). v2 was not run to convert a fail into a pass — it was run because v1's
number was measured on 75%-recycled data and therefore meant nothing. The withdrawal was reasoned on
the *mechanism*, not the number. The gate, band formula, cells, route and both-cells rule are
byte-for-byte unchanged; the pre-registration preceded the run directory; the code that ran is
sha256-identical to the committed version; and pre-registration v2 prohibits a third window. Both v2
point estimates land inside v1's pre-declared non-trigger interval, which is what an honest re-run of
a correct estimator should do.

**One correction to my own wording:** I described v2 as "20,000 datasets no prior run has seen."
That is true *within* each cell against its v1 counterpart, but 19,000 v2-d1 reps share an RNG
stream with v2-d2 and 1,000 with v1-d2. Nothing is byte-identical — the datasets genuinely differ
because `d` differs — so this qualifies the strength of the conjunction, not the freshness of either
cell.

## What the next session must not re-litigate

- **The disposition.** CERTIFY, 3-0. Do not reopen absent new evidence about the estimand under gate.
- **The gate.** 0.94, rep-level 2·MCSE band, both cells, `profile_total` on gaussian d ∈ {1,2},
  n=150. Not renegotiable in either direction — not relaxed, and **not retroactively tightened** by
  requirements no lens raised before the run. ("The route must be exported" was never in the gate;
  it binds the wording only.)
- **Both v1 defects.** Seed disjointness and failure accounting are verified fixed from primary
  sources by two lenses each. Settled.
- **The five fences**, now with v2-native support for 1, 2 and 4.

## Status of public surfaces — verified unmoved

`NEWS.md` "Known limitations" block md5-identical to `origin/main`; the validation-debt register
byte-identical; no commit on this branch touches `NEWS.md`, the register, or
`capability-surface.html`; `coverage_study()` and `check_identifiability()` remain unexported.
