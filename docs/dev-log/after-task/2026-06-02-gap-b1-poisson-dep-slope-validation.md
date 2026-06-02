# GAP-B1 / PHY-18: validate + enable poisson `phylo_dep(1 + x)` slope

## Scope

First bounded engine PR lifting the Gaussian-only reservation on the
augmented full-unstructured `phylo_dep(1 + x | species)` random slope
for **poisson only**, behind a real recovery test. Mirrors how
PHY-11..PHY-17 lifted the `phylo_indep` / `phylo_latent` non-Gaussian
cells.

Branch: `claude/dep-slope-poisson-validation`. Draft PR (high-risk
family-guard change; maintainer review required, NOT merged by the
agent).

## Changes

1. **Engine guard relax (`R/fit-multi.R`, ~line 849).** The
   `use_phylo_dep_slope` family allowlist goes from `c(0L)` (gaussian)
   to `c(0L, 2L)` (gaussian + poisson). Comment/message updated to cite
   PHY-18 poisson and the GAP-B1 identifiability sweep evidence (the
   reservation was finite-sample power, not structural
   non-identifiability). ZERO C++ changes -- the augmented dep eta is
   accumulated before the family dispatch, and the dep parameter setup
   (`theta_dep_chol`, `b_phy_aug` with `C = 2*n_traits` columns, `Z`) is
   family-agnostic and already Gaussian-validated.

2. **Recovery cell (`tests/testthat/test-matrix-slope-phylo-dep.R`).** A
   new poisson `test_that` drives the REAL public API
   (`gllvmTMB(value ~ 0 + trait + phylo_dep(1 + x | species), ...,
   family = poisson(link = "log"))`) over the SAME interleaved C = 4
   2T x 2T `Sigma_b_true` the Gaussian dep anchor uses
   (`.dep_pois_Ltrue` mirrors `.dep_Ltrue`), at n_sp = 150, n_rep = 10,
   modest log intercepts `c(1.0, 0.7)`. It asserts construction (no
   abort), `convergence == 0`, PD Hessian, that the engine ran the dep
   poisson path (`fit$use$phylo_dep_slope`, `use_phylo_dep_slope == 1`,
   `family_id_vec == 2`), and SLOPE-VARIANCE recovery read from the C x C
   `fit$report$Sigma_b_dep` matrix (diag positions 2 and 4) within the
   inherited 4x poisson band. Gated by `skip_if_not_heavy()`; honest-
   skips on non-convergence / non-PD / out-of-band recovery. CRITICAL:
   uses `Sigma_b_dep`, NOT the closed-form `sd_b` 2-vector channel (a
   known latent bug in the matrix-dep harness).

3. **CI gate (`.github/workflows/dep-slope-poisson-recovery.yaml`).** New
   workflow triggered on BOTH `pull_request` (auto-runs on the PR) and
   `workflow_dispatch`. Runs the heavy suite with
   `GLLVMTMB_HEAVY_TESTS=1` via `devtools::load_all` +
   `testthat::test_file(..., reporter = "summary")` and FAILS the step on
   any failed expectation / error (skips do not fail). Uploads the test
   log as an artifact.

## Checks

- No local R in this container -- validated exclusively via GitHub
  Actions (`dep-slope-poisson-recovery` on the PR).

## Follow-up

- Maintainer review required before merge (high-risk family guard).
- Remaining non-Gaussian dep families (nbinom2, Gamma, Beta,
  binomial, ordinal_probit) stay reserved fail-loud until their own
  recovery cells land, per the #388 discipline.
- The seven older honest-skip cells in
  `test-matrix-slope-phylo-dep.R` still read the incompatible `sd_b`
  channel; converting them to `Sigma_b_dep` is a separate cleanup.

https://claude.ai/code/session_01E83SkoXEaWMo1WRxj2Hud4
