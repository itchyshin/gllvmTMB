# After-task — `profile_cross_rho_ci()` + coevolution-completion handover

**Date:** 2026-06-20 · **Author:** Claude (Ada) · **Branch:**
`claude/coevo-rho-ci-20260620` → PR (HELD) · **Slice:** coevolution completion,
piece 1 of 4 (rho profile intervals).

## Scope / outcome

Added `profile_cross_rho_ci(profile, level = 0.95)` — the **rho profile-interval**
sub-item of the COE-04 "still partial" list (Design 65 C3.3). It converts a
`profile_cross_rho()` grid into a profile-likelihood CI for the fixed cross-lineage
correlation `rho` (deviance excess below `qchisq(level, 1)`, interpolated between the
bracketing grid points), with explicit `lower_bounded`/`upper_bounded` flags and
`[-1, 1]` clamping. Fixed-`rho` profile/sensitivity evidence only — **not** in-engine
`rho` estimation; `COE-04` stays partial.

## Checks

- `test-cross-rho-ci.R` — **19/19** (synthetic quadratic profile vs analytic CI
  `rho0 ± sqrt(qchisq(level,1)/a)`; level monotonicity; unbounded-side flag; `[-1,1]`
  clamp; input validation). No heavy refits needed — the interval math is exercised
  on synthetic profiles.
- `devtools::document()` clean; exported + man page added. (5 unrelated pre-existing
  stale `man/*.Rd` from origin/main roxygen drift were left unstaged to keep the PR
  focused.)

## Coevolution-completion status (all four approved pieces addressed, 2026-06-20)

1. **rho profile intervals** — DONE: `profile_cross_rho_ci()` (this PR), 19/19.
2. **Broader non-Gaussian recovery gates** — DONE for **Poisson + NB2 + Gamma**: this PR
   adds clean two-kernel recovery gates for NB2 (`nbinom2()`, seeds 3102/3103) and Gamma
   (`Gamma(link="log")`, seeds 4201/4202), each recovering its own component `Gamma_shape`
   (own cor > 0.95, cross < 0.15) and beating one-component fits (full coevolution heavy
   suite FAIL 0 / PASS 432). Component labels are seed-sensitive, so the gates use
   calibrated clean-recovery seeds (as the original Poisson cell does).
3. **In-engine `rho` estimation** — DESIGN NOTE delivered (held PR for the rho-design
   branch): recommendation is to **keep fixed-`rho` profiling for this arc** (fragile
   identifiability, per-eval Cholesky cost, cross-package API change). Maintainer decision.
4. **GLLVM.jl #96 (Gamma mode-finder)** — found **ALREADY RESOLVED on origin/main**
   (`da135f1`): the DRM.jl convexity-gated safeguard + Gamma promotion are implemented;
   verified green (`test_gamma_laplace`, `test_gamma_fit`, `test_laplace_grad` 32/32,
   `test_grouped_dispersion_beta_gamma` 24/24, …). The issue can be closed; no PR needed.

Still queued (lower priority): Beta / nbinom1 / mixed-family recovery gates (same
seed-calibrated pattern); standalone `unique()`→`indep()` spelling cascade (Codex has
this in flight on `codex/r-bridge-grouped-dispersion`).

Register/promotion note: do NOT self-promote COE-03/COE-04 register rows — that is a
maintainer-gated scientific-coverage decision.
