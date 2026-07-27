# After Task: `start_method = "res"` silently reaches a worse optimum — diagnosis

Date: 2026-07-27
Lane: Claude, worktree `awesome-fermat-0e06a9`, branch `claude/loving-liskov-85d5d5`
Source: correctness bug reported out of the 2026-07-27 Laplace profiling campaign
(`docs/dev-log/2026-07-27-la-speedup-arc-plan.md`, worktree
`/private/tmp/gllvmtmb-va-wiring-20260726`, lens `dev/la-profile-optimizer.md`,
verifier `dev/la-verify-optimizer.md`).

## 1. Goal

Reproduce, scope, and diagnose the reported defect: with
`control$start_method = list(method = "res")`, a well-identified `d = 1` cell
converges to a local optimum **1.84 nats worse** than the default start while
reporting `convergence == 0` and `pdHess == TRUE`. Decide the fix and land a
regression test that fails on current behaviour.

**This is a diagnosis slice. No fitting behaviour was changed.** The two candidate
fixes both need maintainer sign-off (§3a).

## 2. Implemented

- Reproduced the 1.84-nat gap exactly on the reported seed.
- Widened to 36 fits across latent rank, trait count, and 21 random generating
  configurations.
- Identified the mechanism (Heywood boundary + log-scale parameterisation) and
  the **root cause of the silence**, which is not in the start method at all.
- Landed a failing regression test.

## 3. Files Changed

- `tests/testthat/test-start-method-residual.R` — added the outcome-contract
  regression test plus a file-header note that the test is an expected failure.
  No other repository file was modified.

Scratch evidence (not committed): `repro-res-start.R`, `repro-breadth.R`,
`heywood.R`, `flags.R` in the session scratchpad.

## 4. Checks Run

All runs used the campaign worktree's compiled build. `git diff` over `R/` and
`src/` between the two worktrees is **empty**, so the code exercised is
byte-identical to the code in this branch.

**Reproduction — the reported cell (`Lambda_B` fixed, seed 101, p=3, d=1):**

| | −logLik | pdHess | iterations |
|---|---|---|---|
| default | 5699.0762 | TRUE | 74 |
| `res` | 5700.9189 | TRUE | 62 |
| **delta** | **+1.8426 nats** | — | — |

Confirmed to 4 decimal places. Not a flake.

**Breadth — is it specific to `d = 1`?**

| cell | seeds | `res` materially worse | notes |
|---|---|---|---|
| p=3, d=1 (exactly identified) | 21 | **4** (+0.21, +3.70, +7.28, **+14.65** nats) | all 4 with `pdHess = TRUE` on both sides; 1 seed better by 0.07 |
| p=3, d=2 (over-parameterised) | 5 | 0 | objectives agree to ~1e-7 |
| p=3, d=3 (over-parameterised) | 5 | 0 | objectives agree to ~1e-7 |
| p=5, d=1 (over-identified) | 10 | 0 | — |

Two corrections to the original report follow from this. **1.84 nats was not the
worst case** — the sweep found **14.65 nats**. And the event rate at the
exactly-identified corner is **4/21 (19 %)** over independently drawn generating
configurations, not a single cherry-picked cell.

**Does the documented remedy work? No.** `n_init = 5` with the default
`init_jitter = 0.3` returns the identical worse optimum on all five restarts
(5700.9189, 5/5). The roxygen advice to combine `res` with `n_init > 1` "to check
whether the optimiser repeatedly reaches the same likelihood basin" **does not
rescue this cell** — all starts agree on the wrong answer.

**Regression test verified failing** (`testthat::test_file`, `NOT_CRAN=true`,
`GLLVMTMB_HEAVY_TESTS=1`): 22 assertions pass, the new one fails with
`5700.9 > 5699.1, Difference: 1.8`.

## 5. Tests of the Tests

The new test was run against current `main` behaviour and **failed for the stated
reason**, with the expected magnitude — not by erroring, skipping, or failing on
a setup assertion. The two guard assertions (`convergence == 0` on both fits)
pass, so the comparison it makes is meaningful.

Confirmed the test skips cleanly under routine PR CI (`skip_if_not_heavy()`
fires when `GLLVMTMB_HEAVY_TESTS` is unset).

## 6. Consistency Audit

- **`res` is never a default.** `gllvmTMBcontrol()` ships
  `start_method = list(method = NULL, jitter.sd = 0)`. No code path selects
  `"res"` implicitly. Blast radius is opt-in only.
- **It is documented as a remedy**, in two reader-facing places, both without a
  caveat: `R/gllvmTMB.R:1173-1178` (roxygen, "For factor-analytic models, try…")
  and `vignettes/articles/convergence-start-values.Rmd:215` (the strategy table).
  The article does fence the whole table as experimental.
- **No test or vignette depends on the value it returns**; the existing tests in
  `test-start-method-residual.R` pin only the *shape* of the seeded starts
  (finite, lower-triangular, non-default) and `convergence == 0`. The file header
  already says so: "These tests pin the initialization contract only." That is
  precisely why this behaviour passed the suite.
- **`docs/design/35-validation-debt-register.md` marks MIS-18 `covered`.** The
  coverage is shape-only and does not test the achieved optimum. The row is
  arguably overstated; flagged, not edited.
- **`docs/design/48-m3-4-boundary-regimes.md` Q-Boole-2** asks whether `res`
  should become the default when a `latent()` term is present, currently "Lean:
  no for v0.2.0 … pending evidence." This slice supplies the evidence. The answer
  is **no**, on correctness grounds.

## 6a. Root cause of the silence — the important finding

The reported symptom is "no warning of any kind." That silence is **not** caused
by the start method, and fixing `res` would not fix it.

Both fits sit on a **Heywood boundary** — one per-trait unique variance collapses
to zero — and they collapse a *different* trait:

| | ψ₁ | ψ₂ | ψ₃ | −logLik |
|---|---|---|---|---|
| default | 1.009 | **0.0000** | 1.275 | 5699.076 |
| `res` | 1.031 | 0.821 | **0.0000** | 5700.919 |

Two independent reasons the package cannot see this:

1. **`pdHess` is structurally blind to it.** ψ is estimated on the log scale, so
   ψ → 0 is an *interior* point of the transformed parameter space. The Hessian
   is positive definite at a fully collapsed variance component. `pdHess = TRUE`
   is not a false positive here — it is answering a different question than the
   user thinks it is.

2. **The dedicated check computes the right number and passes it.**
   `check_gllvmTMB()` reports
   `near_zero_psi_unit … PASS … value 0.0006826`, and `boundary_flags` returns
   `character(0)` → "no simple boundary flags detected". Both use a threshold of
   **`1e-4` on the standard-deviation scale** (`psi_thresh`, `sd_thresh` in
   `R/diagnose.R:561`, `:103`). The collapsed component has sd `6.83e-4` — above
   the threshold — while its **variance is `4.7e-7`**, six orders of magnitude
   below its two siblings (1.015, 0.906).

   The threshold is effectively off by a square: `1e-4` on the sd scale demands a
   variance below `1e-8` before anything is flagged. The comment at
   `R/diagnose.R:135` states the intended contract — "the isSingular-style signal
   for a weakly-identified random-slope fit" — and the absolute threshold does not
   deliver it.

This is the same failure mode as the campaign's separate observation that Laplace
reported `convergence == 0` and `pdHess == TRUE` on 59 of 70 genuinely degenerate
fits. **A relative test would fire here immediately**: min/max sd ratio is
`6.7e-4`.

## 7. Roadmap Tick

Answers the open design question **Q-Boole-2** (`docs/design/48-m3-4-boundary-regimes.md:374`)
with evidence: `start_method = "res"` must **not** become a default.

## 8. What Did Not Go Smoothly

I initially read the restart loop (`R/fit-multi.R:4821-4828`) and concluded that
because `init_jitter` perturbs the whole parameter vector independently of the
start method, `n_init > 1` was a working guard. **The experiment refuted that** —
5/5 restarts return the identical worse optimum. Reading the code was not a
substitute for running it.

## 9. Team Learning

The existing tests asserted `convergence == 0` on a fit whose defect is that
`convergence == 0` is clean. A contract test that only checks the shape of an
input cannot detect a defect in the output. Where a feature's purpose is to
improve an *outcome*, at least one test must assert something about that outcome.

## 10. Known Limitations And Next Actions

**Scope limits inherited from the campaign and not lifted here:** Gaussian only,
`n_sites = 200`, one OS, one BLAS, `nlminb` only. All fits used the campaign
worktree's build. Non-Gaussian families — the case the roxygen actually
recommends `res` for — are **untested**, so the rate above does not transfer to
them.

**Fix A — LANDED (maintainer approved 2026-07-27).** The near-zero variance
detection is now **relative as well as absolute**: `.gllvmTMB_relative_collapse()`
flags a component whose magnitude is below `rel_thresh` times the largest in its
block. Applied in `.gllvmTMB_boundary_flags()` (`sd_rel_thresh = 1e-3`) and in
the `near_zero_psi_*` rows of `check_gllvmTMB()` (`psi_rel_thresh = 1e-3`, a new
documented argument; the check message now reports the offending ratio).

Verified: both fits in §6a now report `near_zero_sd_B` and
`near_zero_psi_unit = WARN` (ratios 5.3e-4 and 6.7e-4) where both previously
passed. Detection is strictly additive — anything flagged before is still
flagged. `test-slope-boundary-flag.R` (12 pass), `test-sanity-multi.R` (39 pass),
`test-matrix-truncated.R` (heavy, 28 run) all green; 0 failures.

**Fix B — REDIRECTED by the maintainer, not yet implemented.** The original
sketch (run the default start as an extra restart, keep the best) is a guard, not
a repair. The maintainer's diagnosis is better and supersedes it:

> `res` could be useful — if we fit equivalent of GLMM models not GLM etc — do
> not make it the same as glmmTMB.

This is confirmed by the code. `resid_init <- fit_lm$residuals`
(`R/fit-multi.R:2701`) comes from an `lm.fit` of the response on the **fixed
effects only**. Those residuals therefore still contain the site random effect
*and* the within-site noise, so the cell means the SVD decomposes have variance

  Sigma_B[t,t] + sigma_eps^2 / count

With `sigma_eps ~ 0.70` and `count ~ 8` that is ~0.061 of pure noise on every
diagonal element, against a true `psi_B` of 0.3 — roughly 20 % inflation, worse
in sparsely observed cells. Both the loadings and the `psi` start come out too
large. **Mechanism hypothesis**: the inflated start is what steers into the basin
where one `psi` is crushed to zero to compensate. Consistent with the evidence;
the causal link is not experimentally isolated.

The repair is to build the start from a fit that has **already absorbed the
random effects** — either residuals from the independent diagonal model that
`start_method = "indep"` already fits, or, more directly, an SVD of the
**conditional modes of the site random effects** (`s_B`, a trait x site matrix),
which are shrunk estimates of exactly what Lambda describes and carry no noise
floor by construction.

Note the current `indep` path seeds the GLMM pieces but leaves the reduced-rank
block at its historical default (`theta_rr_B == c(0.5, 0)`, asserted in
`test-start-method-residual.R`). So an SVD-of-BLUPs start would also close that
gap. Open design choice: upgrade `indep` in place, or add a separate method.

The regression test asserts Fix B's contract and will fail until B lands.
Under routine PR CI it skips; under the nightly `GLLVMTMB_HEAVY_TESTS=1` run it
will show red. That is deliberate — an open defect should be visible — but if a
red nightly is unacceptable, moving it behind its own env gate is a one-line
change.

Documentation is **not** yet corrected: the roxygen and the article still
recommend `res` with no caveat, and still recommend pairing it with `n_init > 1`,
which this slice shows does not work. Deliberately left for the same decision, so
the caveat can be written once against whichever fix lands.
