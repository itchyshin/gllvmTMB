# After-task report: API/profile ordinary unique cleanup

Date: 2026-06-18 21:11 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup by removing one more
ordinary no-prefix teaching path from the API keyword-grid article and
profile-derived diagnostics.

## Files touched

- `R/profile-derived.R`
- `R/profile-derived-curves.R`
- `vignettes/articles/api-keyword-grid.Rmd`
- `man/profile_ci_phylo_signal.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- The API keyword-grid long/wide starter example now fits ordinary `latent()`
  alone. The nearby prose says default ordinary `latent()` includes the diagonal
  Psi companion.
- `profile_ci_repeatability()` and `profile_repeatability()` diagnostics now
  recommend default ordinary `latent()` tiers when diagonal Psi parameters are
  absent, and reserve explicit `unique()` for legacy diag-only compatibility.
- The simple two-component phylogenetic-signal profile documentation now uses
  `indep(0 + trait | species)` for the non-phylogenetic standalone diagonal
  term.

## Definition-of-done accounting

1. Implementation: local docs/diagnostic cleanup only; not merged to `main`.
2. Simulation recovery: not applicable; no likelihood, parser, or estimator
   behavior changed.
3. Documentation: roxygen source and generated Rd updated for
   `profile_ci_phylo_signal()`.
4. Runnable example: the API keyword-grid article starter example now uses the
   preferred ordinary latent syntax.
5. Check-log: `docs/dev-log/check-log.md` has the 21:11 MDT entry with exact
   commands and outcomes.
6. Review pass: no likelihood or formula-grammar behavior changed; this was a
   lifecycle/reference consistency slice.

## Validation

- `devtools::document(quiet = TRUE)` regenerated
  `man/profile_ci_phylo_signal.Rd`.
- `parse("R/profile-derived.R")` and `parse("R/profile-derived-curves.R")`
  succeeded.
- Direct `rmarkdown::render()` of `vignettes/articles/api-keyword-grid.Rmd`
  succeeded.
- Focused `profile-derived-curves|confint-derived` tests passed with expected
  heavy skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no remaining ordinary starter/example prompt for
  `unique(0 + trait | individual)`, `unique(1 | individual)`, or
  `unique(0 + trait | <unit>/<obs>)` in the touched files.
- Dashboard JSON validation, `git diff --check`, and both dashboard HTTP checks
  passed.

## Still open

- No keyword removal.
- No source-specific/kernel paired-Psi fold.
- No extractor `part = "unique"` rename.
- No Paper 2 multi-kernel explicit Psi.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
