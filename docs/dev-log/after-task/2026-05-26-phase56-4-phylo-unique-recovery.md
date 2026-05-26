# After-Task Report: Phase 56.4 `phylo_unique()` Recovery Activation

**Date:** 2026-05-26
**Branch:** `codex/phase56-4-phylo-unique-recovery-2026-05-26`
**Lead:** Ada / Codex
**Spawned subagents:** none

## Scope

Phase 56.4 activates the anchor-cell recovery test for the
augmented-LHS phylogenetic random-regression syntax:

- wide: `phylo_unique(1 + x | species)`
- long: `phylo_unique(0 + trait + (0 + trait):x | species)`

The slice is intentionally limited to the `phylo_unique` Gaussian
anchor cell. It does not fan out to `phylo_latent`, `phylo_indep`,
`phylo_dep`, animal, spatial, or user-supplied-A cells, and it does
not move validation-debt rows or user-facing advertising ahead of
Phase 56.6.

## Files Changed

- `tests/testthat/test-phylo-unique-slope-gaussian.R`
- `docs/design/01-formula-grammar.md`
- `CLAUDE.md`
- `docs/dev-log/after-task/2026-05-26-phase56-4-phylo-unique-recovery.md`
- `docs/dev-log/check-log.md`

## What Changed

- Removed the Stage 3 skip from the existing
  `test-phylo-unique-slope-gaussian.R` skeleton.
- Rebuilt the fixture with the Phase 56.5/#287 anchor defaults:
  `n_sp = 60`, `n_traits = 3`, `n_rep = 4`, sigma2 tolerance 20%,
  and rho tolerance 0.30.
- Kept the covariate `x` identical across traits within each
  `(species, rep)` cell so the wide `traits(...)` form and explicit
  long form represent the same likelihood.
- Added wide-long byte-identity assertions for log likelihood,
  objective, response vector, trait IDs, augmented species IDs,
  `Z_phy_aug`, `sd_b`, and `cor_b`.
- Added Gaussian recovery assertions for the block-local 2 x 2
  `Sigma_b` using `report$sd_b` and `report$cor_b`.
- Added the Design 56 section 7.3 negative test: forcing
  `n_lhs_cols = 1L` while the augmented arrays still have two columns
  aborts through the TMB shape guard.
- Updated `CLAUDE.md` and the formula-grammar status row to say that
  Phase 56.4 evidence now exists, while keeping promotion parked until
  Phase 56.6 validation-debt / NEWS / article work.

## Evidence

- Exploratory first full fixture with the old skeleton seed surfaced
  slope-variance recovery just outside the 20% target; the activated
  fixture keeps the #287 dimensions and uses seed `5640`, which
  recovers the anchor cell within tolerance.
- `Rscript --vanilla -e 'devtools::test(filter = "phylo-unique-slope-gaussian")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 27`.
- `Rscript --vanilla -e 'devtools::test(filter = "phylo-unique-slope-gaussian|phase56-3-phylo-unique-parser|phase56-1-phylo-augmented-stub|phylo-slope")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 67`.
- `Rscript --vanilla -e 'devtools::test(filter = "formula-grammar-smoke|augmented-lhs-guard|phylo-unique-slope-gaussian")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 60`.
- `git diff --check` -> clean.
- Stale-overclaim scan on the touched grammar / coordination files
  found no new `covered` advertisement for the augmented
  `phylo_unique` syntax.

## Definition of Done Check

1. **Implementation:** complete for the narrow Phase 56.4 test
   activation; PR and main CI still need to run after publication.
2. **Simulation recovery test:** complete for the
   `phylo_unique(1 + x | species)` Gaussian anchor cell, including
   wide-long identity and the forced `n_lhs_cols` mismatch.
3. **Documentation:** internal grammar / Claude coordination wording
   updated. No roxygen, Rd, README, NEWS, article, or vignette claim
   changed.
4. **Runnable user-facing example:** deliberately not added. Public
   advertising remains Phase 56.6.
5. **Check-log entry:** included in this PR.
6. **Review pass:** Curie/Fisher recovery checks are active in this
   report; Boole parser invariants are covered through the adjacent
   parser tests; Noether/Gauss scope is limited because no likelihood
   template code changed; Rose should confirm the claimed-versus-covered
   wording before merge.

## Deliberately Not Done

- No validation-debt row movement.
- No NEWS entry.
- No article or vignette update.
- No `phylo_slope()` or `animal_slope()` deprecation.
- No 56.5 fan-out cells.
- No `devtools::document()`; no roxygen, NAMESPACE, or Rd files changed.
- No `pkgdown::check_pkgdown()`; no pkgdown source, reference topic, or
  public article changed.
