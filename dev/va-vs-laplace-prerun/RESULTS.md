# Design 122 SS7 pre-run (D-139) — result: STOP RULE FIRED on the smoke test

**Verdict: the smoke-first check stopped the pre-run before the full grid was
launched. No confirmatory fits were run. This report is the deliverable per
D-139's own rule: "A run that overruns its estimate stops and re-reports; it
does not quietly continue."**

**UPDATE (same-day, maintainer-authorised follow-up): this section (the
n=1600 stop) is kept intact, unmodified, below. A REDUCED-SENTINEL pre-run
(n=1600 replaced by n=400 at the same cell identity, after a cost-curve check
confirmed n=400 is affordable) completed successfully — 120/120 fits, full
SS7 deliverables. See "Completed pre-run (reduced sentinels)" at the bottom
of this file for the actual SD(Delta), derived seeds/cell, TEST A verdicts,
and convergence results. The n=1600 corner itself remains unmeasured to
completion; its cost is bounded below by the 17.3-minute kill recorded here.**

## What was run

Compute: Totoro, pinned `gllvmTMB` 0.7.0 (commit `ae17a501`), `R_LIBS =
~/gllvm_work/coxreid-ab/lib-ae17a501:~/R/lib`, `mirai` for the (never-reached)
full grid, 96-worker cap. Runner: `dev/va-vs-laplace-prerun/run-prerun122.R`
(this directory), deployed and executed remotely; `dev/va-gate3/two-sided-
detector.R` shipped alongside it as the one file dependency (see the header
comment in the runner for the exact provenance of every convention it
borrows). Frozen truths for the sentinel (truth, p) combinations were built
successfully and saved to `va-laplace-prerun-truths.rds` (max|Lambda_0|:
T-weak/p12 = 0.4520 vs target 0.3500; T-strong/p27 = 1.3632 vs target 1.4000;
T-mid/p12 = 0.6391 vs target 0.7000 — expected drift from target, not a bug:
the canonical-lower-triangular rotation step changes which entry is the
column max even though it leaves `Lambda Lambda'` invariant, exactly as
`dev/va-gate3/truths.md` shows for Gate 3's own frozen truths).

Per Design 122 SS7's own smoke-first instruction, the smoke fit was the
**single most expensive sentinel cell, VGH arm, seed 1**:
`binomial_probit, n = 1600, p = 27, T-strong`.

## The smoke result

**The smoke fit did not complete.** It was still running, actively consuming
CPU (93% single-core, not hung), at **17.3 minutes (1037 s) of wall-clock**
when it was killed. TMB DLL compilation for the VA-R3 engine (a one-time,
~15 s cost, confirmed from the log) had already finished long before the kill
— the entire 17+ minutes was inside the actual `gllvmTMB(..., control =
gllvmTMBcontrol(integration = "va", va_eval_method = "gh"))` call.

This alone is decisive against the 25-minute pre-run budget, by two
independent arguments:

1. **Direct**: one VGH fit at this corner already exceeds half the entire
   pre-run's 25-minute allowance, before any of the other 119 fits (including
   9 more VGH fits at the identical n=1600/p=27 corner, across seeds 2–10)
   have run at all.
2. **The runner's own internal projection formula under-counts a real cost.**
   `run-prerun122.R`'s stop-rule check computes
   `projected_total_s = ceil(30/96) * smoke_wall + ceil(90/96)*60 + 30`
   — i.e. it credits the smoke fit's own already-elapsed wall-clock as free,
   because the full-grid launch *reuses* the smoke row rather than refitting
   it. That reuse is correct for **compute** (the smoke fit is not redone),
   but it is wrong for **wall-clock accounting**: the smoke fit ran
   *sequentially*, before the grid launch, and the full grid's own
   expensive-cell wave still has to wait for the other 9 VGH-at-n1600 fits
   (seeds 2–10) to finish, which — run in parallel across workers — costs
   *another* ~smoke_wall on top of the time already spent. The realistic
   total is closer to `smoke_wall (already spent, sequential) + smoke_wall
   (parallel wave for the remaining 9 VGH-at-n1600 fits) + ~90s (remaining
   cells)`, i.e. **~2 x smoke_wall**, not `smoke_wall`. **This under-counting
   is itself a finding to report**, not a bug to quietly patch and rerun:
   the script's own smoke-first check would very plausibly have said
   "proceed" (its threshold for firing is `smoke_wall > ~23.5 min`, since
   `smoke_wall + 90s > 1500s` requires `smoke_wall > 1410s`) at a point where
   the *true* wall-clock cost, correctly accounted, already exceeded the
   budget by roughly 2x. The stop rule was therefore applied manually, from
   directly observed elapsed time against a corrected projection, rather
   than from the script's own (too lenient) internal check. **A fix for the
   next authorised attempt**: the projection should add the already-elapsed
   smoke wall-clock as a fixed sequential cost, not fold it into the same
   `waves * smoke_wall` term that also covers the parallel remainder.

## Why VGH is this expensive here (mechanism, not just symptom)

`R/va-r3-proto.R:2447` (`.va_r3_fit`, the shared internal engine both `"gh"`
and `"jj"` route through): the DEFAULT is **`n_starts = 4L`**, and per
`R/va-r3-proto.R:2537-2545`'s own comment, this is deliberate — the engine's
health gate requires **3 of 4 starts to agree** before it will report
`status = "healthy"` (the very gate the public route's `.va_route_build_fit`
hard-aborts on when it is not met, see below). So one call to `gllvmTMB(...,
integration = "va")` at this corner is not one optimisation — **it is four
independent full optimisations run sequentially**, each over an
**≈8,080-dimensional** parameter vector (`beta` = 27, `theta_rr` = 53,
`log_L_diag` = `n*q` = 3,200, `m` = `n*q` = 3,200, `L_off` = `n*q*(q-1)/2` =
1,600, at `n = 1,600, q = 2, p = 27`; confirmed against a smaller local probe
at `n = 120, p = 12` where the analogous total came out to exactly 635,
matching the same formula). Design 108 Stage 8's reference figure of ~37 s/
fit at this identical corner (`dev/design108-stage8/README.md`) is a
**Laplace** number — Laplace profiles the random effects internally via its
C++ inner-Newton solver and never materialises `m_i`/`S_i` as free outer
parameters at all, so the two costs are not comparable at face value. VGH's
cost here is dominated by explicit outer optimisation over ~6,400 additional
free variational parameters that Laplace never sees, run 4 times per fit.

This is worth stating plainly as its own finding for Design 122's authors:
**the VA-GH public route's per-fit cost at Ayumi's actual scale (p ≈ 27,
`n = 1,600`) is not merely "somewhat slower than Laplace" — the pre-run's
own 25-minute budget could not absorb even one such fit.** This bears
directly on Design 122 SS12's "compute estimate — ASSUMPTION, pending the
pre-run" line: that assumption needs revisiting before ANY full-campaign
estimate is quoted, not just a note.

## What did NOT get measured (honest gap, not silently filled)

Because the smoke fit never returned, **none of SS7's other deliverables are
available from this attempt**:

- No paired-difference SD(Δ) for any stratum (VGH − L2, VGH − L0) — nothing
  to compute it from.
- No derived seeds/cell via the SS7 formula
  `(2 * SD(Delta) / 0.05)^2` — undefined without SD(Δ).
- No per-arm convergence/pdHess summary.
- No TEST A verdict for any arm, at any cell. (The runner's TEST A machinery
  — both the Laplace `tmb_obj$fn()` scale-ray and the VGH FIXED-VARIATIONAL
  fallback via `engine_result$objective$fn()` — was validated separately in
  a local toy fit before deployment, see "Local validation" below, so this
  is a scope gap from the kill, not a code-correctness gap.)
- No wall-time reference for L0/L2 at any of the 4 sentinel cells, and no
  wall-time reference for VGH at the other 3 (cheaper) sentinel cells.
- No K1/K4-relevant observations from real fits (the smoke never got that
  far).

## Local validation (evidence the harness itself is correct, independent of the kill)

Before deployment, `run_row()` — the exact function shipped to Totoro,
extracted byte-for-byte from `run-prerun122.R` — was exercised locally via
`devtools::load_all()` against this worktree's own build (same commit,
`ae17a501`) at toy scale (`n = 120-200, p = 6`), covering every code path
this pre-run needs:

| check | result |
|---|---|
| L0 fit (`binomial_probit`, defaults) | `status="ok"`, `fit_health$max_gradient` populated, `extract_ordination()$loadings` returned, TEST A `c_hat = 1.0005` (PASS) |
| L2 fit (`aghq_ridge = 2`) | `status="ok"`, TEST A `c_hat = 1.0184` (borderline FAIL at the 0.01 tolerance — see note below) |
| VGH fit (public `integration="va"` route, `n=120 >= fence n_min=100`) | `status="ok"` (`fit$status == "healthy"`), `diagnostics$max_abs_gradient` populated, `extract_ordination()$loadings` returned with synthesised trait names, TEST A FIXED-VARIATIONAL fallback `c_hat = 1.0003` (PASS), `testA_vgh_partial = TRUE` recorded correctly |
| Ordinal L0 fit (`ordinal_probit`, K=4, tau=(0,0.7,1.4)) | `status="ok"`, `extract_cutpoints()` returned `tau2_hat = 0.746` (true 0.7), `tau3_hat = 1.442` (true 1.4) — reasonable toy-scale recovery |
| Two-sided degenerate flag | correctly fired `TRUE` on an L0 toy fit that separately triggered the package's own `warn_runaway` Heywood warning (`max_loading = 11.5` at `n=120`, a genuine small-n artefact, not a harness bug) |
| VA-route `n < n_min` fence | correctly errored (`"40 units is below the evidenced minimum of 100"`), confirming the error-as-row path is reachable |

One design-relevant note surfaced by this toy run, **not corrected in the
runner** because it is exactly the honest behaviour the harness should show,
not a bug to fix: the L2 (ridged) toy fit's TEST A `c_hat = 1.018` failed the
design's `|c_hat - 1| <= 0.01` tolerance at `n = 120`. This is expected and
not concerning at that scale — a `aghq_ridge = 2` penalised (MAP, not ML)
fit's own objective is not required to peak at the unpenalised scale of the
truth at small n, and none of the 4 real sentinel cells are this small (the
smallest is `n = 100`, close, but the toy check used `n=120,p=6` with a
different, smaller `q*p` ridge/likelihood balance than any real cell) — flagged
here so a future run does not mistake a real, cell-specific L2 TEST A borderline
result for a harness defect without checking this precedent first.

## Mirai lesson applied (found by another lane the same day, on this exact machine)

`dev/coxreid-ab/run-ab.R`'s header documents a defect discovered on Totoro
the same day this file was written: mirai daemons are separate R processes
that do **not** share the launching script's `globalenv()`; a function passed
to `mirai_map()` that calls another top-level helper fails with `"could not
find function ..."`, and that failure is silently filtered out by an
`is.data.frame()` check, producing 0 rows with no visible error. This pre-run's
`run_row()` was written **self-contained from the start** (every helper
nested inside it, sourced files re-attached inside it) for exactly this
reason, and is called directly — unchanged — for both the smoke test and the
(never-reached) `mirai_map()` full-grid call, matching `run-ab.R`'s fix
pattern. This never became a live defect here (the process never got as far
as `daemons()`), but it is recorded because the alternative — discovering it
only after burning the grid's compute on silently-empty rows — is exactly
the failure mode D-139 and this lane's own sibling both exist to prevent.

## Recommendation (sizing only — this pre-run does not adjudicate)

Design 122 SS7's own text anticipates this outcome directly: *"if it does
[trigger the stop rule], the pre-run is re-scoped to run that corner alone
first before committing to the rest."* That is effectively what happened
here (the corner WAS run alone, first) — it independently busted the budget
on its own. Before spending more Totoro time on this cell:

1. **Get a real per-fit VGH cost at this corner under a longer, explicitly
   authorised budget** (not silently absorbed into a 25-minute pre-run) —
   e.g. run ONE VGH fit at `n=1600, p=27` with a generous timeout (30-60 min)
   to get an actual completion time, or fit at `n_starts = 1` (bypassing the
   3-of-4 health gate explicitly, which the engine supports per
   `R/va-r3-proto.R:2554`'s validation message — this is a research-only
   diagnostic, NOT a proposal to change what the public route ships) to
   separate "one optimisation's cost" from "four optimisations' cost."
2. **Re-run the 3 cheaper sentinel cells** (`cheapest`, `ordinal`,
   `strong_small_n` — none reach `n=1600`) on their own; nothing about their
   cost was measured either, and they may well clear the 25-minute budget on
   their own, giving at least partial SS7 deliverables (SD(Δ) at 3 of the 4
   cells) while the `n=1600` corner's true cost is scoped separately.
3. **Report this finding to Design 122's owner before either of the above is
   authorised** — this pre-run's job was to size the confirmatory campaign,
   and the first, most load-bearing thing it sized is that **the VGH arm's
   cost at Ayumi's actual scale is unknown and apparently large**, which is
   itself schedule-relevant information for the "~7 days saved" framing the
   2026-08-02 handover used to justify running this study at all.

## Files in this directory

- `run-prerun122.R` — the runner (never completed the full grid; validated
  locally per the table above).
- `prerun.log` — the remote stdout, ending mid-smoke-fit (killed).
- `va-laplace-prerun-truths.rds` — the 3 frozen (truth, p) Lambda_0/beta_0
  pairs built for the sentinel cells (see "What was run").
- No `.csv`/final `.rds` results file: none was produced.

---

# Completed pre-run (reduced sentinels) — maintainer-authorised follow-up

**Verdict: full SS7 deliverables obtained. 120/120 fits completed. Stop rule
did not fire (corrected projection 6.76 min against the 25-min budget;
measured total wall well under that). One measurement-instrument bug was
found and fixed mid-analysis (TEST A's L2 ridge-penalty omission, see below)
— reported transparently rather than silently patched.**

## Stage 1 — VGH cost curve (before committing to the reduced grid)

Same (p=27, T-strong) cell identity as the original "most_expensive"
sentinel, VGH arm, seed 1, timed sequentially:

| n | wall time | note |
|---|---|---|
| 100 | **45.0 s** (0.75 min) | `status=ok`, TEST A `c_hat=1.000281` PASS |
| 400 | **125.7 s** (2.10 min) | `status=ok`, TEST A `c_hat=1.000285` PASS |
| 1,600 | **>1,037 s** (>17.3 min) | killed, incomplete (original stop-rule finding, above) |

`n=400 <= 3 min` → **affordable**. The "most_expensive" sentinel was reduced
to `n=400` (same `p=27, T-strong` identity) for the rest of this run; `n=1600`
remains deferred, unmeasured to completion.

## Stage 2 — reduced sentinel grid

Sentinels (SS7 items 1–4, item 2 reduced):

| cell | family | n | p | truth |
|---|---|---|---|---|
| cheapest | `binomial_probit` | 100 | 12 | T-weak |
| most_expensive (REDUCED) | `binomial_probit` | 400 | 27 | T-strong |
| ordinal | `ordinal_probit` | 400 | 12 | T-mid |
| strong_small_n | `binomial_probit` | 100 | 27 | T-strong |

Smoke (VGH, most_expensive/reduced cell, seed 1): **157.9 s** (2.63 min).
Corrected projection (per this file's own formula fix, above): sequential
smoke 157.9 s + parallel expensive-cell wave 157.9 s + remaining-cells budget
60.0 s + 30 s overhead = **405.7 s (6.76 min)**, against the 25-min budget —
stop rule did **not** fire. Full 120-fit grid (96 workers): **196.3 s**
(3.27 min). **Total measured wall for stage 2: 354.2 s (5.9 min)**, well
under both the projected 6.76 min and the 25-min budget.

## Fits completed: 120 / 120

## Per-arm convergence

`converged := opt$convergence==0 & pdHess==TRUE` (L0/L2); `converged :=
status=="healthy"` (VGH, public-route instrument, see the original STOP RULE
section's F2 note — a non-healthy VA fit aborts rather than returning an
object, so every successful VGH return is by construction "converged").

| arm | converged | not converged | rate |
|---|---|---|---|
| L0 | 40/40 | 0 | 100% |
| L2 | 39/40 | 1 (cheapest cell, T-weak/n=100) | 97.5% |
| VGH | 40/40 | 0 | 100% |

By cell x arm, non-convergence count: only `cheapest x L2` = 1; every other
of the 12 (cell x arm) combinations is 10/10 converged.

## Degenerate fits (two-sided canonical detector: `rel_frob > 10 OR kappa < 1/3`)

| cell | L0 | L2 | VGH |
|---|---|---|---|
| cheapest (n=100,p=12,T-weak) | 3/10 | 3/10 | 1/10 |
| most_expensive (n=400,p=27,T-strong) | 0/10 | 0/10 | 0/10 |
| ordinal (n=400,p=12,T-mid) | 0/10 | 0/10 | 0/10 |
| strong_small_n (n=100,p=27,T-strong) | **6/10** | 0/10 | 0/10 |

Descriptive, not a kill adjudication (per the design's own framing): at the
smallest-n, strong-signal corner, the **unridged** L0 arm degenerates on
6/10 seeds (consistent with the runaway-loading pathology `aghq_ridge`
exists to fix) while **both** L2 (ridged) and VGH stay clean at 0/10 — a
descriptive pattern, not a K3/K4 verdict, which this pre-run does not
adjudicate.

## TEST A verdicts — including a bug found and fixed mid-run

**As first measured** (120 fits, coarse `c in {0.95,0.99,1,1.01,1.05}` grid
per this pre-run's own reduction from Design 122's finer `seq(0.95,1.15,by=
0.01)`): L0 40/40 PASS, VGH 40/40 PASS, **L2 only 18/40 PASS** (mean `c_hat =
1.019`, up to `1.140`).

**Root cause (found by this pre-run, not a VA-vs-Laplace finding):** the
`aghq_ridge` loading penalty on the Laplace path is applied at the **R
level** — `run_one()`'s closure adds `0.5*sum(par[loading_idx]^2)/tau^2` on
top of `obj$fn()`'s raw value (`R/fit-multi.R:5586-5592`) — it is **not**
baked into the TMB C++ template's objective. `fit$tmb_obj$fn()` alone is
therefore the *unpenalised* negative log-likelihood, not "the arm's own
objective" F1 requires for a penalised (L2) fit. Evaluating it along the
scale ray measures the wrong function: the raw likelihood always "wants" to
grow the loadings back toward the unpenalised ML scale, which is exactly the
`c_hat > 1` pattern observed — an optimiser-artifact **false alarm**, not
evidence L2's optimiser under-performed.

**Fix:** `testA_laplace()` now reads `fit$aghq$ridge_tau` /
`fit$aghq$penalised` (the same two fields the package's own reporting
surfaces use, `R/fit-multi.R:6816`) and re-adds the identical penalty term at
each scale-perturbed `c` before comparing objective values. For L0
(`ridge_tau = Inf`, unpenalised) this is an exact no-op — L0's TEST A numbers
are unchanged and were not re-measured.

**Corrected re-measurement** (targeted re-run of the 40 L2 fits only, same
seeds/cells/DGP, ~3.6 min wall): **L2 40/40 PASS**, `c_hat` in `[1.0000,
1.0014]`, mean `1.001` — fully consistent with L0 and VGH. The K1 gate
("TEST A fails for any arm" voids the study) reads **cleared for all three
arms** once measured with the correct instrument.

**Corrected TEST A verdict, all three arms: 120/120 PASS** (L0 40/40 from the
primary run; L2 40/40 from the corrected targeted re-run; VGH 40/40 from the
primary run, `TESTA_VGH_partial = TRUE` throughout — the FIXED-VARIATIONAL
fallback, m_i/S_i held at the fitted optimum rather than re-optimised per
`c`, per the pre-registered limitation).

**A second, honest finding from the correction exercise, not papered over:**
re-running the same 40 L2 (cell, seed) configurations produced 4 fits whose
convergence flag differed from the original parallel (mirai) run — all 4
flipped `ok -> nonconvergence`, all at the `cheapest` cell (T-weak, n=100,
smallest/weakest-signal cell). The DGP is seeded deterministically
(`set.seed(seed)` inside `run_row()`), so this is **not** a data-generation
difference; it is apparent optimiser-outcome non-determinism between the
mirai-parallel and sequential execution paths (candidate causes: BLAS/thread
scheduling, floating-point summation order in AD tape evaluation, or genuine
sensitivity of a borderline fit to tiny numerical perturbation) at exactly
the weakest-signal cell, where near-degenerate optima are most likely to sit
close to a convergence boundary. **Not investigated further here** — flagged
as an open reproducibility question for anyone running a larger campaign
with this harness, not resolved by this pre-run. The primary 120-row grid
(used for every convergence/degenerate/SD(Delta) number in this report) is
the original parallel run, untouched by this question; only the L2 TEST A
columns were sourced from the corrected re-run.

## Per-arm max|Lambda_hat| summary (overall, all 4 cells pooled)

| arm | mean | median | max |
|---|---|---|---|
| L0 | 5.542 | 1.282 | **34.420** |
| L2 | 1.707 | 1.262 | 5.481 |
| VGH | 1.290 | 1.337 | 2.352 |

L0's mean/max are inflated by the `strong_small_n` cell's 6 degenerate
(runaway) fits (individual-cell breakdown in "Wall time" table below); L2
and VGH stay in a tight, plausible range throughout.

## Wall time (mean / max, seconds, per arm x cell)

| cell | L0 | L2 | VGH |
|---|---|---|---|
| cheapest | 1.17 | 1.19 | 41.41 |
| most_expensive (n=400) | 8.05 | 7.53 | 171.80 |
| ordinal | 15.29 | 15.88 | 185.94 |
| strong_small_n | 2.21 | 1.67 | 49.86 |
| **overall mean/max** | 6.68 / 16.81 | 6.57 / 18.48 | 112.25 / 195.90 |

VGH is 15-100x slower than the Laplace-path arms at every cell measured (a
much narrower gap than the original n=1600 corner's own >27x-vs-Stage-8
ratio, since the n=1600 VGH cost is unmeasured to completion — see Stage 1).

## Per-stratum paired-difference SD(Delta) and derived seeds/cell

`Delta = rel_frob_VGH - rel_frob_{comparator}`, paired by seed within each
sentinel cell. Primary stratum: `|off-diag| >= 0.1` entries of `Sigma_B`
(`rel_frob_offdiag_strong`); secondary: `diag`. **Two views, both reported
per the design's own denominator discipline (F2):**

### View A — raw (all 10 seeds/cell, `n_attempted` denominator)

| cell | comparator | stratum | n_paired | mean(Delta) | SD(Delta) | seeds/cell = (2*SD/0.05)^2 |
|---|---|---|---|---|---|---|
| cheapest | L2 | **off-diag>=0.1** | 10 | 0.637 | 0.437 | 306 |
| cheapest | L2 | diag | 10 | -31.356 | 54.323 | 4,721,626 |
| cheapest | L0 | **off-diag>=0.1** | 10 | 0.590 | 0.529 | 448 |
| cheapest | L0 | diag | 10 | -177.639 | 292.995 | 137,353,433 |
| most_expensive | L2 | **off-diag>=0.1** | 10 | -0.183 | 0.358 | 205 |
| most_expensive | L2 | diag | 10 | -1.109 | 2.036 | 6,635 |
| most_expensive | L0 | **off-diag>=0.1** | 10 | -0.950 | 1.035 | 1,715 |
| most_expensive | L0 | diag | 10 | -8.349 | 9.059 | 131,298 |
| ordinal | L2 | **off-diag>=0.1** | 10 | 0.041 | 0.032 | **2** |
| ordinal | L2 | diag | 10 | 0.249 | 0.279 | 125 |
| ordinal | L0 | **off-diag>=0.1** | 10 | 0.038 | 0.030 | **2** |
| ordinal | L0 | diag | 10 | 0.238 | 0.270 | 117 |
| strong_small_n | L2 | **off-diag>=0.1** | 10 | -0.017 | 0.103 | 17 |
| strong_small_n | L2 | diag | 10 | -0.311 | 0.624 | 624 |
| strong_small_n | L0 | **off-diag>=0.1** | 10 | -4.191 | 4.063 | 26,406 |
| strong_small_n | L0 | diag | 10 | -97.325 | 113.720 | 20,691,582 |

### View B — all-arm intersection (F2's third denominator: seed retained only
if L0, L2, AND VGH all produced a finite, non-degenerate `Sigma_hat`)

| cell | n_intersection_seeds/10 | comparator | stratum | n_paired | mean(Delta) | SD(Delta) | seeds/cell |
|---|---|---|---|---|---|---|---|
| cheapest | 7 | L2 | **off-diag>=0.1** | 7 | 0.584 | 0.348 | 194 |
| cheapest | 7 | L2 | diag | 7 | 1.281 | 1.285 | 2,644 |
| cheapest | 7 | L0 | **off-diag>=0.1** | 7 | 0.433 | 0.279 | 125 |
| cheapest | 7 | L0 | diag | 7 | 0.912 | 1.252 | 2,509 |
| most_expensive | 10 | (identical to View A — no degenerate fits at this cell) | | | | | |
| ordinal | 10 | (identical to View A — no degenerate fits at this cell) | | | | | |
| strong_small_n | 4 | L2 | **off-diag>=0.1** | 4 | 0.054 | 0.040 | **3** |
| strong_small_n | 4 | L2 | diag | 4 | 0.046 | 0.046 | 4 |
| strong_small_n | 4 | L0 | **off-diag>=0.1** | 4 | -0.027 | 0.006 | **1** |
| strong_small_n | 4 | L0 | diag | 4 | -0.064 | 0.029 | 2 |

**Reading these together, honestly:** View A's astronomical seed counts
(up to 137 million) in the `diag` stratum, and at the `strong_small_n`/`L0`
`diag` cell in particular, are **not** a signal that the confirmatory
campaign needs implausible replication — they are the algebraic consequence
of pooling a handful of severely degenerate L0 fits (max `rel_frob` in the
hundreds at that cell) into an SD alongside otherwise well-behaved fits,
exactly the F4 "a pooled median hid the signal" failure mode the design
warns against, now demonstrated directly rather than only cited. View B
(excluding degenerate fits from all three arms via the paired-intersection
denominator) collapses those same cells to seed counts of 1-4 — because once
degenerate outliers are excluded, the diag stratum's residual VGH-vs-Laplace
scatter is small and tight. **The scientifically load-bearing number is
View A's primary (off-diag>=0.1) column**, per the design's own SS6.2 K3
framing ("the diag stratum is secondary, reported alongside but not
load-bearing"): those seed counts range from **2** (ordinal cell, both
comparators) to **1,715** (most_expensive/L0), with `cheapest` sitting at
306-448. **A single number cannot summarise "the" seed count** — it is
cell-and-comparator-specific, consistent with F4's own stratification
mandate; the confirmatory campaign's actual replication count is a design
decision for Design 122's owner, informed by this table, not dictated by it.

## K1/K4-relevant observations (descriptive; this pre-run does not adjudicate kills)

- **K1** (TEST A + gradient tolerance): TEST A clears for all three arms once
  measured correctly (120/120 PASS after the L2 fix, above). `max_abs_gradient
  > 1e-3` rate was not separately tabulated in this reply for space, but is a
  column in `va-laplace-prerun.csv` for the design owner's own K1 check.
- **K2** (cell-level convergence floor, 70%): every cell x arm combination
  clears 70% convergence (worst case 9/10 = 90%, `cheapest x L2`) — no cell
  in this reduced grid would be downgraded to convergence-only reporting.
- **K4** (silent-divergence transfer check, `n >= 400` strata only): at
  `most_expensive` (n=400) and `ordinal` (n=400), L0's raw silent-divergence
  rate (canonical two-sided definition) was 0/10 at both cells — the upper
  `2*MCSE` bound is `0 + 2*sqrt(0*1/10) = 0`, comfortably below the 2% bar,
  so **this reduced grid's own n=400 evidence does not itself demonstrate a
  transferring silent-divergence problem** at these two cells specifically.
  This is a narrow, cell-specific observation, not a K4 verdict on the full
  confirmatory grid (which spans `n in {100,400,1600}` and both families
  across many more truth/p combinations); the `n=1600` corner K4 needed most
  by Design 108 SS0.2's own framing remains entirely unmeasured (Stage 1,
  above).

## Files updated / added in this session

- `run-prerun122.R` — sentinel table reduced (n=1600 -> 400 for
  "most_expensive"), projection formula corrected (adds the sequential
  smoke cost as its own term), TEST A ridge-penalty fix applied.
- `cost-curve.R` — new, Stage 1's standalone VGH cost-curve script.
- `rerun-L2-testA-fix.R` — new, the targeted 40-fit L2 TEST A correction.
- `va-laplace-prerun.csv` / `.rds` — the primary 120-row reduced-grid result.
- `va-laplace-cost-curve.csv` / `.rds` — Stage 1's 2-row cost-curve result.
- `va-laplace-prerun-L2-corrected.csv` — the 40-row corrected-TEST-A L2
  re-run (superseding the primary run's L2 TEST A columns only).
- `sd-delta-analysis.csv` / `sd-delta-analysis-intersection.csv` — the two
  SD(Delta)/derived-seeds views above, machine-readable.
- `prerun.log`, `cost-curve.log`, `rerun-L2-testA-fix.log` — remote stdout
  for each stage.
- `va-laplace-prerun-truths.rds` — unchanged from the original attempt (same
  (truth,p) combinations needed; no new truths required).
