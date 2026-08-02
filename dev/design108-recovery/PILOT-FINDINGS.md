# Design 108 recovery campaign — PILOT findings

Status: **Job 1 complete and analysed. Jobs 2–4 are ON HOLD** pending a separate adversarial
diagnostic into the finding below (an agent that did not build the harness is checking an
estimand/scale-convention mismatch, an `S_i`-vs-`Sigma_B` conflation, a genuine `q=1`
identifiability limit, a truth-extraction/`rel_frob` defect, and a diagonal-dominance metric
floor). **`SD(d)` and the N-ladder floor are NOT reported here and must not be inferred from
anything below — they are blocked on that diagnostic, not merely pending more seeds.**

Scripts: `dev/design108-recovery/pilot-results/job1_floor_sweep.R` (run; `job2_sd_d.R`,
`job3_tips_only_wall.R`, `job4_bridge.R` written but **not run**, per the hold). Raw per-cell
output: `dev/design108-recovery/pilot-results/job1_floor_sweep.{rds,csv}`,
`job1_full.rds` (LOCAL only, per D-50 — not committed, never a GitHub artifact).

Fixed pilot design (deliberately cheaper than the eventual campaign grid): `T = 20`
(PROTOCOL.md §Design grid's Part A floor trait count), `q = 1`, `lambda_sd = 0.7`
("mild" `sigma_lambda`), `n_trials = 6` (multi-trial — avoids the shipped engine's Bernoulli
Psi-identifiability skip caught while building the harness), `n_starts = 1`, `H = 15`
(cheapest admitted quadrature order — deliberate speed choices for calibration, not the
eventual grid's settings), `gauss_sd = 0.4` (PROTOCOL.md's proposed `gaussian_control`
residual SD). Job 1 fit the `gaussian_control` arm only (Laplace engine, identity link,
Gaussian response on the same realized `eta`) — no VA arm has been fit yet in this pilot.

---

## Headline: the positive control plateaus — it does not converge to truth

Design was: sweep N over {100, 250, 500, 1000} at T=20, q=1, 3 seeds each, fitting
`gaussian_control` only, and read the smallest N at which it recovers cleanly. **The intended
floor calibration did not produce a floor**, because the control's `rel_frob` does not trend
toward zero with N — it improves once (100 → 250) and then stalls:

| N | mean rel_frob tier 1 | mean rel_frob tier 2 | s/cell (mean) |
|---|---|---|---|
| 100  | 0.584 | 0.554 | 21  |
| 250  | 0.418 | 0.373 | 59  |
| 500  | 0.348 | 0.402 | 130 |
| 1000 | 0.394 | 0.419 | 280 |

Per-seed detail (12 rows) is in `dev/design108-recovery/pilot-results/job1_floor_sweep.csv`.

At N=1000, T=20 that is 20,000 observations estimating on the order of 40 parameters (per-trait
loadings/psi for two tiers); a consistent estimator's sampling error at that ratio should be
in the low single digits of percent, not 35–47%. **The control's error stops shrinking with N.
A plateau, not a decaying curve, is the signature of a systematic mismatch (the estimand
`rel_frob` compares, or the metric itself, does not track the recovery it is meant to measure)
— it is not the signature of finite-sample noise, which would keep shrinking.** This is treated
as a stop condition, not a data point to average over: the N-ladder floor this pilot was meant
to calibrate **cannot be set** until the plateau is explained, because "clean at N" was never
observed at any tested N — only "less bad."

**The degeneracy gate this campaign inherited from `analyse-silent-divergence.R`
(`rel_frob > 10 AND convergence == 0 AND pdHess == TRUE`) passes every one of these 12 cells**
(`rel_frob` never exceeded 0.82; `pdHess` was `TRUE` throughout; `convergence` was 0 in 5/12
rows and 1 in 7/12, with no visible relationship to `rel_frob`). That gate answers "did the fit
blow up," and the answer is no. It is silent on the question this campaign actually needs
answered — "did the fit land near truth" — where the honest answer at every N tested is "no,
not closely, and not improvingly." Both gates are reported here on purpose: passing the
degeneracy gate while failing the precision trend is exactly the gap non-negotiable 3 exists to
catch, and reusing only the inherited gate would have missed it.

**What this does NOT mean, stated so it cannot be misread downstream.** The design is paired
(non-negotiable 2): `d = rel_frob_VA − rel_frob_Laplace` is a within-seed, within-cell
difference, so a large *common* control error does not by itself prevent detecting a
VA-vs-Laplace *difference* — shared DGP-and-sampling noise cancels in `d` the way it does not
in either arm's raw `rel_frob`. **The control's plateau bounds ABSOLUTE claims** ("VA recovers
`Sigma_B` to within X of truth") **and does NOT automatically invalidate the PAIRED claim**
("VA recovers better than Laplace by `d`"). Conflating those two is the same class of error as
conflating `S_i` with `Sigma_B` (Design 109's own stated trap for this problem) — keep them
separate in every later write-up.

**But `SD(d)` is still blocked here, and deliberately not measured this round**, for a
different reason than the paired-cancellation argument above: if the plateau turns out to be an
**estimand mismatch** — `Sigma_hat` and `Sigma_true` denoting different objects, rather than the
same object measured noisily — then `rel_frob` is mis-specified for *every* arm, not just
`gaussian_control`, and `d` becomes a difference of two mis-specified quantities. Its `SD` would
then be a precise measurement of the wrong thing, and the whole grid would be sized off it. That
is why Job 2 (which measures exactly this `SD(d)`) is on hold pending the diagnostic, not run
opportunistically on the reasoning that pairing protects it — the reasoning only protects `d`
against *noise* cancelling, not against a *definitional* mismatch shared by both arms.

---

## Cost curve (feeds grid affordability regardless of how the diagnostic resolves)

Mean wall-clock per cell, `gaussian_control` arm only, Laplace/glm engine, T=20, q=1:

| N | mean s/cell |
|---|---|
| 100  | 21.5  |
| 250  | 58.8  |
| 500  | 130.3 |
| 1000 | 280.3 |

Log-log fit across all 12 rows: `elapsed_s ~ N^1.12` (`exponent = 1.119`, fit on individual
rows; `1.118` fit on the 4 per-N means — the two agree to 3 significant figures, so the
per-row scatter is not distorting the estimate). Ratio check: N=100→1000 is a 10x increase in N
against a **13.0x** increase in cost (`10^1.12 ≈ 13.2`, consistent); N=250→1000 (4x) gives
**4.76x** cost. **The scaling is mildly superlinear, not quadratic** — this is the
`gaussian_control`/Laplace arm only; VA and `va_tips_only` have not been timed in this pilot and
are expected to scale differently (Job 3 exists specifically to measure `va_tips_only`'s O(N²)
inner solve once unblocked).

At this exponent, a naive projection to N=5,000 (envelope floor) would be
`280.3 * (5000/1000)^1.12 ≈ 1,730 s` (~29 min) **per `gaussian_control` cell alone**, before
Laplace's substantive-family fit, before any VA arm, and before seed replication. This is a
projection from 4 points at small N, not a measurement at that N, and is reported only to make
clear that the eventual grid's affordability is not free even before the plateau is explained.

---

## Informativeness labelling (applied to what Job 1 already collected — no refit)

PROTOCOL.md's "GAP FOUND 2026-08-02 — the uninformative-cell trap" section defines
`INFORMATIVE := any(arm tier-2 rel_frob <= <stated level>)`, stipulating the level rather than
deriving it. **Important scope caveat: Job 1 fit only the `gaussian_control` arm** (by design,
to keep the floor sweep cheap) — Laplace and both VA arms have not been fit at any of these
cells yet. So the label below is a **single-arm proxy**, not the full precondition (which is
defined over the committed arm set); it will need re-deriving once Job 2's paired Laplace/VA
data exists for these cells. Stipulated level: **0.5** (matching the `rel_frob` gate already
used elsewhere in this pilot and in `.d108_positive_control_gate()`'s default — a stipulation,
not a derived constant).

| N | seed | tier-2 rel_frob (gaussian_control) | informative (level 0.5, control-only) |
|---|---|---|---|
| 100  | 1 | 0.572 | NO  |
| 100  | 2 | 0.359 | YES |
| 100  | 3 | 0.731 | NO  |
| 250  | 1 | 0.345 | YES |
| 250  | 2 | 0.230 | YES |
| 250  | 3 | 0.545 | NO  |
| 500  | 1 | 0.285 | YES |
| 500  | 2 | 0.582 | NO  |
| 500  | 3 | 0.337 | YES |
| 1000 | 1 | 0.369 | YES |
| 1000 | 2 | 0.416 | YES |
| 1000 | 3 | 0.473 | YES |

Counts: **8/12 INFORMATIVE, 4/12 UNINFORMATIVE** by this single-arm proxy (N=100: 1/3;
N=250: 2/3; N=500: 2/3; N=1000: 3/3). Read cautiously: because `gaussian_control` itself is the
arm whose recovery is in question here (the plateau above), an "informative" label under this
proxy means only "the control's own tier-2 error happened to fall under 0.5 at this seed," not
"the phylogenetic signal is estimable by the engines under test" — that requires Laplace/VA
data this pilot has not yet collected. The one directional signal worth noting: the
INFORMATIVE fraction rises with N (1/3 → 2/3 → 2/3 → 3/3), consistent with *some* N-dependent
improvement existing even though the mean `rel_frob` plateaus — a mean can plateau while the
fraction clearing a fixed threshold still creeps up, and both are reported here rather than
picking one.

---

## What is explicitly BLOCKED, and why

- **`SD(d)` (Job 2): BLOCKED.** Not run. See "Headline" above — measuring it now would size the
  grid off a quantity (`rel_frob`) that may be mis-specified for every arm, not just the control.
- **N-ladder floor: BLOCKED / NOT SET.** No N in {100, 250, 500, 1000} produced a clean control
  by the trend criterion (decaying toward a small value); the mean plateaus at 0.35–0.42 from
  N=250 onward. A floor cannot be honestly picked from these numbers, and none is proposed here.
- **Job 3 (`va_tips_only` affordability wall): NOT RUN**, per the hold — no VA fitting of any
  kind has occurred in this pilot yet.
- **Job 4 (joint-vs-profiled bridge): NOT RUN**, same reason.

All four scripts (`job2_sd_d.R`, `job3_tips_only_wall.R`, `job4_bridge.R`) are written, smoke-
tested for syntax only (not executed), and ready to run once the diagnostic clears — see
`dev/design108-recovery/pilot-results/`.

---

## Raw Job 1 table (all 12 cells, for reference)

See `dev/design108-recovery/pilot-results/job1_floor_sweep.csv` /
`job1_full.rds` (LOCAL only, not committed). Columns: `N, T, q, seed, status, convergence,
pdHess, rel_frob_tier1, rel_frob_tier2, elapsed_s, total_s, clean` (`clean` uses the inherited
degeneracy-style gate — `rel_frob <= 0.5` both tiers, `pdHess == TRUE`, `convergence == 0` — and
is retained in the file for transparency even though the headline finding here is the trend
plateau, not this pointwise flag).
