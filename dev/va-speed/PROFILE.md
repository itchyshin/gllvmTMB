# VA-R3 speed profile: where the time goes

**Author:** Gauss (profiling slice, measurement only — no engine changes made).
**Branch:** `claude/va-speed-arc`, worktree `/private/tmp/gllvmtmb-va-speed`, cut from
`origin/main` @ `19e9cedd`.
**Scripts:** `dev/va-speed/01-q1-single-tier.R` (Q1+Q3 single-tier), `dev/va-speed/02-probe-inner-trace.R`
and `03-probe-hesspattern-once.R` (infrastructure probes), `04-q2-structured-tier.R` and
`05-q2-extended-ladder.R` (Q2+Q3 structured tier). Raw logs: `q1-log.txt`, `q2-log.txt`,
`q2-extended-log.txt`. Raw results: `q1-result.rds`, `q2-result.rds`, `q2-extended-result.rds`,
`q2-summary.csv`, `q2-extended-summary.csv`.

Every number below is a real measurement from a script that was actually run on this machine
(R 4.6.0, TMB 1.9.21, arm64 clang -O2, 20-core Mac). Nothing here is an estimate dressed up as a
measurement; where I extrapolate (GH-node scaling, the >3600 s reconciliation) it is labeled as
extrapolation, not fact.

---

## 0. Setup

**Q1 cell** (single tier): binomial-probit, N=250 units, T=20 traits, q=1, H=15 GH nodes,
`n_starts=1L`, `optimizer="nlminb"` (the family registry's own resolved choice — `auto` always
maps binomial-probit to GH quadrature + nlminb; there is no JJ-bound alternative for probit).
DGP: hand-rolled (no planted-truth recovery needed for a profiling slice), `traits(t1..t20) ~
latent(1|unit, d=1)` shape, 5,000 rows.

**Q2 cell** (structured tier): gaussian_anchor family (closed-form expectation, no GH — chosen
specifically so the GH cost visible in Q1 cannot confound the tier-structure question), T=8,
q=1, N (tips) in {20, 50, 100, 300, 600, 1000}. One extra tier: `kind="diagonal"`, `dim=T`,
`structured=TRUE`, levels = the augmented phylogenetic node set (`2N-2` levels, built via
`.va_r3_phylo_structure()` from an `ape::rcoal(N)` tree) — this is exactly the "diagonal tier of
dim T over 2N-2 levels" the brief names, i.e. the `phylo_latent(unique=TRUE)` Psi companion in
isolation. Every cell capped at `control=list(eval.max=20L, iter.max=10L)`, run under BOTH
`profile_variational=FALSE` (the default: `random=NULL`, every variational coordinate is an outer
"fixed" TMB parameter) and `profile_variational=TRUE` (Stage 7's `profile=` route: the
variational block goes through TMB's sparse inner Newton solve). A `setTimeLimit()` safety wall
(70–120 s) was set per cell in case a cell ran away; it was never triggered — every capped cell
in this report finished and is a real, completed measurement, not a timeout.

**One-time cost excluded from all "per-fit" totals below:** the first `TMB::MakeADFun()` call in
a fresh R session compiles `gllvmTMB_va_r3.cpp` (cached under `tempdir()`, keyed by source
md5sum). Measured compile time: **22.9 s** (Q1 script) / ~19–27 s (Q2 scripts, each a fresh
`Rscript` process so each repays it once). This is a fixed per-R-session tax, not a per-fit cost,
and is reported once here rather than folded into every table.

---

## Q1 — single-tier fit, seconds and % per bucket

N=250, T=20, q=1, H=15, n_starts=1, binomial-probit. **Total wall-clock (excl. one-time DLL
compile) = 18.266 s**, cross-checked against an independent, uninstrumented `.va_r3_fit()` call
on the identical cell: **18.581 s** (2 % apart — the instrumented replica is faithful).

| Phase | Seconds | % of total | Detail |
|---|---:|---:|---|
| `.va_r3_validate_data()` | 0.244 | 1.3% | data validation, tier layout, index checks |
| `.va_r3_make_objective()` (dll-load[cached] + `MakeADFun` taping) | 0.839 | 4.6% | n_par = 540 |
| **Primary `nlminb` optimization** | **16.253** | **89.0%** | 173 outer iterations |
| — of which `obj$fn()` | 5.511 | (33.9% of primary) | 215 calls, 25.6 ms/call |
| — of which `obj$gr()` | 10.576 | (65.1% of primary) | 174 calls, 60.8 ms/call |
| — of which nlminb's own R-level bookkeeping | 0.166 | (1.0% of primary) | linesearch/update logic only |
| Polish passes (gradient re-check + up to 2 re-`nlminb` runs) | 0.593 | 3.2% | 2 passes actually run; 0.459s is the 2 `nlminb` re-runs themselves, 0.134s is the gradient re-checks between them |
| L-BFGS-B fallback (triggered: post-polish `\|grad\|` still ≥ 1e-4) | 0.248 | 1.4% | did not improve on nlminb's optimum |
| Post-processing: final `gr()` + `report()` + `.va_r3_latent_posterior()` | 0.089 | 0.5% | **no `sdreport()` anywhere in `.va_r3_fit()`** — confirmed by reading the full function body and by `grep -n sdreport R/va-r3-proto.R R/approximation-engine.R` (zero hits); VA-R3 has no SE/sdreport machinery, so this bucket does not exist for this engine |
| **TOTAL** | **18.266** | **100%** | |

**fn/gr dominate everything**: across the whole fit (primary + polish + lbfgsb + post-processing),
227 `fn()` calls (5.810 s) + 185 `gr()` calls (11.222 s) = **17.03 s = 93.2% of total wall-clock**
is spent evaluating the TMB objective/gradient. Only 6.8% is R-level orchestration
(`validate_data`, `make_objective`, nlminb bookkeeping, polish-loop logic, report/latent
extraction). Independent cross-check via `Rprof(interval=0.01)` sampling during the primary phase:
**96.6%** of sampled time (13.18 s of 13.65 s) is inside `.Call` (native/compiled TMB code) — the
`summaryRprof()` table:

```
                self.time self.pct total.time total.pct
.Call               13.18    96.56      13.65    100.00
proc.time            0.44     3.22       0.44      3.22
f                     0.02     0.15      13.10     95.97
EvalADFunObject       0.01     0.07      13.08     95.82
```

(Rprof cannot see *inside* `.Call`, so this is a coarser, independent corroboration of the fn/gr
split above, not a finer one — it confirms the dominant cost is compiled TMB code, not R.
`line.profiling=TRUE` was tried and dropped: both TMB's evaluator and `nlminb`'s own PORT driver
are compiled code reached through a single native call, so line-level R profiling has no R source
lines to attribute time to on the side that actually matters — it would only resolve the ~3–7%
that is genuinely R-level bookkeeping, which the wrapper timers already isolate directly and more
precisely.)

### GH-quadrature share (empirical, via H-node scaling — never modifies the C++ template)

Held N/T/q/data/parameter-vector fixed, varied H over its three admitted values, timed 30 reps of
`obj$fn()`/`obj$gr()` each:

| H | fn ms/call | gr ms/call |
|---:|---:|---:|
| 15 | 23.27 | 57.13 |
| 25 | 46.67 | 110.27 |
| 61 | 92.63 | 226.47 |

Linear in H (as expected — the GH loop is `for h in 1..H` per row): fn ≈ 5.49 + 1.446·H ms,
gr ≈ 11.42 + 3.560·H ms. Extrapolating to H=15, the **GH-attributable share is 79.8% of a single
`fn()` call and 82.4% of a single `gr()` call**; the remainder (≈20%) is H-independent overhead
(linear predictor, per-row family dispatch, KL, AD bookkeeping). Cross-check: 215 fn calls in the
real optimization run cost 5.511 s ⁄ 215 = **25.6 ms/call**, matching the H=15 scaling measurement
(23.27 ms/call) to within 10%; 174 gr calls cost 10.576 s ⁄ 174 = **60.8 ms/call** vs. 57.13
ms/call scaling estimate — good agreement, and both slightly higher in-run than in the scaling
probe, consistent with the in-run parameter vector being further from the (cheaper, more linear)
starting point.

Combining: **GH quadrature accounts for roughly 0.93 (fn+gr share of total) × ~0.81 (GH share of
fn+gr) ≈ 75% of the entire single-tier fit's wall-clock.** Mechanistically (read from
`inst/tmb/gllvmTMB_va_r3.cpp`): `va_r3_probit_expectation()` runs a `for (h in gh_nodes)` loop
**per observation row** (N×T = 5,000 rows × H = 15 nodes = 75,000 inner-loop evaluations per
`fn()` call), each iteration calling a tail-safe `log Φ` (`va_r3_log_pnorm`/`va_r3_inv_mills`,
itself a branching, several-operation expression) twice (for y and n−y). Every one of those
operations is taped for AD, which is why `gr()` costs ~2.4–2.5× `fn()` at every H — a normal
reverse-mode AD constant, not a red flag.

*Caveat:* the GH-scaling probe builds a **fresh objective per H** (fresh `MakeADFun`), so each
30-rep average's first call also pays TMB's one-time lazy "Optimizing tape" setup (see §Q2
below) — diluted 1-in-30 but not zero. This biases the fitted intercept slightly upward and the
GH share slightly downward, i.e. if anything the true GH share is ≥ the 75–82% reported here.

### Multistart overhead (Q1, this cell size)

| | seconds |
|---|---:|
| `n_starts=1` (real `.va_r3_fit()` call) | 18.58 |
| `n_starts=4` (real `.va_r3_fit()` call, the package default) | 72.12 |
| **multiplier** | **3.88×** |

Matches the source's own documented figure (`R/va-r3-proto.R` ~line 1997: "3.33x at N=200 and
3.93-4.45x at N=400") closely. **If the reported 47.3 s median used the default `n_starts=4`, a
per-start cost in the 47.3/3.88 ≈ 12 s range is consistent with this decomposition** — the
47.3 s figure does not require any mechanism beyond "GH-dominated per-start cost × the multistart
gate," though I did not reproduce the exact original cell (N/T/family/seed unknown to me) so this
is a consistency check, not a byte-for-byte reproduction.

---

## Q2 — structured phylogenetic tier: per-iteration cost, both routes, full N-ladder

**Capped run (`eval.max=20, iter.max=10`) — every cell below actually completed; none hit the
70–120 s safety wall.** The "capped-run wall" column below is `nlminb`'s own wall-clock only:
`.va_r3_make_objective()` (taping, always well under 0.3s once the DLL is cached — see §"Where
the joint route's cost actually is" below) and a one-time priming `fn()+gr()` call (which pays
TMB's one-time lazy tape-optimization / Hessian-pattern-matching setup, 0–0.88s, growing slowly
with N) are timed separately and are NOT in this column, so the capped-run numbers are steady-state
per-iteration cost, not contaminated by one-time setup.

| n_tip | n_aug (2N−2) | route | outer par | capped-run wall (s) | fn calls | gr calls | fn+gr time (s) | fn+gr share of wall | per-call (ms) |
|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 20 | 38 | joint (`profile=FALSE`) | 680 | 0.015 | 14 | 11 | 0.001 | 6.7% | 0.60 |
| 20 | 38 | profile (`profile=TRUE`) | 32 | 0.040 | 17 | 11 | 0.040 | 100% | 1.43 |
| 50 | 98 | joint | 1,700 | 0.112 | 17 | 11 | 0.002 | 1.8% | 4.00 |
| 50 | 98 | profile | 32 | 0.087 | 15 | 11 | 0.087 | 100% | 3.35 |
| 100 | 198 | joint | 3,400 | 0.629 | 20 | 11 | 0.010 | 1.6% | 20.29 |
| 100 | 198 | profile | 32 | 0.146 | 14 | 11 | 0.146 | 100% | 5.84 |
| 300 | 598 | joint | 10,200 | 5.825 | 15 | 11 | 0.022 | 0.38% | 224.04 |
| 300 | 598 | profile | 32 | 0.450 | 15 | 11 | 0.450 | 100% | 17.31 |
| 600 | 1,198 | joint | 20,400 | 18.455 | 21 | 9 | 0.038 | 0.21% | 615.17 |
| 600 | 1,198 | profile | 32 | 0.872 | 15 | 11 | 0.871 | 99.9% | 33.54 |
| **1,000** | **1,998** | **joint** | **34,000** | **70.327** | 21 | 10 | 0.117 | **0.17%** | **2,268.61** |
| 1,000 | 1,998 | profile | 32 | 1.507 | 15 | 11 | 1.506 | 99.9% | 57.96 |

**n_tip=100, n_aug=198 is the exact cell named in the brief** ("198 levels at N=100"). At that
cell, the capped run finishes in well under a second on both routes (0.629 s joint, 0.146 s
profile) — **the catastrophe is not yet visible at N=100 with T=8.** It becomes visible by
extrapolation of the trend below, and directly measured once N is pushed to 1,000 (still a small,
fast cell to build/run).

### Where the joint route's cost actually is

`outer par = 34 × n_tip` **exactly**, at every single N tested (680/20, 1700/50, 3400/100,
10200/300, 20400/600, 34000/1000 all equal 34.0). This is the flattened variational parameter
count (`m`, `log_L_diag` for both tiers) plus the small global block, and under
`profile_variational=FALSE` **all of it** is an outer "fixed" parameter that `nlminb` must
optimize directly.

The **fn+gr share of wall-clock collapses monotonically as N grows**: 6.7% (N=20) → 1.8% (N=50) →
1.6% (N=100) → 0.38% (N=300) → 0.21% (N=600) → **0.17% (N=1000)**. This means **the actual TMB
objective/gradient evaluation stays cheap throughout (117 ms of fn+gr time even at N=1000,
outer par=34,000) — it is `nlminb`'s own internal bookkeeping (its quasi-Newton Hessian
approximation, stored and updated as a dense packed matrix of size `outer_par×(outer_par+1)/2`)
that consumes 99.8%+ of the wall-clock at large N.** At outer par = 34,000, that packed
approximation alone is `34000×34001/2×8` bytes ≈ **4.6 GB** — a plausible mechanism for the
observed super-linear (see below) blowup being partly memory-bandwidth-bound, not purely
FLOP-bound.

Fitted power-law exponent for joint per-call cost vs. n_tip (log-log, full 6-point range,
20→1000): **≈ N^2.1** (endpoints: 0.60 ms → 2,268.61 ms over a 50× range in N ⇒
log(2268.61/0.60)/log(1000/20) = 2.106). Local exponents are consistent across sub-ranges
(20→100: 2.19; 100→600: 1.90; 600→1000: 2.55 — noisy at the last step, plausibly the ~4.6 GB
allocation starting to bind) — **the growth is genuinely super-linear throughout, not a
threshold effect that only appears at one N.**

By contrast, the **profile route's outer par is pinned at 32 regardless of N** (confirmed at
every N tested), and its fn+gr share of wall-clock is **≈100% at every N** — essentially zero
`nlminb` bookkeeping overhead, because 32 parameters is trivial for a dense quasi-Newton method.
Fitted exponent for profile per-call cost vs. n_tip: **≈ N^0.9–1.0** (1.43 ms → 57.96 ms over the
same 50× range ⇒ log(57.96/1.43)/log(50) = 0.947) — consistent with the augmented node count
(`n_aug = 2N−2`, the true size of the sparse inner-solve problem) growing linearly and the
solve cost tracking it linearly, exactly as Stage 7's own `nnz/dim` = flat finding predicted.

**Ratio (joint per-call ÷ profile per-call) grows from 0.42× (N=20, joint is actually cheaper) to
1.20× (N=50) to 3.47× (N=100) to 12.94× (N=300) to 18.34× (N=600) to 39.14× (N=1000)** — a clean,
monotonic, accelerating divergence between the two routes as the structured tier's level count
grows.

### Inner Newton iterations (profile route only — no inner solve exists under joint)

Traced via `inner_control=list(trace=TRUE)`, capturing TMB's own per-inner-iteration console
output (`iter: k value: ... mgc: ...`) around individual `fn()`/`gr()` calls (a **separate,
untimed** run — capture.output() overhead is real and this trace is for counts only, never for
the timing numbers above):

| n_tip | n_aug | calls traced | mean inner iters/call | max inner iters/call |
|---:|---:|---:|---:|---:|
| 20 | 38 | 14 | 3.43 | 15 |
| 50 | 98 | 14 | 3.57 | 17 |
| 100 | 198 | 14 | 3.86 | 19 |

**Flat, not exploding** (3.4 → 3.9 mean over a 5× range in N) — a cold-start `fn()` call needs up
to ~14–19 inner Newton iterations (a fresh problem), but every subsequent call at a nearby outer
point warm-starts from `last.par.best[random]` and typically needs 1–3. This directly rules out
"inner iteration count" as the driver of the profile route's (already small) cost growth — it
is genuinely the linear-in-N sparse-Cholesky solve cost, not more inner iterations.

Two **one-time-only** costs were also identified and isolated (via
`dev/va-speed/03-probe-hesspattern-once.R`, which called `fn()`/`gr()` repeatedly and watched
which trace lines repeat): TMB's "Optimizing tape... Done" (appears on the very first `fn()` call
only) and "Matching hessian patterns... Done" (appears on the very first `gr()` call only, under
`profile_variational=TRUE` — this is the sparse-Hessian symbolic factorization/fill-reducing
permutation, computed once and cached). Both are folded into the `t_prime` ("priming fn+gr")
column of the raw results, kept separate from the steady-state per-call cost reported above so
neither contaminates it. Neither was a large absolute cost at the N tested here (priming time
ranged 0–0.88 s, growing slowly with N — plausibly this cost, too, eventually matters at much
larger N, but it was never the dominant bucket in any cell measured).

---

## Q3 — iteration and evaluation counts

**Single-tier (Q1), n_starts=1, converged (`convergence=0`):**

| | count |
|---|---:|
| nlminb outer iterations (primary phase) | 173 |
| `fn()` evaluations (primary phase) | 214 |
| `gr()` evaluations (primary phase) | 174 |
| `fn()` evaluations (whole fit: primary + polish + lbfgsb) | 227 |
| `gr()` evaluations (whole fit) | 185 |
| polish passes actually run | 2 of 2 allowed |
| L-BFGS-B fallback triggered | yes (did not improve on nlminb's optimum) |

**Structured tier (Q2), every cell, both routes:** deliberately capped at `eval.max=20,
iter.max=10` per the brief ("do NOT try to run the structured tier to completion"). **Every
single cell — all 12 (6 N-values × 2 routes) — hit the cap** (`nlminb` message "iteration limit
reached without convergence (10)"; iterations recorded as 9 or 10, fn calls 14–21, gr calls
9–11). This means: (a) I cannot report a genuine to-convergence iteration count for the structured
tier under either route — that would require exactly the uncapped run the brief says not to do —
and (b) even gaussian-anchor synthetic data with **no** recovery target needed *more* than 10
iterations at *every* N on *both* routes, so the structured problem is not trivially easy to
optimize regardless of route. What is measured cleanly is the **per-iteration cost**, which is
the quantity that actually determines whether a real (uncapped) fit finishes in seconds or hours
— see the ranked list below.

---

## Ranked list: where the time actually is

1. **Single-tier (Q1): the Gauss-Hermite quadrature loop inside `fn()`/`gr()`, ≈75% of total
   wall-clock.** `va_r3_probit_expectation()` runs H=15 GH nodes × 2 tail-safe `log Φ`
   evaluations, per observation row (N×T=5,000 rows), taped for AD. `gr()` costs ~2.4–2.5× `fn()`
   throughout (normal reverse-mode AD overhead). fn+gr together are 93.2% of the whole fit's
   wall-clock; nlminb/R-level overhead is negligible (540 outer parameters is small).

2. **Structured tier (Q2): NOT TMB's tape, NOT GH (none present, family is closed-form), NOT the
   inner solve's fill-in or iteration count (Stage 7 already showed nnz/dim flat; this report's
   own inner-trace shows iteration count flat too) — it is `nlminb`'s own outer quasi-Newton
   bookkeeping over a parameter vector that grows linearly with N under the DEFAULT
   `profile_variational=FALSE` route.** At N=1000 (outer par=34,000), 99.83% of the capped run's
   wall-clock is `nlminb` overhead; only 0.17% is genuine `fn()`/`gr()` work, and that overhead
   scales as ≈N^2.1 empirically (vs. ≈N^0.9–1.0 for the already-built `profile_variational=TRUE`
   route, whose outer par stays pinned at 32 regardless of N). This is a **per-iteration cost**
   problem, not (as far as measurable under the mandated cap) an iteration-*count* problem — see
   the answer to the specific question below.

3. **Everything else is a rounding error next to (1) and (2):** DLL compile (22.9 s, one-time per
   R session, not per-fit); `validate_data` (1.3% of Q1); `make_objective`/taping (4.6% of Q1,
   and 0.006–0.25 s — never more than a few hundred ms — at every N tested in Q2, i.e. tape
   *construction* cost does not itself scale badly even when the resulting tape is evaluated by a
   route that scales badly); polish passes, L-BFGS-B fallback, post-processing (report,
   `.va_r3_latent_posterior()`) together under 5% of Q1's total; **no `sdreport()` bucket exists
   for VA-R3 at all** (confirmed by reading the full `.va_r3_fit()` body and by grep — zero
   hits — so this candidate bucket from the brief is real but empty for this engine); multistart
   is a clean ×3.88 multiplier on top of all of the above, matching the source's own documented
   figure.

---

## Direct answers to the brief's three questions

**Q1 (single-tier, seconds/% per bucket):** primary `nlminb` optimization is 89.0% of wall-clock,
of which fn+gr evaluation is 99.0%; GH quadrature is ~75–82% of every fn/gr call. See table above.

**Q2 (structured-tier, per-iteration, ~56× blowup):** **the coordinate count is the driver, but
specifically through its effect on the OUTER optimizer's own bookkeeping under the default
(non-profiled) route — not through TMB's tape, the AD evaluation cost, GH quadrature, or the
inner solve's fill-in/iteration count, all four of which were directly measured here (or by
Stage 7) and ruled out.** The already-built, already-validated-for-correctness
`profile_variational=TRUE` route sidesteps the problem entirely by keeping the outer parameter
count constant at 32 regardless of N; at N=1000 that is already a measured 39× per-call speedup
over the default route, growing every time N doubles.

**Q3 (iteration/evaluation counts):** single-tier converges genuinely in 173 nlminb iterations /
214 fn / 174 gr calls (n_starts=1). Structured-tier: not measurable to convergence without
violating the "do not run to completion" instruction — every capped cell (12 of 12) hit the
10-iteration cap on both routes, so the deliverable number here is **per-iteration cost**, which
is what the ranked list above reports.

**Per-iteration vs. iteration-count:** answered as far as it can honestly be answered under the
mandated cap. **Per-iteration cost is the directly measured, unambiguous driver of the
joint-vs-profile divergence** (39× at N=1000, growing). Whether the joint route *also* needs more
iterations than the profile route to reach the same converged point is **not measured here** —
both routes hit the cap at every N, so no to-convergence iteration count exists for either. Given
Stage 6's own after-task report already found the joint route needs comparable-or-more iterations
than the profile route on a *different* multi-tier model (and reaches a *worse* gradient even
where nlminb reports convergence), the true gap at full convergence is unlikely to be smaller than
the per-iteration-cost gap measured here — but that is an inference from a different model, not a
measurement from this one, and is flagged as such.

---

## Reconciling the >3600 s claim (extrapolation, clearly labeled)

Not a measurement — a consistency check using the measured per-call costs above. At the brief's
own N=100 (n_aug=198), T=8, the joint route's capped run is fast (0.629 s for ~20 calls); the
catastrophe is not visible there in my cell. Two things not matched between my cell and whatever
produced the >3600 s figure: (a) the original almost certainly uses T=20 (matching the paper's
single-tier cell) and/or binomial-probit (GH-loaded) rather than my closed-form gaussian_anchor —
both raise absolute per-call cost, but neither changes the mechanism; (b) most importantly,
**the original was very likely run with the package's default, UNCAPPED `control=list(eval.max=
2000L, iter.max=2000L)`, not a 10-iteration cap.** Extrapolating my own measured N=1000 joint
per-call cost (2.27 s) to even a few hundred real iterations (nlminb never converged in 10 at any
N in this study) already reaches into the 1,000+ second range; the brief's N=100 case, if it also
needed hundreds-to-thousands of iterations to satisfy the health gate's 1e-4 gradient tolerance
(as Q1's own single-tier fit needed 173 iterations for a *20×* smaller outer-parameter problem),
is fully consistent with a multi-thousand-second, non-finishing run — **without requiring any
mechanism beyond the one measured directly in this report.**

---

## Buckets I could not attribute cleanly (flagged, not invented)

- **The exact cell that produced the original 47.3 s / >3600 s numbers is unknown to me** (seed,
  exact T for the structured case, n_starts, control list). Every comparison above is a
  consistency check against my own freshly-measured cells, not a byte-for-byte reproduction.
- **Structured-tier to-convergence iteration counts, for either route, at any N.** Blocked by the
  brief's own "do not run to completion" instruction — reported as a cap-hit at every cell
  instead of invented.
- **Rprof line-level attribution inside TMB's compiled code** is fundamentally unavailable
  (`.Call` is an opaque leaf to any R sampling profiler); the fn/gr wrapper timers and the
  GH-node scaling experiment are the honest substitutes used here, cross-checked against each
  other (25.6 ms/call measured in-run vs. 23.27 ms/call in the isolated H=15 scaling probe).
- **The GH-share estimate (79.8%/82.4%) carries a small upward-biased intercept** because the
  scaling probe rebuilds the objective per H, so each 30-rep average's first call also carries a
  diluted (1/30) share of TMB's one-time lazy tape-optimization cost — flagged in §Q1, not
  corrected for (the true GH share is very likely slightly higher, not lower, than reported).
- **Memory was not directly measured** in this report (only wall-clock and counts, per the brief's
  method). The ~4.6 GB estimate for `nlminb`'s packed Hessian approximation at N=1000 is an
  arithmetic inference from the known PORT storage format (`n(n+1)/2` doubles), not a measured
  RSS — flagged as inference, consistent with (and considerably smaller in scale than) Stage 6's
  own *measured* RSS table for a different multi-tier model (188 MB → 1,935 MB → ≥6,460 MB DNF
  over N=1,000 → 4,000 → 8,000 under the same joint route).
