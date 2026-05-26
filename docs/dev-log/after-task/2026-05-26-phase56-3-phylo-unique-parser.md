# After-Task Report: Phase 56.3 `phylo_unique()` Augmented-LHS Parser

**Date:** 2026-05-26
**Branch:** `codex/phase56-3-parser-2026-05-26`
**Lead:** Ada / Codex
**Spawned subagents:** none

## Scope

Phase 56.3 opens the parser bridge for the first augmented-LHS
phylogenetic random-regression syntax:

- `phylo_unique(1 + x | species)`
- `phylo_unique(0 + trait + (0 + trait):x | species)`

This is parser and TMB-data plumbing only. It does not claim Phase
56.4 recovery evidence, validation-debt promotion, NEWS, article
rewrites, or `phylo_slope()` / `animal_slope()` deprecation.

## Files Changed

- `R/brms-sugar.R`
- `R/parse-multi-formula.R`
- `R/fit-multi.R`
- `tests/testthat/test-phase56-3-phylo-unique-parser.R`
- `docs/design/01-formula-grammar.md`
- `CLAUDE.md`
- `docs/dev-log/after-task/2026-05-26-phase56-3-phylo-unique-parser.md`
- `docs/dev-log/recovery-checkpoints/2026-05-26-130035-ada-checkpoint.md`
- `docs/dev-log/check-log.md`

## What Changed

- Added an internal LHS classifier for `intercept_only`,
  `wide_intercept_slope`, and `long_intercept_slope`.
- Extended `parse_covstruct_call()` to attach `extra$lhs_form` and
  `extra$slope_col` where the LHS shape is recognised.
- Extended `phylo_unique()` rewriting so bar-form
  `phylo_unique(0 + trait | species)` remains on the existing
  legacy `phylo_rr(..., .phylo_unique = TRUE)` path, while the two
  Phase 56.3 augmented forms rewrite to an internal `phylo_slope`
  covstruct marked with `.phylo_unique_augmented = TRUE`.
- Updated `R/fit-multi.R` so the marked augmented form sets
  `use_phylo_slope_correlated = 1L`, `n_lhs_cols = 2L`, and
  `Z_phy_aug[, , 1] = cbind(1, data[[slope_col]])`.
- Kept unsupported augmented forms fail-loud, including
  multi-covariate LHS forms.
- Recorded the grammar status as `claimed`, not `covered`, in
  `docs/design/01-formula-grammar.md` and `CLAUDE.md`.

## Evidence

- `Rscript --vanilla -e 'devtools::test(filter = "phase56-3-phylo-unique-parser")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 25`.
- `Rscript --vanilla -e 'devtools::test(filter = "phase56-3-phylo-unique-parser|augmented-lhs-guard|phase56-1-phylo-augmented-stub|phylo-slope|phylo-mode-dispatch|ordinal-probit")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 88`.
- `Rscript --vanilla -e 'devtools::test(filter = "formula-grammar-smoke|phase56-3-phylo-unique-parser|augmented-lhs-guard")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 58`.
- `git diff --check` -> clean.
- Stale-overclaim scan:
  `rg -n 'phylo_unique\\(1 \\+ x \\| species\\).*covered|phylo_unique\\(0 \\+ trait \\+ \\(0 \\+ trait\\):x \\| species\\).*covered|PARAMETER_MATRIX\\(log_sd_b\\)' docs/design/01-formula-grammar.md CLAUDE.md R tests/testthat/test-phase56-3-phylo-unique-parser.R docs/dev-log/after-task/2026-05-26-phase56-3-phylo-unique-parser.md`
  -> no hits.

## Definition of Done Check

1. **Implementation:** complete for the narrow parser/TMB-data slice;
   PR CI still needs to run after publication.
2. **Simulation recovery test:** not appropriate for this slice.
   Phase 56.4 owns Gaussian recovery, wide-long byte identity, and the
   forced `n_lhs_cols` mismatch negative test.
3. **Documentation:** canonical grammar doc updated with `claimed`
   status; no roxygen or Rd files changed.
4. **Runnable user-facing example:** deliberately not added. This is
   not yet advertised as `covered`.
5. **Check-log entry:** included in this PR.
6. **Review pass:** Boole parser and Curie test perspectives are
   active in this report; Gauss/Noether scope is limited because no
   TMB template code changed in this slice; Rose checks the
   `claimed` wording and stale-overclaim boundary.

## Deliberately Not Done

- No `devtools::document()`; no roxygen or generated Rd changes.
- No `pkgdown::check_pkgdown()` yet; no pkgdown navigation, README,
  vignette, article, or reference-topic examples changed.
- No validation-debt row promotion.
- No NEWS entry.
- No A6 article or deprecation work.
- No Phase 56.4 recovery-test activation.
