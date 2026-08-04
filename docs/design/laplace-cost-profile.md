# Where the shipped Laplace engine spends its time

Status: local finding, D-50. Not promoted, not advertised, nothing committed.
Regime for every number below unless stated otherwise: `cbind(succ, fail) ~ 0 +
trait + latent(0 + trait | unit, d = q, unique = FALSE)`, `family =
binomial(link = "probit")`, default `gllvmTMBcontrol()` (`se = TRUE`, `n_init
= 1L`, `aghq = FALSE`), installed (shipped) package, single-threaded, Totoro.

## The answer, in three sentences

Cold Laplace spends its time almost entirely in two phases — the outer
`nlminb` optimisation with its per-iteration sparse-Cholesky refactorisation
(58–77% of wall time) and `TMB::sdreport()`'s precision-matrix
factorisation for standard errors (22–39%) — with AD-tape construction and
all R-side overhead together under 3% everywhere measured. Yes, this changes
with model size: the optimiser's share climbs from ~58% toward ~77% as the
latent dimension `q` grows (N alone has a much smaller effect once `q` is
fixed), while `sdreport`'s *relative* share shrinks even as its absolute cost
grows by ~33× across the grid. Only `sdreport` is removable at zero
statistical cost to a point-estimate-only user (`se = FALSE`, ~22–39% saved
immediately); the dominant optimiser phase is structural — its cost tracks
`n_random` and outer-iteration count, not starting values — so it cannot be
warm-started away, which is exactly why the VA→LA hybrid tops out near 1.1×
and turns net-negative (0.84×, i.e. *slower*) at N=1000, q=2.

## 1. The phase table and its trend

Method: two independent measurements agree at the anchor cell — `Rprof`
sampling (`38-profile-rprof.R`) and explicit `trace()`-based wall-clock
instrumentation of `TMB::MakeADFun`, `stats::nlminb`, `TMB::sdreport`, and
`gllvmTMB:::gllvmTMB_multi_fit` (`39-profile-phases.R`, generalised to
`41-profile-ladder.R` for the scaling grid). Both agree within ~1
percentage point at N=250, q=2. **The MakeADFun/R-side numbers below are
corrected** for a double-counting bug caught in adversarial review (§3,
defect A) — `sdreport()` rebuilds its own internal AD tape (`obj2 <-
MakeADFun(..., ADreport = TRUE, ...)`, unconditional, near the top of
`TMB::sdreport`'s body), and that nested call's window sits entirely inside
the `sdreport` window that is separately timed, so summing *all* MakeADFun
calls double-counts it. The correction moves ~21–22% of the reported
"MakeADFun" bucket into the R-side residual, which flips that residual from
an impossible negative number to a small, plausible positive one. `nlminb`
and `sdreport` shares are untouched by the correction — the double count was
entirely inside the smallest bucket.

| cell | N | q | n_random | outer iters | total (s) | R-side | MakeADFun (corrected) | nlminb | sdreport |
|---|---|---|---|---|---|---|---|---|---|
| N250_q2  | 250  | 2 | 500   | 159 | 17.1   | 0.28% | 2.02% | 58.37% | 39.32% |
| N1000_q2 | 1000 | 2 | 2000  | 169 | 70.6   | 0.24% | 1.94% | 60.00% | 37.81% |
| N2500_q2 | 2500 | 2 | 5000  | 185 | 190.1  | 0.23% | 1.86% | 61.37%\* | 36.53%\* |
| N250_q5  | 250  | 5 | 1250  | 445 | 76.8   | 0.09% | 0.55% | 71.22% | 28.14% |
| N1000_q5 | 1000 | 5 | 5000  | 634 | 394.0  | 0.07% | 0.43% | 77.32% | 22.18% |
| N2500_q5 | 2500 | 5 | 12500 | 674 | 1012.1 | 0.06% | 0.43% | 77.45%\*\* | 22.06%\*\* |

\* Load contamination flagged in original SCALING caveats (pre-run load 7.2,
peak 35.5 mid-run). \*\* Load contamination **not originally flagged but
present** — see §3, defect B: pre-run load 32.4, dropping to 3.2 by the end.
Both starred cells' shares carry lower confidence than the other four
(load < 6 throughout).

**Trend.** `nlminb`'s share is the one that grows with scale, and it is
driven mainly by `q`, not `N`. At fixed `q=2`, `N` 250→2500 (10×) moves the
optimiser share only 58.4%→61.4% (+3.0pp). At fixed `q=5`, the same `N`
range moves it 71.2%→77.5%, but essentially all of that jump happens by
N=1000 (71.2%→77.3%) and then flattens (77.3%→77.5% from N=1000→2500). The
mechanism is outer-iteration count: raising `q` from 2 to 5 roughly triples
outer iterations at fixed N (159→445 at N=250; 185→674 at N=2500), while `N`
alone barely moves iteration count at fixed `q` (159→185 at q=2; 445→674 at
q=5). Given the iteration count, per-iteration cost then tracks `n_random`
close to linearly (confirmed independently in both series: a 4× increase in
`n_random` from N=250→1000 produces a 3.9–4.0× increase in nlminb-seconds
per iteration, at both q=2 and q=5) — consistent with the sparse-Cholesky
refactorisation hypothesis (candidate b), and *not* dependent on starting
values.

`sdreport`'s absolute cost grows substantially (6.7s→69.5s at q=2; 21.6s→
223.3s at q=5, roughly 33× for a 25× increase in `n_random`, mildly
superlinear) but its **share** shrinks everywhere because `nlminb`'s
absolute cost grows even faster. AD-tape construction (`MakeADFun`, primary
tape only) and R-side overhead both stay small and shrink further in share
as the model grows; neither is a plausible target at any tested size.
Nothing was tested at larger `T` (traits held at 20 throughout, per the
brief's grid); R-side overhead could plausibly matter more there and remains
unmeasured.

## 2. Is `sdreport` optional? Yes, concretely

`gllvmTMBcontrol(se = TRUE)` is the default (`R/gllvmTMB.R:1462`).
`TMB::sdreport()` runs unconditionally at `R/fit-multi.R:6087` unless the
user explicitly sets `se = FALSE`, which gates it at line 6082–6084. Point
estimates (`opt$par`, `obj$report()`) are already fully computed *before*
`sdreport()` is called, so `se = FALSE` changes nothing about the fitted
values — it only removes the standard errors. At the anchor cell this is a
real ~1.6× wall-time reduction (17.0s → ~10.3s, independently measured); at
scale the *absolute* saving grows to over three minutes at the largest grid
cell (223s of 1012s at N2500_q5) even though its *share* has fallen to ~22%.
This is a genuinely free lever for any user who only wants point estimates —
not a partial mitigation, a full skip.

## 3. Adversarial defects and their resolution

Two independent adversarial reviews were run against the profile and
scaling deliverables. No defect overturns the headline qualitative
conclusion (`nlminb` + `sdreport` together are ~97–98% of wall time,
`nlminb`'s share grows with scale, driven mainly by `q`). Three items
materially changed numbers or claims; they are resolved below, not
retracted.

**Defect A (SERIOUS, both reviewers) — double-counted nested `MakeADFun`
call.** `sdreport()` internally rebuilds an AD tape (`obj2 <- MakeADFun(...,
ADreport = TRUE, ...)`, confirmed by reading `body(TMB::sdreport)`); that
call's timing window sits inside the `sdreport` window that scripts
39/41 also sum, so summing *all* `MakeADFun` calls counted ~21–22% of the
reported "MakeADFun" bucket twice. This forced the scripts' own printed
"R-side untraced" residual negative at every one of 7 measured cells (as low
as −0.31%) — a physically impossible number, and exactly the "quietly
absorbed remainder" failure mode this task was asked to hunt for. **Resolved
here**: the phase table in §1 nets out the nested call from the
`MakeADFun` bucket and adds it back to `sdreport` (where its wall time
genuinely belongs), leaving a small positive R-side residual (0.06–0.28%) at
every cell. `nlminb` and `sdreport` shares are unaffected — the bug lived
entirely inside the smallest bucket and does not touch the dominant-phase
conclusion. `41-profile-ladder.R`'s saved `.rds` tables remain wrong as
computed and should be treated as raw event logs, not as the final phase
table; §1's table is the corrected one.

**Defect B (SERIOUS, one reviewer) — undisclosed load contamination at
N2500_q5.** The original SCALING caveats flagged only N2500_q2 (load 7.2→
35.5) as running under contention; N2500_q5 — the single largest cell
(1012s) and the cell that anchors the "nlminb share plateaus near 77–78%"
claim — started under comparable contention (load 32.4, easing to 3.2 by the
end) that was not disclosed. **Resolved here**: both cells are now flagged
in §1's table (starred), and the plateau claim in §1 is stated with the
caveat that its anchor cell carries reduced confidence, not as an
unqualified result.

**Defect C (SERIOUS, one reviewer) — the offered reconciliation for "large
optimiser share vs. small end-to-end warm-start saving" was wrong when
tested directly.** The original profile speculated (explicitly flagged as
untested inference) that a near-exact VA seed "can only shave iteration
count modestly" because per-iteration cost is structural. A direct test (new
script `42-iter-count-check.R`, 4 paired seeds at the exact matched cell, run
on Totoro) shows outer-iteration count actually drops *substantially* under
warm start — seed-by-seed −41.5%, −43.4%, −48.8%, −24.8% (average −39.6%) —
not modestly. **Resolved, not retracted**: the large iteration-count drop is
real, but end-to-end wall time still only improves 3.7–13.6% (avg ~8%,
consistent with the previously-established 1.06–1.13×) because (i)
`sdreport`'s ~39% share is completely warm-start-insensitive (it runs on the
converged fit regardless of how it got there) and (ii) the VA sub-fit itself
costs ~3.5–4.5s at this cell, and both erode most of the nlminb-side
savings. §4 below uses this corrected mechanism.

**Minor items, noted not re-litigated.** (i) The profile's "surprises" bullet
cited `TMB::sdreport`'s `obj3` (bias-correction path) alongside `obj2` as
joint evidence for nested rebuilds; `obj3` only runs under
`bias.correct = TRUE`, which this campaign's calls never used, and the event
logs confirm exactly one nested `MakeADFun` call per fit (`obj2` only) — no
numeric claim was wrong, but the citation overstated the mechanism. (ii)
Script 38's raw output files (`rprof-shipped-la.out`,
`rprof-shipped-la-summary.rds`) live at the lane root
(`~/gllvm_work/va-lane2/`), not under `dev/va-speed/` as originally cited —
an organisation gap, not a numeric one; the recovered numbers matched the
quoted figures exactly. (iii) The warm-start baseline (scripts 33–37, via
`devtools::load_all()`) and this profile campaign (scripts 38–42, via the
installed package) draw on two different `.va_r3_fit()` code snapshots — the
installed version lacks `binomial_probit`/`eval_method = "ac"`/
`collapse_variational_cov`. The assumption that the LA-side code path is
identical between the two was asserted, never formally diffed; partial
corroboration exists (both report `opt$iterations = 159` for the same seed
at the matched cell), but this remains an open gap, flagged rather than
closed.

## 4. Consistency check against the warm-start evidence

There is no contradiction between "the dominant phases are large" (§1) and
"the near-exact warm start only saves ~1.06–1.13× end-to-end" — once
defect C's direct test (script 42) replaces the original speculative
mechanism. Warm-starting genuinely cuts outer-iteration count by ~40% on
average at the matched cell, which is a real effect on the `nlminb` phase.
But two things the warm start cannot touch absorb most of that saving before
it reaches the end-to-end number: `sdreport` (~39% of cold wall time,
completely insensitive to how the fit was reached) and the VA sub-fit's own
cost (~3.5–4.5s at this small cell, growing steeply with scale per the
earlier hybrid-scaling campaign — up to 181s at N=1000,q=5 and 228s at
N=2500,q=2, VA-only). The hybrid's net saving is therefore the *difference*
between a real but partial `nlminb`-phase gain and a fixed VA-fit tax plus
an untouched `sdreport` tax — small at best, and, per the earlier
hybrid-scaling ladder (claim 38 in the claims ledger), *negative* once N
grows past ~1000 at q=2 (0.84×, i.e. slower than cold LA).

## 5. Ranked speed levers

Ranked by estimated payoff; "statistical cost" column states whether the
lever changes fitted values/SEs for a user who wants them.

| # | lever | payoff | statistical cost | risk / effort |
|---|---|---|---|---|
| 1 | **`se = FALSE` on demand** (defer/skip `sdreport`) | ~1.6× at small models (N250,q2: 17.0s→10.3s); ~22–39% of wall time everywhere measured, growing in absolute seconds with scale (up to 223s saved at the largest grid cell) | **NONE** for point-estimate-only use; SEs simply absent until requested | LOW. Already gated by an existing control flag; the improvement is packaging it as a documented "fit now, get SEs later" recipe (e.g. a lazy `sdreport()`-on-demand accessor) rather than an engineering change |
| 2 | **Avoid `sdreport`'s internal nested tape rebuild** (its own `obj2 <- MakeADFun(..., ADreport = TRUE)`) | small — ~0.5–1pp of total wall time at every cell (the nested call is itself only ~21–22% of an already-small MakeADFun bucket) | NONE if done correctly (same SEs, cheaper route to them) | MODERATE-HIGH effort: this lives inside `TMB::sdreport()`, not in this package's code; would require either a TMB-level change/PR or reimplementing the SE extraction locally. Low payoff for the effort — deprioritise |
| 3 | **Reduce sparse-Cholesky / per-iteration cost** (candidate b, the actual dominant phase, 58–77% of wall time) | **potentially the largest available**, since it is the majority phase everywhere measured | Depends entirely on HOW: an algorithmic/solver-level improvement (better sparsity exploitation, alternative sparse Cholesky backend, precomputed symbolic factorisation reuse across iterations) is statistically free; loosening convergence tolerances to cut iteration count directly changes point estimates and is NOT free | HIGH effort, HIGH uncertainty of payoff without a solver-level investigation this task did not attempt. The single most promising unexplored lever, but a genuinely separate engineering project, not a quick fix |
| 4 | **VA→LA warm-start hybrid** (the arc this profile was commissioned to evaluate) | ~1.06–1.14× at N≤250, **0.84× (slower) at N=1000, q=2** — net saving is capped by lever 1's untouched share plus the VA sub-fit's own cost, which grows faster with scale than the saving it buys | NONE (lands on the identical optimum, per the claims ledger's claim 37) | Already built and measured. **Not worth further investment as a speed lever** — report as a ~1.1× curiosity, bounded above by `sdreport`'s untouchable share and bounded below (i.e. made negative) by the VA sub-fit's own growing cost |
| 5 | **R-side overhead reduction** (formula parsing, model-matrix construction, wrapper checks) | negligible at every tested cell (<0.3% at N250,q2, shrinking further at scale) | NONE if pursued, but there is essentially nothing to remove at this problem size | Untested at larger `T` (traits held at 20 throughout); not a lever at any size measured here |

## 6. What this means for the VA→LA hybrid

The dominant cost of a cold Laplace fit is the outer sparse-Newton
optimisation (58–77% of wall time, growing in share with `q`) plus
`sdreport` (22–39%, shrinking in share but growing hugely in absolute
seconds). Neither is warm-startable in the way that matters: `sdreport` runs
on the converged fit regardless of starting point, and the optimiser's
per-iteration cost is set by problem size and sparsity structure, not by
distance from the optimum — a near-exact seed cuts iteration *count* by
~40% (§4), but that saving is consumed by `sdreport`'s untouched share and
the VA sub-fit's own cost, which itself grows faster with scale than the
gain it is meant to buy. The hybrid should be reported as capped at roughly
**1.1×** at small-to-moderate model sizes and **should not be pursued
further as a speed lever** — it goes net-negative (0.84×) at N=1000, q=2 in
the existing scaling ladder, and nothing in this profile campaign suggests
that reverses at larger scale. If speed is the actual goal, lever 1 (skip
`sdreport` on demand) delivers a larger, unconditional, statistically-free
saving today, and lever 3 (attack the sparse-Cholesky cost directly) is the
only lever with headroom to beat it — but is a separate, unstarted
engineering project.

## Files

- `dev/va-speed/38-profile-rprof.R`, `39-profile-phases.R`,
  `40-profile-sizes.R` — anchor-cell profiling (methods a/b) and problem-size
  recovery.
- `dev/va-speed/41-profile-ladder.R` — parameterised scaling ladder (6 cells,
  N×q grid), raw event logs uncorrected for defect A.
- `dev/va-speed/42-iter-count-check.R` — new this pass: direct cold-vs-warm
  outer-iteration-count comparison at the matched cell (4 seeds), resolving
  defect C.
- All logs/`.rds` outputs remain local/untracked in this worktree per D-50;
  nothing here is committed or promoted.
