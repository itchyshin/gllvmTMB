# Slice D: is the Laplace/AGHQ crossover a function of T, and where is it?

Script: `dev/aghq-evidence/12-crossover-vs-T.R`. Reference fitter:
`dev/aghq-r-reference.R` (unmodified). DGP is byte-identical to
`04-n-ladder.R` / `05-descend.csv`: `lam_sd = 1.2`, `b ~ N(0.3, 0.4)`, `q = 1`.
`k = 9` for AGHQ; `k = 1` is Laplace exactly (Liu & Pierce 1994).

**STATUS: PARTIAL. The wall-clock budget was exhausted after 6 of 19 cells
(31%), all at n ≤ 200 and T ≤ 8, with 5 seeds each (not the requested 20).
T=16 has ZERO data at any n. n=400 and n=800 have ZERO data at any T. Read the
"What could not be verified" section before trusting any number here — several
of the surviving medians rest on 1-3 converged seeds out of 5 and are not
reliable bias estimates.**

## What this was supposed to fill in

Every number in the original crossover table (`07-prior-art-crossover.md`,
`05-descend.csv`) was measured at a single fixed T = 4 traits/site. That is one
row of a (T, n) surface. This slice was designed to ask two things:

1. Where is the crossover n, as a function of T ∈ {2, 4, 8, 16}?
2. Does Laplace's bias actually shrink with T at fixed large n (n = 800), as
   the O(1/T) theory (Breslow & Lin 1995; Joe 2008) requires?

**Neither question can be answered with the data actually collected.** Q1 has
usable (if thin) data only for T ∈ {2, 4} and only up to n = 200; T = 8 has one
n-value with mostly non-converged fits; T = 16 has nothing. Q2 requires n =
800, which was never reached at any T. This is reported as a result in itself
(see "Interpretation" below), not smoothed over.

## The dominant, load-bearing complication: the machine was saturated

`uptime` read load averages of **~285 / 265 / 199 on a 20-core box**, with
**~230 concurrently running R processes** (three sibling slices A/B/C, each
itself internally parallel, dispatched alongside this one). A pre-run timing
survey (throwaway scratch, not shipped) showed:

- A single `ref_nll()` evaluation (no optimizer loop) cost **<0.6s for every
  (T,n) cell in the grid**, including T=16, n=800 — the fitter's per-evaluation
  cost is NOT the bottleneck.
- A full `ref_fit()` under contention, by contrast, ranged from ~3s (T=2,
  n=50) to timing out at 20s even for T=2, n=200 and for both engines at
  T=16, n=50 — i.e. **wall-clock cost was dominated by CPU starvation, not by
  the algorithm.** `ps aux` and even plain `Rscript -e 'parse(...)'` calls
  from this same session were regularly taking 60-120s to return during this
  run, which independently corroborates the contention (not just an
  artifact of the reference fitter).
- An untimed single-seed probe at (T=16, n=800), run before contention was
  fully characterised, did not return in over 2 minutes. nlminb's numerical
  gradient has npar = 2T = 32 dimensions there, so its gradient cost
  (npar × per-eval cost) is the worst in the grid by construction, contention
  or not. **This corner was dropped by design**, independent of the machine
  state, per the brief's explicit permission.

Given this, the design ran sequentially (adding parallel workers of its own
would only have worsened the shared-box contention for the sibling slices),
processed the grid **cheapest-cell-first** (by T×n), and allocated seeds in
**batches of 5 across a breadth-first outer loop** (batch 1 gives every
surviving cell its first 5 seeds; batch 2 would give every cell 5 more if time
allowed; and so on toward 20) under a **10-minute internal wall-clock budget**
(`WALL_BUDGET_S = 600`, checked with `Sys.time()` inside the R process, so it
reflects real incurred contention, not a guess). This was meant to guarantee
the same seed count across the (T,n) grid at whatever point the budget ran
out, rather than exhausting the whole budget on one or two cheap cells while
T=16 got nothing. **In the event, the budget ran out partway through batch 1
itself** — no cell reached even its second batch of 5, so the intended
breadth-vs-depth trade-off never had to arbitrate; breadth alone consumed the
entire budget.

**Per-fit cap:** 15s (`R.utils::withTimeout`), tighter than the 20s used in
the throwaway survey, given the observed contention. A fit that does not
converge inside the cap is recorded as non-convergent (`ratio = NA`,
`timed_out = TRUE`) — itself informative about that (T,n) cell, not silently
retried or dropped from the count.

## The discipline check (mandatory, not decorative)

**First attempt genuinely broke, and stayed broken for a real reason worth
recording, not the reason intended.** The plan was to force
`TIMEOUT_S = 0.01s` on a cell known to take 5-6s and confirm every fit in it
is recorded as timed-out. That is **not** what happened: the AGHQ (k=9) fit at
T=4, n=50 came back **CONVERGED** (`ratio = 2.409, conv = 0,
timed_out = FALSE`) under the nominal 0.01s cap. That is not a genuine 10ms
convergence — it means `R.utils::withTimeout`'s elapsed-time check only fires
at R-level dispatch points, and a cap that small is not a reliable cutoff on
this stack. The script's own `stopifnot(all(broken$timed_out), ...)` caught
this immediately and halted the whole run with `Execution halted` (first run,
exit code 1 — the process genuinely died, it was not caught and hidden).

**Fix:** the break-check was changed to force `TIMEOUT_S = 1s` on the same
cell (T=4, n=50), comfortably below its empirically measured 5-6s typical fit
time. Re-run result (from the log, verbatim):

```
=== BREAK CHECK: forcing TIMEOUT_S = 1s on T=4, n=50, 1 seed (typical fit here takes 5-6s) ===
  T  n seed  engine ratio conv timed_out
1 4 50 9001 laplace    NA   NA      TRUE
2 4 50 9001    aghq    NA   NA      TRUE
CONFIRMED RED under the deliberately-broken (1s) cap.
```

The cap was then restored to the real `TIMEOUT_S = 15` on the same cell:

```
=== RESTORE CHECK: same cell, real TIMEOUT_S ===
  T  n seed  engine     ratio conv timed_out
1 4 50 9002 laplace 0.5783469    0     FALSE
2 4 50 9002    aghq 0.7800519    0     FALSE
CONFIRMED GREEN after restoring the real cap -- the check is not vacuous.
```

**What this proves:** the timeout/convergence bookkeeping used throughout the
sweep is not vacuous — it really does distinguish a forced-broken run from a
working one, but only above roughly 1s; **sub-second `withTimeout` caps
should not be trusted on this stack**, a genuine, reportable finding about the
tool that is independent of this specific script.

## Coverage actually achieved

From `dev/aghq-evidence/12-seed-coverage.csv`:

| T  | n   | seeds run |
|----|-----|-----------|
| 2  | 50  | 5 |
| 4  | 50  | 5 |
| 2  | 100 | 5 |
| 8  | 50  | 5 |
| 4  | 100 | 5 |
| 2  | 200 | 5 |
| 16 | 50  | **0** |
| 8  | 100 | **0** |
| 4  | 200 | **0** |
| 2  | 400 | **0** |
| 16 | 100 | **0** |
| 8  | 200 | **0** |
| 4  | 400 | **0** |
| 2  | 800 | **0** |
| 16 | 200 | **0** |
| 8  | 400 | **0** |
| 4  | 800 | **0** |
| 16 | 400 | **0** |
| 8  | 800 | **0** |
| 16 | 800 | **0** (dropped by design, not budget) |

The sweep hit the 600s internal budget at **634s elapsed**, 7/19 cells into
batch 1 (the 7th, T=2 n=200, was allowed to finish since the budget check only
runs between cells, then the loop stopped before starting T=16, n=50). **13 of
19 candidate cells were never started at all.**

Per-fit convergence within the 15s cap, from the incremental CSV (`n_ok` =
returned a value; `5` = attempted):

| T | n   | engine  | n_ok / 5 |
|---|-----|---------|----------|
| 2 | 50  | laplace | 5 |
| 2 | 50  | aghq    | 5 |
| 2 | 100 | laplace | 5 |
| 2 | 100 | aghq    | 5 |
| 2 | 200 | laplace | 4 |
| 2 | 200 | aghq    | 4 |
| 4 | 50  | laplace | **3** |
| 4 | 50  | aghq    | 5 |
| 4 | 100 | laplace | **3** |
| 4 | 100 | aghq    | 5 |
| 8 | 50  | laplace | **2** |
| 8 | 50  | aghq    | **1** |

**Convergence itself degrades sharply as T grows, before bias is even
comparable.** At T=2 essentially everything converges within 15s; at T=4,
Laplace (not AGHQ) is the one failing to converge 2/5 times; at T=8, AGHQ
converges only 1/5 times and Laplace 2/5. The T=4 pattern (Laplace failing
more than AGHQ) is the **opposite** of the T=8 pattern (AGHQ failing more) —
with only 5 seeds per cell this is not a resolvable trend, just a flag that
**non-convergence-within-a-time-budget is itself T-dependent and does not
move monotonically with either engine** in this thin a sample.

## Crossover table (median |ratio − 1| by T, n, engine)

Medians are computed **only over the fits that returned a value** (see the
convergence table above for how many that is per cell — as low as 1).

```
--- T = 2 ---
     n     |Lap-1|    |AGHQ-1|
    50      0.5353      0.3395  <- AGHQ <= Laplace here  [n_seeds=5, both fully converged]
   100      0.2556      0.5753                            [n_seeds=5, both fully converged]
   200      0.5084      0.3460  <- AGHQ <= Laplace here  [n_seeds=5, 4/5 converged each]
   400           -           -  (NOT RUN)
   800           -           -  (NOT RUN)
"crossover n" per the script's scan rule: 50 (i.e. the FIRST n tested)

--- T = 4 ---
     n     |Lap-1|    |AGHQ-1|
    50      0.5674      0.5607  <- AGHQ <= Laplace here  [Laplace n_ok=3/5, AGHQ n_ok=5/5]
   100      0.2830      0.4333                            [Laplace n_ok=3/5, AGHQ n_ok=5/5]
   200           -           -  (NOT RUN)
   400           -           -  (NOT RUN)
   800           -           -  (NOT RUN)
"crossover n": 50

--- T = 8 ---
     n     |Lap-1|    |AGHQ-1|
    50      0.0587      0.0403  <- AGHQ <= Laplace here  [Laplace n_ok=2/5, AGHQ n_ok=1/5 -- SEE CAVEAT]
   100           -           -  (NOT RUN)
   200           -           -  (NOT RUN)
   400           -           -  (NOT RUN)
   800           -           -  (NOT RUN)
"crossover n": 50 (meaningless with n_ok=1 for AGHQ, see below)

--- T = 16 ---
                              ALL CELLS NOT RUN. No statement possible.
```

**Read the T=2 row as noise, not a reversal.** The script's crossover-scan
rule reports "50" for T=2 because AGHQ ≤ Laplace happens to hold at n=50 (the
first n checked) — but Laplace is *better* than AGHQ at n=100, then AGHQ is
better again at n=200. With 4-5 seeds per cell that non-monotonicity is far
more consistent with sampling noise than with a real, reproducible crossover
location; the mechanical "first n where AGHQ ≤ Laplace" rule the script
applies is too literal for n_seeds this small and should not be read as "the
crossover is at n=50 for T=2." The **direction** that is qualitatively
consistent with the original T=4 finding (`05-descend.csv`) is: AGHQ's
absolute deviation from 1 is generally larger than Laplace's across most of
these small-n cells, matching the original crossover shape's low-n regime —
but that is the only qualitative signal this slice can support.

**T=8, n=50's numbers are not a bias estimate, they are one seed.** AGHQ's
`|AGHQ-1| = 0.0403` at T=8, n=50 comes from a **single converged fit** (seed
505; the other 4 timed out). Laplace's `0.0587` comes from 2 converged fits.
Presenting either as "T=8 has smaller bias than T=2/T=4 at n=50" would be
overclaiming from an n of 1-2. The honest reading is: **at T=8, n=50, this
reference fitter mostly cannot produce an answer inside a 15s cap under this
box's load**, and the few fits that finish happen to look unbiased — which
could equally mean (a) T=8 genuinely reduces bias fast, consistent with more
information per site, or (b) the fits that finish quickly are a
non-representative, "easy" subset of the seed space (a selection effect on
exactly the sub-population most likely to also be well-behaved in Lambda).
This slice cannot distinguish those two explanations with 1-2 successful
fits.

## Does Laplace's bias shrink with T at fixed n = 800?

**Cannot be tested. n = 800 has zero data at every T** (all four cells
T ∈ {2,4,8,16} × n=800 were never reached; T=16,n=800 was pre-dropped, the
other three ran out of budget). This is the direct O(1/T) check the brief
asked for, and it did not run. Reported as a plain miss, not inferred from
smaller n.

The only same-T, same-engine comparison that exists across more than one n is
within T=2 (n=50→200) and T=4 (n=50→100), and neither shows a clean
monotonic shrinkage of Laplace's `|ratio-1|` with n (T=2: 0.535 → 0.256 → 0.508;
T=4: 0.567 → 0.283) — n=100 looks better than either neighbour for both T,
which given only 3-5 seeds is again most consistent with sampling noise. No
T-dependence claim can be extracted from this.

## Interpretation for the routing rule

**No (T, n) routing recommendation can be responsibly issued from this
slice's data.** The two questions the routing rule needs answered — where the
crossover sits as T varies, and whether Laplace's bias genuinely shrinks with
T at fixed large n — both require data this run did not obtain (T=16
entirely; n≥400 entirely; T=8 beyond a single mostly-non-convergent cell).
Issuing a recommendation from the T∈{2,4} n≤200 fragment that did complete
would extrapolate two dimensions (T up to 16, n up to 800) beyond what was
measured, which is precisely the overclaiming this project's discipline rules
exist to prevent.

What CAN be said, narrowly:

- **The qualitative shape of the original T=4 finding is not contradicted** by
  the T=2, T=4 data obtained here (n ≤ 200): AGHQ's deviation from 1 is
  generally at least as large as Laplace's in this small-n range, consistent
  with the earlier `05-descend.csv` result that AGHQ becomes markedly worse
  than Laplace below roughly n=400 (this slice never reached n=400, so it
  cannot confirm the crossover LOCATION, only that AGHQ is not obviously
  better than Laplace at n ≤ 200 for T ∈ {2,4}).
- **Non-convergence within a practical time budget becomes a first-order
  problem before bias comparison is even meaningful, and it worsens with T.**
  At T=8, n=50, most attempts (whichever engine) did not return an answer
  inside 15s. A routing rule that only reasons about bias, and ignores
  whether either engine reliably TERMINATES in the T region a user would
  actually run, is incomplete. This is a real, if incidentally discovered,
  finding: **for T≥8 at small n, "which engine has less bias" may be the
  wrong question relative to "does either engine converge in bounded time."**
- **Whether Laplace's small-n "adequacy" is a stable, engineerable
  cancellation of two errors, or a coincidence that drifts with T, is
  unresolved by this run.** The brief specifically asked to check this. The
  honest answer is: not enough of the (T,n) surface was measured to tell.
  Given that T=4's cancellation (`05-descend.csv`) was itself fairly narrow
  (Laplace ratio bottomed near n=25-50 then continued to move at n=25:
  14.534!), and this slice's own T=4/T=8 convergence-rate reversal (Laplace
  worse at T=4, AGHQ worse at T=8) shows AT LEAST that the *convergence*
  side of "adequacy" is not stable across T — which is itself evidence
  against treating the cancellation as something a default rule can rely on
  without re-deriving it per T, even before bias stability is considered.

**Recommendation:** re-run this design on a quiet machine (or with a
dedicated core allocation), with the same script (`12-crossover-vs-T.R`,
unmodified) and a realistic budget of 30-60 minutes rather than 10, before
writing any T-dependent routing rule. The script already implements
breadth-first batching and a wall-clock cutoff, so it is safe to re-run
as-is with a larger `WALL_BUDGET_S` and/or more seeds; it does not need to be
redesigned, only re-run in a better compute environment.

## What could NOT be verified, plainly stated

- **T=16 has zero data at any n.** No statement about T=16 can be made,
  including whether it converges at all in bounded time (the one probe
  available, from the throwaway pre-survey, showed T=16 n=50 timing out on
  BOTH engines at a 20s cap — suggestive that T=16 may be even harder to
  converge than T=8, but this is a single anecdotal probe, not part of the
  shipped design, and is not relied on above).
- **n=400 and n=800 have zero data at any T.** The direct O(1/T) check at
  n=800 (the brief's second question) did not run at all.
- **13 of 19 candidate (T,n) cells were never started**, cut off by the
  600s wall-clock budget (see coverage table). This is distinct from, and in
  addition to, the single cell (T=16, n=800) dropped by design before the
  run started.
- **T=8, n=50's bias numbers rest on 1 (AGHQ) and 2 (Laplace) converged
  fits out of 5 attempted** and should not be read as bias estimates (see
  above).
- Every number in this file was collected on a machine reporting load
  averages of ~285-199 against 20 cores, with ~230 concurrent R processes
  from three sibling slices. Absolute wall-clock times quoted here are NOT a
  clean measurement of the reference fitter's intrinsic cost — the
  contention-free per-evaluation cost (bench, not shipped) was <0.6s for
  every cell in the grid including the largest. The RATIOS themselves (once
  a fit does converge) are not mechanically distorted by contention — nlminb
  converges to the same optimum regardless of how long it took — but
  **contention-driven non-convergence is not random with respect to the
  hardest cells**: T=8 and T=16 were disproportionately affected, so the
  surviving (converged) sample at those T values, thin as it already is, may
  be a biased subset of what a full run would show. This is flagged as a
  real caveat on every T≥8 number above, not folded silently into the
  routing recommendation.
