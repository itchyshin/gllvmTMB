# G3 marginal-curvature Phase 0 sweep

Date: 2026-08-14  
Platform: Codex  
Branch: `codex/isdm-g3-marginal-curvature`  
Base commit: `d2aed871` (`docs: close G3P V2 terminal smoke hold`)  
Lane: Paper 1/Paper 2 frozen-model marginal-curvature admission  

## Scope and lane boundary

This lane resumes the provenance-valid G3P V2 closeout without changing any
consumed root.  It owns only the new isolated worktree at
`/private/tmp/gllvmtmb-isdm-g3-marginal-curvature`.  It does not edit or reuse
the active `codex/lane-b-mspl-interval-feasibility`,
`codex/isdm-g3-provenance-amendment`, `codex/mainline-06-issue-closeout`,
`codex/897-ordinal-detector-admission`, or
`codex/two-paper-global-analysis` lanes.

The 2026-08-14 lane preflight reported seven live lanes and 15 duplicate
numbered-design slots.  Consequently, this programme uses date-stamped private
records and allocates no new design or ledger number.

## Exact-head inventory

- The isolated branch is clean at `d2aed871`.
- The retained G3P V2 record is a provenance-valid infrastructure HOLD:
  the ordinary Paper 2 fit returned, but `obj$he()` was unavailable for a TMB
  objective with random effects, so no G3 trial ran.
- The retained fit has a finite, positive-definite `36 x 36`
  `sd_report$cov.fixed`.  Its approximate spectral condition number is 758,
  well below the frozen `1e8` curvature limit.
- The existing authoritative package helper,
  `.gllvmTMB_isdm_g3_full_vector_trials()`, requires `obj$he()` for both raw
  and candidate curvature.  The Paper 2 runner repeats that requirement before
  entering the helper.
- The repository contains diagnostic uses of `sd_report$cov.fixed` and the
  private G3 trial grid, but no ordinary random-effects G3 route that validates
  `cov.fixed` as inverse marginal curvature and checks it against a finite-
  difference Jacobian of the exact marginal gradient.

## Independent sweep

A read-only Luna scout independently checked the exact head and reported the
same gap: G3 has Newton-trial gates, receipts, runners, and focused tests, but no
ordinary iJSDM marginal-curvature utility based on `sd_report$cov.fixed`.
Searches of the Shinichi brain and the GLLVM.jl sister repository did not find a
completed implementation that can be reused without changing the estimator.

## Decision

Proceed with the approved symbolic contract and a single private G3 pathway.
The pathway must use the unchanged Laplace objective and exact marginal
gradient; validate the supplied inverse Hessian by names, symmetry, finiteness,
positive definiteness, condition number, and finite-difference direction
agreement; retain all nine predeclared trials; and fail closed with the approved
terminal taxonomy.  No smoke is authorised until the symbolic, compiled,
random-effects, runner, and claim-boundary gates pass.

## Phase 0 verdict

`GO_TO_SYMBOLIC_CONTRACT`.  This is a genuine missing numerical route, not an
algorithm failure and not permission to make a paper or package capability
claim.
