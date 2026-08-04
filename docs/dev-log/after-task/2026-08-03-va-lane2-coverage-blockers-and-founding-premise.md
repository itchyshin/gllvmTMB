# After Task: VA lane 2 — both coverage blockers closed, and the arc's founding premise refuted

**Date:** 2026-08-03 · **Agent:** Claude Code (Fable 5) · **Branch:** `claude/va-lane2`
**Worktree:** `/private/tmp/gllvmtmb-va-lane2` · **Compute:** Totoro (D-50: results LOCAL)

## 1. Goal

Rehydrate from `docs/dev-log/handover/2026-08-03-claude-handover-va-lane2.md`, reconcile
against git state, and continue only the OWED Next Immediate Steps (1–6).

## 2. Implemented

- **Coverage blocker 1 closed.** The VA-R3 health gate's gradient bar was recalibrated from a
  fixed `1e-4` to `5e-3`, against a measurement rather than a guess. Step-0 VA-Wald healthy
  yield at n=150 went **0/30 → 28/30**.
- **Coverage blocker 2 closed, both halves.** `.total_variance_spec()` now aborts instead of
  silently substituting `Sigma_tt` for `V_t`; and the Step-0 design's LA formula was moved to
  `unique = TRUE` so psi actually exists in the tier the estimand reads. LA-Profile `V_j`
  now produced **30/30**, coverage **0.925** against the previous collapse to **0.096**.
- **OWED step 2 answered.** A paired VA-vs-LA ladder refutes the arc's founding premise:
  VA is slower than the shipped Laplace engine at every configuration measured, and scales
  worse (VA ~N^1.27–1.29 vs Laplace ~N^0.94–0.95).

## 3. Files Changed

| file | change |
|---|---|
| `R/va-r3-proto.R` | four bare `1e-4` literals → two named constants with distinct jobs |
| `R/profile-derived.R` | guard in `.total_variance_spec()` (committed as `2a174fb9`) |
| `tests/testthat/test-va-r3-prototype.R` | +3 tests pinning the calibration |
| `tests/testthat/test-profile-ci-total-variance-export.R` | +2 tests pinning the estimand refusal |
| `dev/va-speed/40-step0-pilot.R` | LA formula → `unique = TRUE` |
| `dev/va-speed/43-va-vs-la-ladder.R` | new — paired VA/LA harness |
| `dev/va-speed/44-…-calibration.R`, `45-…-objective-gap.R`, `47-psi-tier-probe.R` | new — the measurements |
| `dev/va-speed/46-VA-VS-LA-VERDICT.md` | new — the step-2 verdict |

Commits: `f15ad1b7`, `33805e86`, `86049310` (plus `2a174fb9`, which another session made
from my working tree — see §8).

## 3a. Decisions and Rejected Alternatives

- **Rejected the handover's own prescription for blocker 1.** It said to make the bar
  relative or N-scaled — the intuitive fix for an absolute bar on an extensive quantity.
  Measurement (`45-gradient-vs-objective-gap.R`) shows the safe window *barely moves* with
  `n_obs` and if anything tightens (0.0201 → 0.0134 over an 8× n range), so scaling with N
  would push the bar the **wrong way**. The defect was never the scaling; the bar was simply
  ~130–200× too tight at every n.
- **Rejected `1e-3` for the new bar, after trying it.** It fixed the primary cells but took
  n=50 seed 20260803 (gradients 1.99e-03..4.97e-03, all genuinely converged) from 4/4 to 0/4.
  `5e-3` admits every converged start observed and stays 2.7× below the smallest gradient
  ever seen with an objective gap ≥ 1e-6.
- **Kept the polish target at `1e-4`** as a separate named constant. It is an effort knob,
  not a verdict; relaxing it because the verdict was miscalibrated would degrade every fit.
- **Did not ship a second Laplace-cost verdict doc.** I had written one before discovering
  the concurrent session's `docs/design/laplace-cost-profile.md`, which covers the same
  ground more thoroughly (it caught a `MakeADFun` double-count I had missed). Mine was
  reshaped to carry only the non-duplicated VA-vs-LA content.

## 4. Checks Run

- VA suite: **21 files, 1335 passed, 0 failed, 0 errors, 1 skipped**.
- Profile suite: **16 files, 523 passed, 0 failed, 0 errors, 70 skipped** (heavy tier).
- `test-va-r3-prototype.R` alone: 479 passed, 0 failed.
- Calibration re-run: **4/4 healthy on all 9 cells** (n ∈ {50,150,400} × 3 seeds).
- Step-0 pilot re-run, n=150, 30 seeds: yields and coverage in §2. n=400 was still running.
- Harness cross-validation: the ladder's LA arm reproduces `41-ladder-N250_q2.rds` at
  **159 outer iterations**, exactly.

## 5. Tests of the Tests

The first negative control was **invalid and I said so rather than reporting its number.**
`44-gradient-tolerance-calibration.R` tried to force non-convergence with
`eval.max=12/iter.max=6`; the truncated fits reached the same optimum to 6+ decimals because
the polish loop and the L-BFGS-B fallback rescue them regardless. Its apparent finding — that
converged and truncated gradients overlap, so no threshold can work — was an artifact.
`45-gradient-vs-objective-gap.R` replaced the instrument: walk away from a converged `par*`
and measure `max|gradient|` against the objective gap directly. That is what produced a
separable window at every n.

Similarly, the `unique = TRUE` design fix *looked* wrong (an auto-suppression message about
the per-row level suggested psi was going to the W tier). `47-psi-tier-probe.R` checked
instead of assuming: `theta_diag_B` is present and the spec returns OK.

## 6. Consistency Audit

The new constants are the single source for both the applied and the reported
`gradient_tolerance`, with a test asserting they agree. `46-VA-VS-LA-VERDICT.md` explicitly
defers to `docs/design/laplace-cost-profile.md` for phase shares so the two do not drift.
Nothing user-facing changed: no NEWS, no roxygen, no article, no export. `default_tier`
remains `"gh"`; `R/integration-fence.R` untouched; `confint.gllvmTMB_va` / `vcov.gllvmTMB_va`
still error.

## 7. Roadmap Tick

OWED steps 1–4 complete; step 5 partially (Step-0 re-run done at n=150, Tiers 1+2 **not**
run — see §10); step 6 folded into step 2's harness.

## 7a. GitHub Issue Ledger

No issues opened or closed. Nothing here is promoted or advertised.

## 8. What Did Not Go Smoothly

**A second Claude Code session was writing this same lane concurrently.** Between 18:50 and
19:01 it landed three commits: the 21 carried-over `dev/va-speed/` paths plus its own verdict
doc (`695450d2`), a **rewrite of the handover I had rehydrated from** (`305b6b86`, correcting
the warm-start mechanism from "helped iteration 1 of 674" to "cut iterations ~40%"), and
`2a174fb9` — which swept my **uncommitted** `R/profile-derived.R` blocker-2 fix into its own
commit. The commit message describes my change accurately, so nothing was lost or corrupted,
and its LA-cost findings agree with my independent extraction from the same `.rds`.

This is D-88 bleed-through, not merely concurrency: the handover that defined my task was
edited underneath a running session, and my working tree was committed by another writer.
Per D-87 the overlap is the maintainer's call, not mine to resolve, so I did not revert,
amend, or rebase anything. It is surfaced here and in the handover.

Secondary: the first VA ladder cell failed instantly because `family = "binomial"` requires
link `"logit"` (probit needs `family = "binomial_probit"`). The smoke-test-one-cell-first
habit caught it in 0.18 s instead of across 9 launches.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Fisher.** Two independent harnesses can agree and still both be wrong about the
  *mechanism*. The gradient bar's defect was diagnosed as a scaling problem by everyone who
  looked at it, including the handover; only measuring the bar against the criterion it is
  supposed to approximate showed the scaling was a red herring.
- **Curie.** A control that does not control is worse than no control, because it produces a
  publishable-looking negative. Check that a negative control actually failed before
  believing what it says.
- **Rose.** Two sessions independently wrote a Laplace-cost verdict document within the hour.
  The duplication was caught only because a `git status` came back unexpectedly clean.

## 10. Known Limitations And Next Actions

- **N=2500 ladder cells and the n=400 Step-0 cell were still running** at write time; results
  land in `43-vala-*.rds` and `40-step0-refix-n400.log`. The N=1000 → N=2500 step is what
  confirms the exponent holds beyond one doubling.
- **Tiers 1+2 of the coverage campaign were deliberately NOT run.** Both blockers are closed,
  so the campaign is technically unblocked — but §2's third finding undercuts its premise. If
  VA is slower than Laplace at every N, "do VA's intervals cover" is not the next question.
  **Recommend the maintainer decide whether the campaign runs at all before its compute is
  spent.**
- **Ledger claim `f3df8193` ("VA is 5.8× faster than our own Laplace") is not retracted** —
  it was measured on a cell I have not reproduced. It should be re-measured with the paired
  harness, since pairing is what made the new numbers trustworthy.
- **`claude/va-lane2` remains unpushed** — the maintainer's call, unchanged from the handover.
