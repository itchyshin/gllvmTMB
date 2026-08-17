# Design 121 pre-run test — RESULTS

**Status: pre-run test only, per D-139. Not the full ~2,400-fit campaign, and
no promotion decision follows from this document.** 48/48 fits completed
(2 seeds x 8 cells x 3 primary arms; arm D excluded, per the design's own
scope). Script: `dev/coxreid-prerun/run-prerun.R`. Raw output:
`dev/coxreid-prerun/prerun-results.csv`, `dev/coxreid-prerun/prerun.log`.

## Corrections to the pre-registered spec, found while building this

1. **`aghq_ridge = 0` is invalid.** The task brief and Design 121 §2 both name
   `aghq_ridge = 0` as the "ridge off" control value. The package's live
   validator (`.gllvmTMB_normalize_aghq_ridge`, `R/aghq-auto-ridge.R:8-20`)
   requires a **positive number, `Inf`, or `"auto"`** — `0` aborts outright
   (this was the smoke test's first failed attempt, reproduced verbatim
   below). **`Inf` is used throughout instead** — it is the package's actual
   "ridge off" sentinel and exactly what
   `tests/testthat/helper-aghq-golden.R`'s `.golden_aghq_control()` uses to
   run AGHQ unpenalised. Design 121 §2's own ridge paragraph needs this
   correction before any full run.
2. **Formula deviation from the task's literal text.** The task brief wrote
   `latent(0 + trait | site, d = 1)` (no `unique =` argument), which would
   default to `unique = TRUE` (Lambda + diagonal Psi) per the package's
   Psi-by-default rule. This pre-run used
   `latent(0 + trait | site, d = 1, unique = FALSE)` instead — the exact
   loadings-only pattern from `tests/testthat/helper-aghq-golden.R`'s
   `.golden_formula_q1`, which is also the formula underlying the
   `dev/aghq-evidence/` norm-ratio convention this design's own §1 cites.
   The DGP below has no idiosyncratic per-trait noise beyond the response
   family's own, so fitting a Psi the DGP does not contain would invite
   Heywood cases unrelated to the Cox-Reid question under test.

## Smoke test (D-139)

binomial, T=4, n=100, arm A, seed 1: **wall 1.18 s, `norm_ratio` = 0.8423
(finite)**. Passed; proceeded to the full 48-fit grid.

(First attempt, before the `aghq_ridge` correction above, aborted inside
`gllvmTMBcontrol()` with `"aghq_ridge must be a positive number, Inf, or
'auto'"` — recorded here rather than silently discarded, since D-139 treats a
smoke failure as a reportable event.)

## Full 48-fit table

| Family | T | n | Arm | Seed | Converged | Wall time (s) | Latent-SD bias (%) | Notes |
|---|---|---|---|---|---|---|---|---|
| binomial | 4 | 100 | A | 1 | yes | 1.0 | -15.8 |  |
| binomial | 4 | 100 | A | 2 | yes | 0.3 | +28.2 |  |
| binomial | 4 | 100 | B | 1 | yes | 0.4 | -11.8 | REML honesty warning |
| binomial | 4 | 100 | B | 2 | yes | 0.4 | +32.0 | REML honesty warning |
| binomial | 4 | 100 | C | 1 | **NO** | 7.8 | +39.9 | not converged |
| binomial | 4 | 100 | C | 2 | **NO** | 6.2 | +39.3 | not converged |
| binomial | 4 | 200 | A | 1 | yes | 0.7 | -13.7 |  |
| binomial | 4 | 200 | A | 2 | yes | 0.6 | -7.0 |  |
| binomial | 4 | 200 | B | 1 | yes | 0.6 | -12.1 | REML honesty warning |
| binomial | 4 | 200 | B | 2 | yes | 0.7 | -5.6 | REML honesty warning |
| binomial | 4 | 200 | C | 1 | yes | 5.1 | +4.2 |  |
| binomial | 4 | 200 | C | 2 | **NO** | 53.8 | +4.8 | not converged |
| binomial | 8 | 100 | A | 1 | yes | 1.1 | +16.5 |  |
| binomial | 8 | 100 | A | 2 | yes | 1.2 | **+669.0** | runaway-loading warning fired |
| binomial | 8 | 100 | B | 1 | yes | 1.0 | +20.7 | REML honesty warning |
| binomial | 8 | 100 | B | 2 | yes | 1.1 | **+671.8** | REML honesty warning (runaway not re-flagged — session-once) |
| binomial | 8 | 100 | C | 1 | yes | 4.9 | +25.6 |  |
| binomial | 8 | 100 | C | 2 | yes | 6.4 | +96.6 |  |
| binomial | 8 | 200 | A | 1 | yes | 1.5 | -11.5 |  |
| binomial | 8 | 200 | A | 2 | yes | 1.7 | +11.7 |  |
| binomial | 8 | 200 | B | 1 | yes | 1.5 | -10.4 | REML honesty warning |
| binomial | 8 | 200 | B | 2 | yes | 1.7 | +13.1 | REML honesty warning |
| binomial | 8 | 200 | C | 1 | yes | 7.3 | -7.9 |  |
| binomial | 8 | 200 | C | 2 | yes | 18.3 | +17.4 |  |
| ordinal_probit | 4 | 100 | A | 1 | yes | 8.9 | -32.2 |  |
| ordinal_probit | 4 | 100 | A | 2 | yes | 4.0 | +45.4 |  |
| ordinal_probit | 4 | 100 | B | 1 | yes | 4.4 | -30.6 | REML honesty warning |
| ordinal_probit | 4 | 100 | B | 2 | yes | 4.4 | +47.8 | REML honesty warning |
| ordinal_probit | 4 | 100 | C | 1 | yes | 15.0 | -29.1 |  |
| ordinal_probit | 4 | 100 | C | 2 | **NO** | 34.6 | +51.0 | not converged |
| ordinal_probit | 4 | 200 | A | 1 | yes | 7.9 | -2.3 |  |
| ordinal_probit | 4 | 200 | A | 2 | yes | 6.5 | +6.6 |  |
| ordinal_probit | 4 | 200 | B | 1 | yes | 8.7 | -0.8 | REML honesty warning |
| ordinal_probit | 4 | 200 | B | 2 | yes | 7.7 | +7.4 | REML honesty warning |
| ordinal_probit | 4 | 200 | C | 1 | **NO** | 82.6 | +10.2 | not converged |
| ordinal_probit | 4 | 200 | C | 2 | yes | **301.8** | +9.6 |  |
| ordinal_probit | 8 | 100 | A | 1 | yes | 10.4 | -15.7 |  |
| ordinal_probit | 8 | 100 | A | 2 | yes | 9.3 | +25.4 |  |
| ordinal_probit | 8 | 100 | B | 1 | yes | 11.1 | -14.5 | REML honesty warning |
| ordinal_probit | 8 | 100 | B | 2 | yes | 10.3 | +26.8 | REML honesty warning |
| ordinal_probit | 8 | 100 | C | 1 | yes | 42.2 | -15.0 |  |
| ordinal_probit | 8 | 100 | C | 2 | **NO** | 61.6 | +26.5 | not converged |
| ordinal_probit | 8 | 200 | A | 1 | yes | 19.3 | -7.3 |  |
| ordinal_probit | 8 | 200 | A | 2 | yes | 19.3 | +14.3 |  |
| ordinal_probit | 8 | 200 | B | 1 | yes | 23.3 | -6.7 | REML honesty warning |
| ordinal_probit | 8 | 200 | B | 2 | yes | 19.8 | +14.9 | REML honesty warning |
| ordinal_probit | 8 | 200 | C | 1 | yes | **345.1** | -6.8 |  |
| ordinal_probit | 8 | 200 | C | 2 | **NO** | 125.6 | +15.4 | not converged |

Every arm-B row correctly fired the Design 121 §7 REML honesty warning
(`"Non-Gaussian REML = TRUE is EXPERIMENTAL and UNVALIDATED"`) — 16/16, as
expected. No arm's control was structurally rejected by `gllvmTMB()`; the
`error` column of `prerun-results.csv` is empty on every row (`aghq_ridge =
Inf` combines cleanly with both `allow_nongaussian_reml = TRUE` and `aghq =
7`).

## Convergence — a primary pre-run finding

| Arm | Converged | Rate |
|---|---|---|
| A (Laplace-ML) | 16/16 | 100% |
| B (Laplace + Cox-Reid) | 16/16 | 100% |
| C (AGHQ-ML, k=7, ridge off) | **9/16** | **56.25%** |

Arm C's convergence rate is **below the design's own 70% cell-level
threshold** (§3, "Non-convergence rule"). Per-cell (2 seeds each, so each
cell reads as 0/2, 1/2, or 2/2 — noisy but the pattern is consistent):
binomial T4n100 0/2, ordinal T4n100 1/2, binomial T8n100 2/2, ordinal T8n100
1/2, binomial T4n200 1/2, ordinal T4n200 1/2, binomial T8n200 2/2, ordinal
T8n200 1/2. Six of eight arm-C cells are at or below 50% in this 2-seed
sample. **This is itself the headline finding of this pre-run**: AGHQ at
`k=7` with the ridge off (`aghq_ridge = Inf`) does not reach usable
convergence reliability at this scale in either family, and any full-run
approval should either raise the arm-C seed budget specifically to
characterise this properly, revisit `k`, or accept that arm C's bias
comparison in the full run will run on a shrunken, self-selected subset of
seeds (§3's stated risk — "arm B enlarges the random block and may fail more
often than A" was the anticipated direction; the pre-run instead found the
*AGHQ* arm the least reliable one).

## A reproducible runaway/degenerate cell, orthogonal to the arm

**binomial, T=8, n=100, seed=2** produced `norm_ratio` ~7.7 (bias +669% /
+672%) in **both** arm A and arm B, converged = TRUE in both, with the
package's own `warn_runaway` diagnostic firing once (session-scoped, so it
did not re-fire on the second occurrence of the same pathology). Arm C on
the *same* cell/seed gave a far smaller ratio (1.97, +96.6%) — still elevated
but not runaway-scale. This looks like a seed-specific degenerate/
quasi-separated optimum that Laplace (arms A, B) lands in but AGHQ's
different search path avoids **for this one cell** — not evidence about
Cox-Reid specifically, since it hits arms A and B identically. It is exactly
the "converged, unflagged, degenerate fit enters the bias average silently"
risk that Design 121 §3 names for `ordinal_probit` (no degeneracy detector,
#897); here it shows up on **binomial**, which does have a runaway detector,
and the detector still only caught it once due to the per-session warning
cap. **Binomial arm-A/B mean bias figures below are dominated by this one
seed** — medians and an outlier-excluded mean are reported alongside for
this reason.

## Per-arm mean bias by family

Bias % = 100 x (`norm_ratio` - 1); computed over converged fits only (n = 4
per cell except where arm C's convergence failures thin the count — see
convergence section above for exact per-arm-family denominators: A and B
are 8/8 per family, C is 5/8 binomial and 4/8 ordinal_probit).

| Family | Arm | Mean bias % | Median bias % | Mean bias %, T8n100 binomial cell excluded |
|---|---|---|---|---|
| binomial | A | +84.7 | +2.4 | -1.3 |
| binomial | B | +87.2 | +3.8 | +0.9 |
| binomial | C | +27.2 | +17.4 | +4.6 |
| ordinal_probit | A | +4.3 | +2.2 | (n/a — no outlier cell) |
| ordinal_probit | B | +5.5 | +3.3 | (n/a) |
| ordinal_probit | C | -10.3 | -10.9 | (n/a) |

The mean columns for binomial A/B are not usable as a point estimate at this
seed count — they are one degenerate fit away from any other number. The
median and outlier-excluded columns read more sensibly and both show A and B
close together (as expected: at just 2 seeds, small effects are not
separable from noise) and C landing lower for ordinal_probit but higher for
binomial. **None of this should be read as adjudicating K1** — see the MCSE
caveat below.

**K1 (informal, non-adjudicating) read.** Using the more robust median
figures: arm B vs A point-bias difference is +1.4pp (binomial) and +1.2pp
(ordinal_probit) — both under the design's 2pp K1 threshold, but this is a
**2-seed sample against a threshold the design's own §3 says needs ~100
seeds to clear 2x MCSE**; this pre-run cannot adjudicate K1 and does not
attempt to.

## Per-cell seed-to-seed spread (crude 2-seed MCSE signal)

`|norm_ratio(seed 2) - norm_ratio(seed 1)|` per cell x arm (full list in
`prerun-results.csv`; the extremes):

- **Largest spread:** binomial T8n100 arm A/B, `|diff|` = 6.53 / 6.51 —
  entirely the runaway-cell artefact described above, not sampling noise in
  the ordinary sense.
- **Typical spread away from that cell:** 0.005-0.80, with most cells in the
  0.05-0.45 range (e.g. binomial T4n200 arm C = 0.005, ordinal T4n100 arm B
  = 0.78). Even excluding the runaway cell, spreads of 0.4-0.8 on a
  `norm_ratio` scale centred near 1.0 are large relative to the design's
  2-3pp kill-criterion thresholds — consistent with §3's own warning that 2
  seeds cannot clear 2x MCSE for any of K1/K2/K4. This pre-run does not
  attempt to raise the seed count; it reports the spread as instructed.

## Total wall time

- **Full 48-fit loop: 1,308.4 s = 21.82 min** (script's own timer;
  `sum(wall_time_s)` in the CSV agrees at 1,309.2 s).
- Range per fit: **0.33 s to 345.1 s** (both extremes were arm C /
  `ordinal_probit`, `T=8`, `n=200`: 345.1 s at seed 1 (converged), 125.6 s at
  seed 2 (not converged)).
- Mean per-fit: 27.3 s; median: 6.9 s.
- **By arm — mean / max wall time (s):**

  | Arm | Mean | Max |
  |---|---|---|
  | A (Laplace-ML) | 5.9 | 19.3 |
  | B (Laplace + Cox-Reid) | 6.1 | 23.3 |
  | C (AGHQ, k=7, ridge off) | **69.9** | **345.1** |

  Arm C is ~12x slower than arms A/B on average, and its worst cell
  (`ordinal_probit`, `T=8`, `n=200`) is the single dominant cost driver.

## Updated full-run (2,400-fit) wall estimate

Design 121 §4's assumption was **5-15 s/fit, giving 3-10 hours sequential**
for ~2,400 fits. That assumption **held for arms A and B** (measured means
5.9 s and 6.1 s) but **does not hold for arm C** (measured mean 69.9 s, up to
345.1 s at the worst cell).

Per-arm-weighted estimate, using each arm's measured mean x 800 fits/arm
(8 cells x 100 seeds):

- Arm A: 800 x 5.86 s = 4,686 s (1.3 h)
- Arm B: 800 x 6.07 s = 4,856 s (1.3 h)
- Arm C: 800 x 69.90 s = 55,920 s (**15.5 h**)
- **Total: ~65,462 s = ~18.2 hours sequential** (vs the design's stated 3-10 h
  assumption) — driven almost entirely by arm C, and arm C's own convergence
  failures (56.25% in this pre-run) mean a meaningful share of that 15.5 h
  buys non-converged rows, not usable bias evidence.

This is a **sequential-equivalent** figure per §4's own convention; under
Totoro parallelism (≤150 cores per D-143) elapsed wall time would be much
shorter, but the per-core allocation for this slice remains undecided
pending Shinichi's approval, unchanged from §4's original framing.

## Bottom line for the Section 4 gate

Two things should be reported to Shinichi before any full-run approval,
neither of which the pre-run text anticipated:

1. **The full run is ~18.2 h sequential-equivalent, not 3-10 h**, entirely
   because of arm C (AGHQ, `k=7`, ridge off). Arms A and B alone match the
   original assumption closely.
2. **Arm C's convergence rate (56.25%) is below the design's own 70%
   cell-level bar** at this `k` and ridge setting. Before scaling to ~800
   arm-C fits, either the `k`/ridge choice for arm C should be revisited, or
   the full run should be scoped to accept a large non-convergent share
   for that arm as a documented finding in itself.
