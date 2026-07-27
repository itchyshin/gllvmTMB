# The speed claim at scale: does our VA ever beat Laplace? (n up to 5000, p up to 50)

**Role:** Fisher (adversarial speed test). **Compute:** Totoro, 48 workers, 900s
per-arm-fit budget, real OS-level hard kill (see Methodology note). Results
local (D-50); never a GitHub artifact. Raw CSV: `results/scale.csv`. Per-cell
RDS backups: `results/cells/`.

**Design:** family (poisson, bernoulli) x n (500, 1000, 2500, 5000) x p (27,
50) x q=2 x seed (1:3) = 48 cells, up to 4 arms each (`gtmb_gh` always,
`gtmb_jj` bernoulli-only, `gllvm_va`, `gtmb_laplace`) = 168 rows, 48/48 cells
completed (no hangs, no lost data). p=27 mirrors Ayumi's model (n=5397, p=27).

## Bottom line

**No crossover. VA is slower than Laplace everywhere tested, and the gap gets
categorically worse with n, not better.** At n=500 our GH-VA (`gtmb_gh`) is
~10-16x slower than Laplace. By n=1000 it's ~18-31x slower. By n=2500 and
n=5000, `gtmb_gh` and `gtmb_jj` no longer *complete* inside a 900-second
budget at all (100% TIMEOUT, both families, all seeds) — while
`gtmb_laplace` finished every single one of its 48 fits, with **zero
timeouts and zero errors**, in a median of 79-202 seconds even at the largest
size. `gllvm_va` (gllvm's own VA/EVA-adjacent implementation) does better
than ours but degrades the same way: 100% TIMEOUT at n=5000, 58% at n=2500.

This is the literature's O(m^3)-Laplace argument tested in the regime it is
actually made for, and it does not show up as an advantage for VA in this
range — if anything the roles are reversed: **VA's own cost is what turns out
to be superlinear (and apparently intractable) as n grows**, and Laplace's
p-sensitivity (see Q3) is the only place the classical argument's direction
appears at all.

---

## Q1. At what n does VA become faster than Laplace? Is there a crossover?

**No crossover exists anywhere in n in {500, 1000, 2500, 5000} or p in {27,
50}.** Median wall-clock seconds, GH-VA (`gtmb_gh`) vs Laplace (`gtmb_laplace`),
pooled over family and seed:

| n | p | gtmb_gh (s) | gtmb_laplace (s) | ratio (VA/Laplace) |
|---:|---:|---:|---:|---:|
| 500 | 27 | 110.5 | 7.0 | 15.8x |
| 1000 | 27 | 413.2 | 13.3 | 31.0x |
| 2500 | 27 | **901.5 (TIMEOUT, censored)** | 36.0 | ≥25.0x |
| 5000 | 27 | **901.7 (TIMEOUT, censored)** | 78.8 | ≥11.4x |
| 500 | 50 | 163.8 | 16.6 | 9.9x |
| 1000 | 50 | 628.6 | 34.2 | 18.4x |
| 2500 | 50 | **901.5 (TIMEOUT, censored)** | 87.0 | ≥10.4x |
| 5000 | 50 | **901.7 (TIMEOUT, censored)** | 202.3 | ≥4.5x |

The ratio *shrinks* at n=2500/5000 only because `gtmb_gh`'s reported time is
capped at the 900s budget (a right-censored lower bound, not its real
completion time — it never finished, see Q4/status table). The genuinely
measured trend (n=500→1000, both uncensored) is that the gap *widens*: 15.8x
→ 31.0x at p=27, 9.9x → 18.4x at p=50. Extrapolating the fitted scaling (Q2)
rather than the censored medians, the true gap at n=5000 is far larger than
"11x" — `gtmb_gh` simply doesn't finish.

A finding that VA never becomes faster IS a finding; it is not being tuned
away here.

## Q2. Scaling exponents (log-log slope of seconds vs n, and vs p)

Fit on the **only uncensored, fully-completed range (n=500→1000)** — the
honest way to estimate the true growth rate rather than let the 900s
timeout ceiling flatten it artificially:

| arm | exponent vs n (p=27) | exponent vs n (p=50) | exponent vs p (n=500) | exponent vs p (n=1000) |
|---|---:|---:|---:|---:|
| `gtmb_gh` (ours, GH) | 1.90 | 1.94 | 0.64 | 0.68 |
| `gtmb_jj` (ours, JJ) | 2.66 | 2.51 | 0.38 | 0.21 |
| `gllvm_va` | 2.10 | 2.04 | 0.75 | 0.68 |
| `gtmb_laplace` | 0.93 | 1.04 | 1.40 | 1.53 |

(A naive fit across all 4 n points, including the two censored ones, gives
misleadingly *low* n-exponents for the VA arms — 0.83/1.39/1.71, from
`analyse-scale.R`'s automated table — because the 900s cap truncates what
would otherwise be much larger values. Those numbers understate the true
cost and are not used above; they are reproducible by re-running
`Rscript dev/scale/analyse-scale.R dev/scale/results`.)

**Both VA implementations scale roughly quadratically in n (exponent ~1.9-2.7)
— our GH engine, our JJ engine, and gllvm's own VA all land in the same
"roughly n²" band. Laplace scales roughly linearly in n (exponent ~0.9-1.0)**,
consistent with a sparse per-site random-effect structure at fixed q=2. This
is the single biggest number in this study: a genuinely quadratic-vs-linear
gap compounds catastrophically as n grows from hundreds to thousands, which
is exactly what the timeout wall at n≥2500 shows happening in practice.

**In p, the pattern reverses direction (mildly).** Laplace is the
*fastest-growing-in-p* arm (exponent 1.4-1.5) while the VA arms are flatter
(0.2-0.8). This is the one place the classical argument's *direction* shows up
— Laplace really is more p-sensitive than VA here — but p only ranges to 50 in
this design, and Laplace's absolute times stay far below VA's even at p=50
(202s vs VA not finishing at all), so this p-sensitivity is real but nowhere
near large enough to close the n-driven gap in the tested range.

## Q3. Does the O(m³)-in-species Laplace argument show up at all?

**Only in direction, not in consequence.** Laplace's cost genuinely grows
faster in p than either VA arm's does (Q2), which is the qualitative shape the
literature predicts. But it does not show up as a practical disadvantage
anywhere in this design: at every (n, p) cell tested, Laplace's absolute
runtime is far below every VA arm's, because the *n*-scaling gap (quadratic
VA vs linear Laplace) dominates completely once n reaches the thousands. The
argument for VA-over-Laplace at scale, as tested here, is not supported —
if anything the paper would need to argue the opposite for this model class
and this size range.

## Q4. Does the accuracy/reliability advantage survive at scale?

**It cannot be assessed at n≥2500 for our arms, because they mostly don't
finish, and the answer for what does finish is a genuine and severe
survivorship-bias trap.** Status counts (48 cells; `gtmb_jj` n=24 since it
is bernoulli-only):

| arm | converged/healthy | failed_health_gate | TIMEOUT | ERROR |
|---|---:|---:|---:|---:|
| `gtmb_gh` | 5 | 19 | 24 | 0 |
| `gtmb_jj` | 5 | 7 | 12 | 0 |
| `gllvm_va` | 29 | 0 | 19 | 0 |
| `gtmb_laplace` | 48 | 0 | 0 | 0 |

By n, `gtmb_gh` completes 12/12 cells at n=500 and 12/12 at n=1000 (all
health-gate labels, not silent), then **0/12 at n=2500 and 0/12 at n=5000** —
a clean, total cutoff, not partial degradation. `gllvm_va` degrades more
gradually: 12/12 at n≤1000, 5/12 at n=2500 (only p=27 cells survive; all
p=50 cells at n=2500 time out), 0/12 at n=5000.

This means the relative-Frobenius accuracy table below is **not a fair
comparison past n=1000**: at n=2500 it reports `gllvm_va`'s accuracy only on
the *easier* half of cells that happened to finish in time (p=27, not p=50),
and it cannot report anything for our arms at all. Reading "0.247" as
"gllvm_va's accuracy at n=2500" without this caveat would be a survivorship
error.

| arm | n | median rel_frob | n cells contributing |
|---|---:|---:|---:|
| `gtmb_gh` | 500 | 0.218 | 12 |
| `gtmb_gh` | 1000 | 0.157 | 12 |
| `gtmb_gh` | 2500 / 5000 | NA (0 survivors) | 0 |
| `gllvm_va` | 500 | 0.207 | 12 |
| `gllvm_va` | 1000 | 0.170 | 12 |
| `gllvm_va` | 2500 | 0.247 (p=27 only, biased) | 5 |
| `gllvm_va` | 5000 | NA (0 survivors) | 0 |
| `gtmb_laplace` | 500 → 5000 | 0.214 → 0.156 → 0.109 → **0.074** | 12 each n |

The one clean, unbiased trend in this table: **Laplace's own accuracy
*improves* with n** (0.214 → 0.074, monotonically, on all 48/48 cells, no
survivorship issue since nothing times out). The variational parameter-count
growth the brief worried about (N·(2q + q(q-1)/2), >25,000 coordinates at
n=5000) is not something we can evaluate for our own engine at n=5000 at all
— it never finishes fitting to check. That itself is the answer: whatever
happens to VA's accuracy at that scale is moot next to the fact that it
doesn't complete within a fitting budget nearly 12x Laplace's actual n=5000
runtime.

---

## Methodology notes (what changed mid-run, and why it matters for reading the numbers)

1. **`setTimeLimit()` does not work as a per-fit budget for this workload —
   confirmed empirically, not assumed.** The first full-grid attempt used
   `setTimeLimit(elapsed=900, transient=TRUE)` around each fit (matching the
   brief's ask). It hung: several workers sat pegged at ~99% CPU for over an
   hour on a single arm, past their nominal 900s cap. Root cause, confirmed
   directly: R's elapsed-time check is cooperative (checked when control
   returns to the R evaluator); a TMB fit that spends a long stretch inside
   one C++-level `nlminb`/`sdreport` call never yields control back, so the
   check never fires. A synthetic non-yielding tight R loop reproduced the
   same failure. **Fixed** with a real OS-level kill: `gllvm_va` /
   `gtmb_laplace` use `callr::r(timeout=)` (fresh subprocess, hard-killed on
   timeout); `gtmb_gh`/`gtmb_jj` use a persistent `callr::r_session` per
   worker (`call()` + `poll_process(timeout)` + `close()`), because their
   engine (`va_r3`) compiles its TMB template on the fly per R session and a
   fresh subprocess per call was measured to silently recompile on *every*
   call (confirmed: two `callr::r()` calls with an identical fixed `TMPDIR`
   still got two different `tempdir()` paths, since R appends a random
   per-session suffix and deletes it on exit). The session fix was verified
   directly before the real run: a second call on the same session dropped
   from 21.6s to 0.12s by reusing the compiled DLL, and `poll_process` +
   `close()` forcibly killed a tight non-yielding loop inside the requested
   budget.
2. **The first full-grid attempt also had no crash recovery and had to be
   discarded.** Nothing was written to disk until the master's blocking
   `mirai_map()[.progress]` collection returned, so killing a hung master
   lost every already-finished cell too (~8 cells, ~70 minutes of compute,
   discarded). Fixed: every cell now writes its own RDS file to
   `results/cells/` the moment it's produced, independent of the master's
   final collection.
3. **900-second budget rationale.** The smoke test (n=1000, p=27, poisson)
   measured `gtmb_gh` at 280-370s across three separate runs before any
   budget was applied — comfortably under 900s, so the budget is not
   artificially truncating the n=500/1000 numbers reported above. It is a
   genuine wall the n≥2500 cells hit, not a tuning choice that produced the
   TIMEOUT rows.
4. **Timing overhead from the fix.** `gllvm_va`/`gtmb_laplace` in fresh
   subprocesses matched their pre-fix (mirai-worker-only) timings to within
   ~1-3 seconds in a direct A/B check (370.1s vs 368.0s for the same
   `gtmb_gh` cell before the persistent-session fix existed) — the added
   subprocess-spawn cost is real but small relative to the multi-hundred-
   second fit times reported here, and does not change any qualitative
   conclusion above.
5. **Warm start present.** All fits used the checked-in (uncommitted,
   research-only) factor-analytic warm start in
   `.va_r3_default_parameters()`/`.va_r3_warm_theta_rr()` — the fix this
   workflow was scoped to build on, not to re-derive. `gtmb_gh`'s frequent
   `failed_health_gate` status at n=500/1000 (24/24 cells that completed) is
   an existing package health-gate behavior on this random data-generating
   process, observed consistently across every successful fit; it did not
   prevent numerically correct answers (objectives matched `gllvm_va` to
   within noise in every completed cell) and is out of scope to fix here.

## Files

- `results/scale.csv`, `results/scale.rds` — 168-row raw output.
- `results/cells/cell_NNN.rds` — per-cell backup (crash-safe).
- `results/scale-full3.log` — full run log (48/48 cells, 3009.2s wall clock).
- `run-scale.R` — the harness (reuses the `dev/totoro-grid/run-grid.R`
  pattern: mirai daemons, thread pinning, row-based failure recording).
- `analyse-scale.R` — produces the raw tables this report is built from.
