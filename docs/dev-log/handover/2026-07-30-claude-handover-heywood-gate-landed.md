# Session Handoff: the Heywood gate is built, validated, and waiting on ONE human decision

Date: 2026-07-30. Author: Claude. Target: Claude or Shinichi (same platform).
Predecessor: `docs/dev-log/handover/2026-07-29-claude-handover-vgh-heywood-gate.md`.
Lane: `claude/heywood-gate-20260730`, worktree `/private/tmp/gllvmtmb-heywood`.

## Critical context — read this first

**Nothing here is blocked on more compute.** The arc is finished; two items need a
maintainer decision and one is closed by measurement. **Do not restart the
calibration** — thirteen cells and ~12,400 fits are recorded, and re-running them
will reproduce what is already in `dev/heywood/`.

**PR: https://github.com/itchyshin/gllvmTMB/pull/838** — 17 commits,
`rcmdcheck --as-cran` **0 errors / 0 warnings / 1 note** (New submission),
58 tests green in `test-sanity-multi.R`.

## What shipped

`check_gllvmTMB()`'s binomial loading row required `extreme_prevalence` as a
**conjunct**, so quasi-complete separation — a property of the fitted linear
predictor, not the marginal rate — could never trip it.

**The gate keyed on a quantity the pathology does not move.** Across 3,944
binomial fits the worst trait's prevalence never left **[0.20, 0.807]** while
loadings ran to **24,057x** typical, essentially uncorrelated (**r = 0.036**).

| change | effect |
|---|---|
| `loading_runaway_thresh = 25` (new arg) | a runaway ratio reports alone; 0/551 FP, 96.3% detection |
| `loading_absolute_thresh = 6` (new arg, on a new `max_loading_unit` column) | catches 14 the ratio misses; the arm that survives large p |
| `psi_rel_thresh` 0.001 → **0.01** | psi-collapse coverage 73.7% → 96.2%, FP 0 on 510 healthy fits |
| denominator taken over the traits being screened | a x100-scale gaussian trait no longer masks a binomial runaway |
| advice rewritten | `suggest_lambda_constraint()` referral **deleted** (it cannot resolve separation); now names `gllvmTMBcontrol(aghq_ridge = 2)` |

## 🔴 NEEDS YOU — two decisions, no work attached

1. **Merge or hold #838.** `loading_*_thresh` are **API changes** and
   `psi_rel_thresh` is a **behaviour change** — fits that previously passed will
   now warn (correctly, on this evidence). `CLAUDE.md` puts both behind maintainer
   approval, so this was deliberately **not self-merged**.
2. **`aghq_ridge` belongs in `NEWS.md`.** It ships (`R/fit-multi.R:5310`,
   `man/gllvmTMBcontrol.Rd`), is measured at **47% → 0% runaway**, and takes the
   reproduction fit from `||Lambda||_F` **979.1 → 3.352** — and **no user can
   discover it**. `NEWS.md` contains zero occurrences. Small, high-value, its own PR.

## Decided by measurement — do NOT re-litigate

- **Only ONE new statistic was justified.** Six candidates tested:
  `max_loading_unit` **wired**; `communality > 1` **structurally unreachable**
  (psi = exp(theta) >= 0; max observed exactly 1.000 over 360 fits);
  `g_norm_var` **adds 0**; `saturated_fit` standalone **adds 0** (tested per-trait
  on logit, probit AND cloglog); a family-general scale statistic has **nothing to
  detect**.
- **The loading face is BINOMIAL-SPECIFIC**: 0/360 degenerate off binomial, even
  at fitted rank 5 against true rank 2 with no Psi outlet. This is why the row is
  binomial-only and why the absolute threshold must never be reused elsewhere.
- **The two arms cover each other's blind spots.** At large p the *relative* arm
  is fragile (worst healthy 23.95 against a threshold of 25 at p = 100) and the
  absolute arm is stable; on a structured tier the *absolute* arm is fragile
  (70,792 from SPDE basis normalisation) and the ratio is stable at 1.85.
  **Neither is safe alone.**

## Gotchas paid for in blood this session

- **A test that passes proves nothing until it fails against the defect.** The
  stratification patch first named its argument `keep`, colliding with a local
  `keep` in the merge loop at `R/diagnose.R:340`. The denominator silently
  collapsed to the *first trait's* loading for every fit — and the new test passed
  anyway (12/0.25 = 48 clears 25 by accident). Found only by checking it fails
  without the fix. Renamed `reference_traits`.
- **Design the DGP so the gated quantity can reach its threshold.** The first
  headline ("the old rule fired on 0 of 1,465") was forced by a DGP in which
  `extreme_prevalence` was unreachable — deducible from the code without
  simulating. Corrected on every reader surface.
- **Reject a candidate only on a measurement as wide as the candidate.** Twice a
  statistic was rejected on too narrow a test (`g_norm_var` scored against the
  wrong face; `saturated_fit` scored on the argmax trait only) and both had to be
  re-run.
- **Query the phenomenon, not the plan.** The prior-work sweep RAN and PASSED
  while the brain held a two-day-old note with this pathology's mechanism, remedy
  and citation — because the query used the plan's vocabulary
  ("diagnostic efficacy audit") rather than the phenomenon's ("Heywood",
  "runaway", "ridge"). Filed as
  `~/shinichi-brain/memory/Query the PHENOMENON, not the PLAN …`.

## The finding that outgrew this lane

**VGH has 0/148 degenerate fits where Laplace has 50/148 — 49 of them silent.**
Confirmed by the Totoro grid (`dev/totoro-grid/results/RESULTS.md` §4: 0/320
`gtmb_jj`, 0/600 `gllvm_va`, 70/601 `gtmb_laplace`). **The Heywood gate is a
Laplace-specific patch for a pathology VA does not have.** Correct for a
Laplace-only 0.6 — but the long-run answer is the estimator, not the detector.
Full record, with the caveats that must travel with it, in
`~/shinichi-brain/memory/VGH in gllvmTMB — the settled position …`.

Also corrected there: the Phase 3 VGH screen refutation was **over-scoped** (the
statistic tested contains no `Lambda`; the doc calls it "the worst candidate
available"), and `gllvm`'s VA is **not** faster than its LA in our own
measurements (LA 3.3x faster at n = 200, m = 50).

## Evidence map

| file | what |
|---|---|
| `docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md` | the loading face: calibration, all coverage arms, §7 the errors review caught |
| `docs/dev-log/2026-07-30-psi-face-heywood-and-rel-threshold.md` | the psi face and the threshold retune |
| `docs/dev-log/after-task/2026-07-30-heywood-gate-diagnose.md` | Arc A close-out |
| `docs/dev-log/after-task/2026-07-30-psi-face-and-mixed-family-validation.md` | Arcs B–C close-out |
| `dev/heywood/*.{R,csv}` | every sweep, script and result |

## How to resume

Nothing needs resuming. If #838 is merged, the follow-ups in priority order are:

1. **`aghq_ridge` into NEWS** (see above).
2. **Spatial coverage beyond the false-positive rate.** 0/61 FP is measured, but
   detection on *degenerate* spatial fits is not — no degenerate spatial fit was
   produced. Use multi-trial binomial (n 200–300, 10–20 trials); single-trial
   Bernoulli at n = 80 will not converge.
3. **A matched-parameterisation LA-vs-VGH accuracy run.** The existing speed
   benchmark is confounded (Laplace 60 parameters, VGH 79), so no equal-accuracy
   claim exists in either direction.

```
cd /private/tmp/gllvmtmb-heywood && git log --oneline -17
```
