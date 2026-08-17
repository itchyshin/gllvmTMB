# Design 122 SS7 pre-run (D-139) — result: STOP RULE FIRED on the smoke test

**Verdict: the smoke-first check stopped the pre-run before the full grid was
launched. No confirmatory fits were run. This report is the deliverable per
D-139's own rule: "A run that overruns its estimate stops and re-reports; it
does not quietly continue."**

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
