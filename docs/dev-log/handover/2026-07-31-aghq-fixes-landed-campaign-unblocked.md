# Handover — the three AGHQ fixes are in; the campaign is UNBLOCKED but not yet re-gated

**2026-07-31 · from Claude (Fable 5) → a FRESH Claude session · nothing running · PR #875 open**
**Supersedes `2026-07-31-aghq-campaign-designed-blocked-on-874.md`, which said the campaign was
blocked on #874. #874 is fixed. Read the re-gate condition below before launching anything.**

## Copy-paste opener

```
🎯 GOAL — gllvmTMB: establish (or refute) the AGHQ ESTIMATOR · solo platform: CLAUDE
STATE: #843, #871, #874 all FIXED and merged/in-PR (#870 merged, #875 open). The ADEMP
  campaign is designed, coded, smoke-tested and TURNKEY.
🔴 BEFORE LAUNCHING THE GRID, RE-GATE: the campaign was blocked because its converged-only
  analysis population was EMPTY. #874 raised convergence (n=400: 0% -> 58%), but 58% is not
  100% and the residual STALLS are a separate, unfixed question. Re-run the smoke
  (STAGE=smoke NSIM=40) and check the converged-only population is now usable. If it is
  still thin, say so and do NOT spend 16,000 fits on a table that will read
  OPTIMISER-LIMITED throughout.
THEN: STAGE=1 NSIM=400 CORES=100 on Totoro (REINSTALL FIRST -- its build predates the hook).
🔴 NO PUBLIC CLAIM without Shinichi.
```

## What changed since the last handover

| issue | state | measured effect |
|---|---|---|
| **#843** multi-start | fixed (PR #875) | catastrophic fits **16/40 → 1/40**; seed 2003 frob 29.700 → 2.365 |
| **#871** dead control | fixed | `aghq_multistart` reachable; `FALSE` reproduces the old answer exactly |
| **#874** convergence | fixed | n=100 **8.3% → 25%**, n=400 **0% → 58.3%**, estimates byte-identical |

`aghq$converged` / `grad_max` / `grad_rel` / `grad_tol` / `grad_tol_rel` / `n_starts` /
`start_used` are new machine-readable fields. **The campaign runner's `converged` column
already reads the right field**, so no harness change is needed.

## 🔴 The one finding that should change how you think about the campaign

Selecting the better start on the **AGHQ objective** is only as trustworthy as that
objective. Measured on the q = 2 golden fixture at **k = 3**: the alternative start reached
a *lower* objective (1.884065 vs 1.909543) at a point where the k = 3 quadrature is wrong by
**0.107** against an independent nested-`integrate()` oracle, while the warm start sat at
2.9e-09 from it. The optimiser had exploited quadrature error — the same shape as a runaway
exploiting Laplace's error.

Fixed by ranking on **(converged, objective)**. But the general point stands and bears on the
campaign: **at coarse `k`, AGHQ's own objective is not a safe criterion for anything.** The
campaign uses k = 9, where the two starts agree to the last digit, so it is fine — but any
arm or sensitivity analysis that lowers `k` inherits this.

It also means the campaign's evidence base could never have found this: it only shows up
against ground truth from *outside* the machinery. Keep the golden fixtures in mind as the
check on any future estimator claim.

## Do not redo

- #843's truth start (120 fits, committed) · the integrator verification (#842)
- `dev/aghq-r-reference.R` for any comparative number (`decisions.md:1706-1709`)
- campaign 12 · the 73%/47% headline without the single-start caveat
- **the three engine fixes** — they are done; #871 has two *documentation* follow-ups left
  (relabelling `19-warmstart-vs-flatness.R`, promoting `sweep-control-fields.R` to `tests/`)
  and #874 has one (adding `aghq_grad_tol` to the **#857** inventory)

## Carried over

- **PR #875 is open**, not self-merged: it changes the likelihood path, which CLAUDE.md
  routes to the maintainer even with a go-ahead on the arc. Two items in it want a second
  pair of eyes, both flagged in the PR body — the corrected gaussian-exactness test, and the
  `(converged, objective)` ranking.
- **The campaign has still never run.** Its blocker is cleared; its re-gate is not done.
- **Residual stalls are unexplained.** n = 400 convergence is 58%, not ~100%. The new
  gradient reporting shows stalls sit at ~50× tolerance, so they are genuinely not
  near-misses — a separate continuation-schedule question, worth its own issue if the
  campaign needs those cells.
- **n = 1600 convergence is not re-measured** post-#874. Expected to improve on the same
  mechanism; expected is not measured.

## Three process traps that cost time today — all mine, all cheap to avoid

1. **`git stash pop` restores changes UNSTAGED.** I committed without re-adding after a
   rebase, pushed a branch missing two of my own fixes, and CI went red while my local suite
   was green — because the local suite was testing my *working tree*. Run `git status` after
   a stash/pop, and never read a green local suite as a statement about the pushed tree.
2. **Skipped is not passing, and here the factor was 15×.** The AGHQ suite reports **105**
   assertions with skips active and **1571** with `NOT_CRAN=true`. The k = 3 regression was
   hiding in that gap. Always run new tests once with `NOT_CRAN=true` and read the skip count.
3. **Rapid pushes auto-cancel CI.** Four runs were cancelled before one completed. Batch
   commits, then push once.
