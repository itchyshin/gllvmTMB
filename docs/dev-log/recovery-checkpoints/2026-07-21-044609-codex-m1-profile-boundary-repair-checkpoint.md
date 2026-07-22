# M1 nonlinear-profile boundary repair checkpoint

Date: 2026-07-21 04:46 MDT

## Repository state at repair admission

- Builder: `/private/tmp/gllvmtmb-060-m1-builder`
- Branch: `codex/gllvmtmb-060-m1-baseline-20260720`
- Pre-repair HEAD: `c6e1dd8aff5b76b672806076369e96588f818980`
- Frozen base: `de211f762812c574646938adaca22cbf41c6175e`
- Remote branch matched the pre-repair HEAD.
- `git status --short --branch` was clean before this checkpoint and the
  bounded source/test workers were dispatched.
- Draft PR #778 was the sole open PR and reported `mergeStateStatus = CLEAN`.
- The dirty primary checkout and all parked worktrees remain quarantined and
  untouched. Codex is the sole programme writer.

## Why the qualified head cannot close M1

The exact-head local package check, pkgdown check, automatic Ubuntu package
check, manual Windows/Ubuntu/macOS package checks, and Ubuntu-heavy package
check all passed for `c6e1dd8`. Those receipts remain immutable evidence for
that head.

The fresh D-43 source/API review nevertheless found a load-bearing public
boundary defect:

1. exported `extract_cross_correlations(method = "profile")` still calls the
   withdrawn nonlinear penalty-refit prototype `profile_ci_correlation()`;
2. exported `extract_repeatability(method = "profile")` silently substitutes
   Wald despite the recorded fail-loud contract.

The reproducibility/platform review passed. The systems review found no
load-bearing ownership or Mission Control defect; dirty parked-path overlaps
remain a reconciliation warning before merge. The source/API verdict is
`P1 NOT-DONE`, so M1 is not closed.

## Authorised bounded repair

- `R/extract-correlations.R` plus its focused cross-family interval test:
  preserve the accepted compatibility token but abort public profile requests
  with `gllvmTMB_nonlinear_profile_withdrawn`; retain internal research
  prototypes.
- `R/extract-repeatability.R` plus its focused profile API test: make Wald the
  honest default and abort explicit profile requests with
  `gllvmTMB_repeatability_profile_withdrawn`.
- Reconcile roxygen, generated Rd, extractor contracts, focused tests, the M1
  after-task report, and the append-only check log.
- Do not alter TMB likelihoods, formula grammar, EVA, other direct/simple
  profile routes, or fixed-kernel `profile_cross_rho()` sensitivity helpers.

## Completed commands and outcomes

- Rechecked `gh pr list --state open`: one draft PR, #778.
- Rechecked `git log --all --oneline --since="6 hours ago"`: only the three M1
  branch commits; no competing writer was found.
- Rechecked current builder and remote branch identity at `c6e1dd8` before
  editing.
- Ran three fresh D-43 reviews under systems, reproducibility/platform, and
  source/API lenses. The source/API P1 described above withholds closure.
- Updated and locally committed the canonical Mission Control board in the
  Shinichi vault at commit `2adf8be`; the unrelated dirty drmTMB release note
  was not staged or changed.

## Commands still required

1. Review the two bounded worker patches against Design 75 and the public
   extractor contract.
2. Run `devtools::document()` and inspect generated NAMESPACE/Rd changes.
3. Run focused refusal/default tests, then the complete test suite.
4. Run source-package `R CMD check --as-cran --no-manual` and
   `pkgdown::check_pkgdown()` on a clean candidate commit.
5. Obtain independent precommit review; commit and push the bounded repair.
6. Treat every `c6e1dd8` receipt as predecessor evidence and run a fresh
   exact-head automatic Ubuntu, manual three-OS, and Ubuntu-heavy cycle.
7. Obtain three fresh NOT-DONE-default D-43 verdicts before any M1 close claim.

## Next safest action

Integrate and inspect only the assigned source/test repairs, reconcile their
public documentation, and run the local verification ladder. Do not start
Design 86, connect to Totoro/DRAC for scientific compute, mark PR #778 ready,
merge, tag, submit, or make a readiness/release claim.
