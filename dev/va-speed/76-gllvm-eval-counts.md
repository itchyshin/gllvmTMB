# gllvm 2.0.13 — VA optimiser evaluation counts, recovered by namespace trace

**Date:** 2026-08-05 · **Machine:** local Mac (NOT Totoro — a timing campaign was running there;
evaluation counts are deterministic, so the machine is irrelevant to the counts)
**Cell:** N=120, T=10, q=1, binomial-probit, `Ntrials`=6, ψ=0.6 planted, seeds 1:8
**gllvm version loaded:** 2.0.13

## Why this exists

`gllvm` **discards its optimiser's return value.** Inside `gllvm:::gllvm.TMB` the raw result is held
in locals `optr`/`optrFinal`, and only `optrFinal$par` and `optrFinal$convergence` are kept;
`optrFinal$counts` is thrown away. A fitted `gllvm` object therefore carries no `iter`, `counts`, or
`optim.out` field — which is why a previous probe of `fit$optim.out$counts[["function"]]` returned
`NA`. It was not that gllvm stored `NA`; it never stored anything under that name.

Recovered here with `trace(what = stats::optim, where = asNamespace("gllvm"), exit = ...)`. The
`where =` argument is essential: a plain `trace(stats::optim)` does not intercept a sealed namespace
import.

**Unit warning.** These are **function and gradient EVALUATION counts**, not iterations.
`stats::optim` has no iteration count at all. Our own engine's `nlminb` reports true `$iterations`,
which is a *different unit* — evaluations are the only measure commensurable across the two engines.

## Stage disambiguation

One `gllvm()` call runs three stages: (1) an `nlminb` starting-value pre-fit at `num.lv=0`
(`starting.val="res"` default); (2) the **main `optim(method="BFGS")` fit** — the one reported below;
(3) an `optimHess()` pass for SEs (`sd.errors=TRUE` default), which makes further objective calls but
is not an optimisation. Separated by call order.

## Per-seed results (main optim, stage 2)

| Seed | Wall (s) | optim fn | optim gr | conv | stage-1 nlminb iter | stage-1 fn / gr evals |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.146 | **154** | 50 | 0 | 3 | 8 / 3 |
| 2 | 0.136 | 204 | 72 | 0 | 13 | 20 / 13 |
| 3 | **0.097** | 162 | 53 | 0 | 8 | 14 / 8 |
| 4 | 0.110 | **214** | 80 | 0 | 8 | 15 / 8 |
| 5 | 0.102 | 171 | 56 | 0 | 6 | 11 / 6 |
| 6 | 0.105 | 173 | 61 | 0 | 6 | 12 / 6 |
| 7 | 0.103 | 202 | 66 | 0 | 9 | 16 / 9 |
| 8 | 0.111 | 206 | 79 | 0 | 6 | 11 / 6 |

Spread: wall **1.51×** (0.097–0.146) · optim fn evals **1.39×** (154–214). All eight converged (0).

## 🔴 The finding: seed 1 is NOT hard for gllvm

Seed 1 has the **lowest** function-evaluation count of all eight (154 against a ~188 median) and yet
the **highest** wall-clock (0.146 s against a ~0.105 s median). Fewest evaluations, most seconds.

That combination is the signature of **first-call overhead**, not data difficulty — seed 1 runs
first and pays one-time DLL/TMB/gllvm setup costs. And **the harness that produced the lane's
headline finding, `dev/va-speed/71-split25.R`, has no untimed warm-up**, while its own sibling
`57-gllvm-scaling.R:74-78` explicitly does ("pays TMB compile + gllvm's first-call costs for BOTH
arms").

**Consequence.** `72-THE-GAP-IS-VARIANCE.md` argues that "seed 1 is harder for both engines — gllvm
also slows, 0.294 s against its 0.093 s median (3.2×)" and reads our 34× degradation on the same data
as an ill-conditioning signature *relative to a shared difficulty*. On this measurement gllvm shows
**no such degradation on seed 1** by the load-independent metric, and its wall-clock excess is fully
consistent with warm-up. The "both engines find seed 1 harder" premise should be treated as **not
established** until re-measured with a warm-up in place.

> **🔴 CORRECTION (2026-08-05, adversarial review `77`).** This paragraph originally continued:
> *"This does not refute our own 25.5 s blow-up — that is far too large to be warm-up."*
> **That sentence was false and is struck.** It was a guess made without any compile timing in hand.
> The review measured the actual first-call/compile cost at **24.77 s** — which is precisely the size
> of the 25.5 s "catastrophic seed". The blow-up *is* the warm-up. As originally written this
> sentence preserved the variance thesis on a false premise.

What remains true here is narrower: gllvm shows no seed-1 degradation by the load-independent metric,
which removes the *comparative* framing ("seed 1 is intrinsically harder data") that the conditioning
inference rested on. Note also that this gllvm-side evidence is **thin on its own** — a 41 ms
difference from a single unreplicated run — and should corroborate, not carry, the argument. The
measured compile timing is the load-bearing evidence.

## Verification

The generating script's own summary asserts "Trace fired cleanly: YES" **unconditionally**, printed
regardless of outcome — an assertion that cannot fail, and therefore not evidence. It is not relied
on here. The trace is instead judged fired by the data itself: counts are non-zero, vary sensibly
across seeds (154–214), carry both `function` and `gradient` components, and the stage-1 `nlminb`
values are small and distinct from the stage-2 `optim` values exactly as the three-stage structure
predicts. Verified independently by Ada, 2026-08-05.

Source script: `dev/va-speed/trace-gllvm-va.R`. An earlier auto-generated version of this file
duplicated every row (an artefact of `rbind`-ing named `counts` vectors) and carried a malformed
table header; both are corrected above, and the stage-1 `evaluations` vector is now reported as its
two components rather than as two near-identical rows.
