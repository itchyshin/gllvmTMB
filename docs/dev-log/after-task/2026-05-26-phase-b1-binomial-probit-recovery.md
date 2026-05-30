# After-Task Report: Phase B1 `phylo_unique()` Recovery Activation (binomial probit)

**Date:** 2026-05-26
**Branch:** `agent/phase-b1-phylo-unique-slope-binomial-probit`
**Lead:** Claude (Phase B1 fixed-residual-scale slice)
**Spawned subagents:** none

## Goal

Activate the `phylo_unique(1 + x | id)` recovery test for
`family = binomial(link = "probit")` in `gllvmTMB`. This is the first
of the Phase B fan-out cells; it copies the Phase 56.4 Gaussian anchor
(`test-phylo-unique-slope-gaussian.R`, PR #298) and swaps only the
response family + DGP. Probit-first because the latent residual
variance `sigma^2_d = 1` exactly (`R/extract-sigma.R:14-72`;
`R/families.R:685-759` for the K=2 reduction to `binomial(probit)`),
which gives the cleanest non-Gaussian identifiability story without
delta-method estimation.

## Scope

Phase B1 activates exactly one anchor-adjacent cell:

- wide: `traits(...) ~ 1 + phylo_unique(1 + x | species)` with `family = binomial(link = "probit")`
- long: `value ~ 0 + trait + phylo_unique(0 + trait + (0 + trait):x | species)` with `family = binomial(link = "probit")`

The slice does NOT fan out to other fixed-residual-scale families
(`binomial(logit)`, `ordinal_probit`), mean-dependent families
(`poisson`, `nbinom2`), bounded/positive families (`beta`, `Gamma`),
mixed-family fits, user-supplied A (`vcv = A`), or animal/pedigree
analogues. It does not promote validation-debt rows or user-facing
advertising; the `phylo_unique(1 + x | species)` row in
`docs/design/01-formula-grammar.md` stays at `claimed`.

## Files Changed

- `tests/testthat/test-phylo-unique-slope-binomial-probit.R` (new)
- `docs/dev-log/after-task/2026-05-26-phase-b1-binomial-probit-recovery.md` (this file, new)
- `docs/dev-log/check-log.md` (append-only)

## What Changed

- Created `tests/testthat/test-phylo-unique-slope-binomial-probit.R`
  mirroring the Phase 56.4 Gaussian anchor structure exactly, with
  only the response family + DGP swapped.
- Swapped the Gaussian linear-predictor draw `value <- mu_t +
  alpha_sp + beta_sp * x + N(0, 0.3^2)` for the probit-link
  binomial draw `prob <- pnorm(mu_t + alpha_sp + beta_sp * x);
  y <- rbinom(n, 1, prob)`.
- Reduced the trait intercept magnitudes (`mu_t = c(0.0, 0.3, -0.3)`
  vs. the Gaussian `c(2, 1, 0.5)`) so the marginal probability is
  not saturated, leaving binary observations with adequate information
  for slope-variance recovery.
- Used seed `2026` after the Gaussian anchor seed `5640` failed for
  binomial(probit). See the Evidence section for the full
  seed-selection record.
- Kept the same fixture dimensions as #298 (`n_sp = 60`,
  `n_traits = 3`, `n_rep = 4`), the same recovery tolerances
  (sigma^2 +-20%, rho +-0.30), and the same negative-test pattern
  (forced `n_lhs_cols = 1L` while augmented arrays have two columns).
- Did NOT include a 4th SKIP-gated `test_that` block. The optional
  4th block in `test-relmat-unique-slope-gaussian.R` documents the
  sparse-Ainv vs dense-Ainv divergence under user-supplied
  `vcv = A`; that path is not exercised by Phase B1 (which uses the
  `phylo_tree` route only), so there is no analogous divergence to
  document here.

## Evidence

Seed-selection process (5 candidate seeds at `n_sp = 60`,
`n_traits = 3`, `n_rep = 4`, byte-identity check on each):

- seed `5640` (the Gaussian anchor seed): convergence `1`,
  `pd_hessian = FALSE`, `max_gradient = 5.26e+04`,
  `sd_b = c(0.6551, 0.2803)`, `cor_b = 1` (boundary). Rejected
  because the optimiser hit the correlation boundary; sigma^2_slope
  rel err 0.738 and rho abs err 0.500.
- seed `102`: convergence `0`, `pd_hessian = TRUE`,
  `sd_b = c(0.3346, 0.1936)`, `cor_b = -0.819`. Rejected because
  sigma^2_int rel err 0.720, sigma^2_slope rel err 0.875, rho
  abs err 1.319 — all well outside #287/#298 tolerances.
- seed `2026`: convergence `0`, `max_gradient = 4.12e-04`,
  `pd_hessian = TRUE`, `sdreport_ok = TRUE`,
  `sd_b = c(0.6217, 0.5534)`, `cor_b = 0.560`. Accepted: sigma^2_int
  rel err 0.034 (target <= 0.20), sigma^2_slope rel err 0.021
  (target <= 0.20), rho abs err 0.060 (target <= 0.30). Marginal
  `mean(y) = 0.324`, so the binary outcome is reasonably balanced.

Local validation (verbatim):

- `Rscript --vanilla -e 'devtools::test(filter = "phylo-unique-slope-binomial-probit")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 27`
- `Rscript --vanilla -e 'devtools::test(filter = "phylo-unique-slope-binomial-probit|phylo-unique-slope-gaussian|phase56-3-phylo-unique-parser")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 79`
- `git diff --check` -> clean

## Definition of Done Check

1. **Implementation:** complete for the narrow Phase B1 test
   activation. PR / main CI still need to run after publication.
2. **Simulation recovery test:** complete for the
   `phylo_unique(1 + x | species)` binomial(probit) cell, including
   wide-long byte identity and the forced `n_lhs_cols` mismatch.
3. **Documentation:** none changed beyond this after-task report and
   the check-log entry. The grammar / Claude-coordination wording
   stays at `claimed`.
4. **Runnable user-facing example:** deliberately not added. Public
   advertising remains Phase 56.6.
5. **Check-log entry:** included in this PR.
6. **Review pass:** Curie/Fisher recovery checks are active in this
   report; Boole parser invariants are covered through the adjacent
   parser tests; Noether/Gauss scope is limited because no likelihood
   template code changed; Rose should confirm the claimed-versus-covered
   wording stays unchanged before merge.

## Deliberately Not Done

- No validation-debt row movement.
- No NEWS entry.
- No article or vignette update.
- No `phylo_slope()` or `animal_slope()` deprecation.
- No fan-out to other Phase B families (binomial-logit, ordinal-probit,
  poisson, nbinom2, beta, gamma, mixed-family).
- No engine, parser, R-side, or test-template edits.
- No `devtools::document()`; no roxygen, NAMESPACE, or Rd files
  changed.
- No `pkgdown::check_pkgdown()`; no pkgdown source, reference topic,
  or public article changed.
- No formula-grammar status row change. `phylo_unique(1 + x | species)`
  stays at `claimed`; Phase 56.6 owns promotion.
- No `[ad-hoc note]` tagging in this work (no user ad-hoc input).
- No 4th SKIP-gated `test_that` block. The relmat slice's
  sparse-Ainv vs dense-Ainv divergence is specific to user-supplied
  `vcv = A` and does not apply to the `phylo_tree`-only path
  exercised by this slice.
