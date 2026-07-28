# Claude -> next session handover, 2026-07-27

**Arc: the `start_method = "res"` correctness bug. CLOSED.**
One diagnostic fix landed, the method retired, one proposed repair measured and
rejected. Open as **PR #799** (`claude/res-start-diagnostic`, off `origin/main`).

## START HERE

1. This file.
2. `docs/dev-log/after-task/2026-07-27-start-method-res-worse-optimum.md` — the
   full record, including the two refuted hypotheses and the complete ledger.
3. PR #799. **Do not merge without maintainer sign-off**: the soft-deprecation
   is an API change, which `CLAUDE.md` puts in the discussion-checkpoint set.

## What the arc was

Handed over from the 2026-07-27 Laplace profiling campaign: with
`start_method = "res"`, a well-identified `d = 1` cell converged to an optimum
**1.84 nats worse** than the default start and reported `convergence == 0` and
`pdHess = TRUE`. Reproduced exactly, then widened to 89 fit-pairs.

## What landed (9 commits on PR #799)

**1. The diagnostic fix — the durable win.** A collapsed variance component
could pass every check the package had. `check_gllvmTMB()` printed
`near_zero_psi_unit … PASS … 0.0006826` for a component whose *variance* was
`4.7e-7` against siblings near 1.0. Two independent blind spots: the threshold
is `1e-4` on the **standard-deviation** scale, so it demands a variance below
`1e-8`; and `pdHess` cannot see it at all, because `psi` is estimated on the log
scale, making a collapsed component an interior point where the Hessian stays
positive definite. Detection is now **relative to siblings**
(`.gllvmTMB_relative_collapse()`, `psi_rel_thresh` / `sd_rel_thresh` = `1e-3`),
strictly additive.

**2. `start_method = "res"` soft-deprecated.** Retired on measurement: over 89
fit-pairs (Gaussian / Poisson / nbinom2, `d = 1..3`, 3 and 5 traits) it was
**never materially better** than the default start — best margins 0.068, 0.29,
0.66 nats — was materially worse 8 times (up to 14.65), and was exactly neutral
at `d >= 2` (34/34 to ~1e-7). Still fits; warns once per session. Removal after
0.6. Resolves design question **Q-Boole-2**.

**3. Docs corrected.** The claim that pairing `res` with `n_init > 1` detects
the problem was **false** — measured, all five restarts returned the same worse
optimum — and has been removed. It was the most harmful sentence on the page,
because it asserted a guard that does not exist.

## The most useful thing in this handover: what NOT to try

**Do not re-propose the GLMM/BLUP start.** It was fully built, verified firing,
and **reverted as a 4/4 -> 0/4 regression** (`10b742f2`). It is the most
re-proposable idea in the arc because it sounds obviously right: seed the
loadings from an SVD of the independent model's random-effect conditional modes,
which are noise-free, instead of from fixed-effect residual cell means that carry
`sigma_eps^2 / count`.

The noise floor is **not** the mechanism. Any SVD-based start commits to the
leading PC of the between-group covariance, and at exact identification
(3 traits, `d = 1`) the best-likelihood factor is not the leading PC. The crude
constant start `theta_rr_B = c(0.5, 0)` commits to no direction, which is
exactly why it went 8/8 where both data-driven starts went 4/8.

Generalisation worth keeping: **an "informed" start is not automatically a better
start.** Three hypotheses died in this arc — the `n_init` guard, the noise floor,
the copied `s_B` modes — and each was a plausible statistical story that would
have survived review. Each took ~20 minutes to refute by measurement.

## Checks

Local full fast suite: **7683 pass, 0 fail, 0 error** across 322 files / 2034
tests (2 warnings pre-existing, `gllvm` comparator). Fits ran against a build
whose `R/` and `src/` were byte-identical to this branch; both borrowed
worktrees were restored clean. **Not run:** `devtools::check()`, `pkgdown`.
PR #799 CI was still running at handover — **verify it before merging**.

Scope limits: `n = 200`, one OS, one BLAS, `nlminb` only. The non-Gaussian
sweeps deliberately target the same Heywood-prone corner, so they test whether
`res` redeems itself *there*; they are not a broad survey of non-Gaussian
GLLVMs.

## CARRIED-OVER

**Nothing from this arc is unfinished.** Two items are *next work*, not debt:

1. **A claim worth testing.** If the relative-collapse fix is why the campaign
   saw `convergence == 0` and `pdHess = TRUE` on **59 of 70** genuinely
   degenerate fits, re-running that grid should flip a large share to flagged.
   That is measurable. **If it does not, the explanation in the after-task report
   §6a is wrong and should be corrected**, not quietly dropped.
2. **The `res` removal slice**, after 0.6. Delete the method, its branch in
   `R/fit-multi.R`, `.gllvmTMB_residual_factor_start()`, the deprecation warning,
   and the note at the foot of `tests/testthat/test-start-method-residual.R`.

## Not ours: PR #798 is red

`claude/va-wiring-20260726` fails CI with 3 failures, all in
`test-va-r3-prototype.R` ("R3 blocked information reproduces the dense Schur
complement exactly"). **Deliberately not touched** — different subject, zero file
overlap with this arc, and `R/va-r3-proto.R` has ~59 lines of uncommitted
work-in-progress in that lane's worktree (an L-BFGS-B optimiser route plus
`n_starts`). Editing it would be D-88 bleed-through.

Diagnosis handed over free, since it narrows the search:

- **One root failure, not three.** Line 332 is
  `expect_identical(dense$status, "ok")`. Lines 338/339 compare `blocked$se_*`
  against `dense$se_*` and fail *because* the dense route produced no SEs. Fix
  332 and all three go.
- **The blocked route is healthy.** Lines 333/334/335 — `blocked$status == "ok"`,
  `blocked$pd_hessian` — all passed. The structural block-diagonality claim the
  test exists to verify is holding. It is the dense *comparator* that broke.
- **It is platform-specific.** The file carries no skip gate and the same commit
  passes a full local macOS run; it fails on Linux CI. That points at
  BLAS/LAPACK-dependent positive-definiteness of the dense Hessian, not a logic
  error. **Consequence for whoever fixes it: "it passes locally" is not evidence
  of a fix.**

PR #798 carries the ten VA commits `51d1fa81..197f1bce` (verified). They are not
in `main` — PR #797 merged an earlier state of that branch — but they are not
stranded. #798 and #799 are independent and can merge in either order.

## Housekeeping

A `devtools::test()` process (PID 95515) has been running **3 days 12 hours** on
this machine. Almost certainly hung. Left alone because this session did not
start it.
