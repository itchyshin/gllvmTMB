# Handover note — VA/EVA lane, 2026-07-27

Short pointer note. The two documents below carry everything; this exists so the
links are in one place.

## The two documents

| What | Path |
|---|---|
| **Ultra-plan** — the 12-hour arc, slice table, speed-up programme, do-not-repeat list | [`docs/dev-log/2026-07-27-ultra-plan-va-speedup-and-comparator.md`](../2026-07-27-ultra-plan-va-speedup-and-comparator.md) |
| **Handover** — paste-and-go resume block, landing state, gotchas | [`docs/dev-log/handover/2026-07-27-claude-handover-va-speedup.md`](2026-07-27-claude-handover-va-speedup.md) |
| Morning brief — the overnight evidence in one page | [`docs/dev-log/2026-07-27-morning-brief-va-eva.md`](../2026-07-27-morning-brief-va-eva.md) |

## State in one paragraph

VA/EVA/JJ work as internal engines for Poisson, Bernoulli and multi-trial
binomial, verified against `gllvm` 2.0.13 (Poisson 4.4e-09, JJ binomial 2.7e-07
median relative difference; bound ordering correct 320/320 cells). Nothing is
exported, no `method=` argument exists, `NAMESPACE` is untouched, and Laplace
remains the only estimation route. `main` (`c3d11667`, including the merged
binary/OLRE logLik fix) is already merged into this lane. **Not pushed.**

## The reframing that matters

The reason for building VA is refuted by its own evidence: **no speed crossover
exists** (VA ~n^1.9–2.7 vs Laplace's linear n^0.98; VA does not complete beyond
n ≈ 2500), and the **tighter GH bound recovers `Sigma_B` worse** than the looser
JJ bound on 20/20 paired seeds. Both the optimiser and the starting values were
tested as explanations and cleared.

What survives is honest failure: across 640 grid cells VA **never** reported a
clean status on a degenerate fit, while **59 of 70** degenerate Laplace fits
reported `convergence = 0` with `pdHess = TRUE`, and gllvm's EVA was 68%
degenerate with **all** reporting converged.

So VA's product is a **cross-engine second opinion**, not a faster or better
estimator — Shinichi's framing, 2026-07-27: *"VA is required to be able to
compare with Laplace and also to compare with gllvm."*

## Next action

Arc 0 of the ultra-plan, 60 minutes, both changes already measured:

1. Flip the binomial default from GH to **JJ** — 5–8x faster *and* better
   `Sigma_B` recovery.
2. Swap `stats::optim(method = "BFGS")` for **`"L-BFGS-B"`** at
   `R/va-r3-proto.R:639` — 16x at n=800, identical objective. BFGS keeps a dense
   inverse-Hessian over ~25,000 variational coordinates at n=5000 (5.0 GB), which
   is very likely the n>=2500 wall.

**Gate:** re-run `devtools::test()` and confirm green **before** pushing. This
lane touches TMB templates; its suite was still running when the session closed
and its result is unknown.

## Capability surface

The estimation-methods ladder now carries VA and EVA rows, tagged
**internal research**, with a note recording that Laplace remains the only route
and that VA is not faster. Live at `/p/gllvmTMB/surface`.

The copy in the **main checkout is deliberately uncommitted** — that checkout is
on `claude/profile-coverage-remeasure-20260718`, and committing there would put a
commit on another lane's branch. The same edit is committed here.

## Open, maintainer-only

NEWS entry and the public GitHub issue for the merged binary/OLRE logLik defect
(`c3d11667`, PR #796; `v0.6.0` / `rc.1` / `rc.2` affected, not on CRAN).
