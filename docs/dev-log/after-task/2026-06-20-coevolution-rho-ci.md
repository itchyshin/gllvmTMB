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

## Remaining coevolution-completion pieces (handover — heavy, queued)

Maintainer approved all four (2026-06-20). Done: this one. Remaining:

1. **In-engine `rho` estimation** — the biggest; estimate `rho` inside the fit rather
   than fixed-`rho` profiling. Needs a brief design note first (how `rho` enters the
   optimizer / its identifiability with the kernel scale). Engine work.
2. **Broader non-Gaussian / mixed-family recovery gates** — extend beyond the narrow
   2-cell Poisson gate (Binomial, Gamma, NB, mixed-family two-kernel recovery cells,
   mirroring `test-coevolution-two-kernel.R`). Heavy fits (`GLLVMTMB_HEAVY_TESTS`).
3. **GLLVM.jl #96 — Gamma mode-finder hardening** — borrow the DRM.jl convexity-gated
   mode-finder safeguard into `_laplace_mode!` to unblock the Gamma caveat. Self-
   contained Julia engine change; verify with the full Julia suite (~33 min).

Register/promotion note: do NOT self-promote COE-03/COE-04 register rows — that is a
maintainer-gated scientific-coverage decision.
