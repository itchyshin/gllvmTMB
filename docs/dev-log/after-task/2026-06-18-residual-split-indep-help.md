# After-task report: residual-split indep help cleanup

Date: 2026-06-18 21:30 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Close the leftover `extract_residual_split()` / `extract_proportions()` help
wording that still described observation-level residual variation as a
`unique()` term even though new examples now use per-row `indep()`.

## Files touched

- `R/extract-omega.R`
- `man/extract_residual_split.Rd`
- `man/extract_proportions.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- `extract_residual_split()` now describes the OLRE diagonal as a per-row
  `indep(0 + trait | <obs-level>)` term in new code, with legacy `unique()`
  accepted as compatibility syntax.
- `extract_proportions()` keeps the historical `unique_W` output label but
  explains that the corresponding fit term should normally be written with
  per-row `indep()`.
- The generated Rd files were regenerated from roxygen.

## Definition-of-done accounting

1. Implementation: documentation wording only; no model behavior changed and
   nothing was merged to `main`.
2. Simulation recovery: not applicable.
3. Documentation: roxygen source and generated Rd files updated.
4. Runnable example: unchanged, already used per-row `indep()`.
5. Check-log: `docs/dev-log/check-log.md` has the 21:30 MDT entry with exact
   commands and outcomes.
6. Review pass: no parser, likelihood, or extractor semantics changed; this
   was a lifecycle wording consistency slice.

## Validation

- `R/extract-omega.R` parsed.
- `devtools::document(quiet = TRUE)` regenerated
  `man/extract_residual_split.Rd` and `man/extract_proportions.Rd`.
- Focused extractor / mixed-family OLRE / unique-deprecation tests passed with
  expected heavy skips and one expected lifecycle warning from a legacy
  `unique()` fixture.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no old observation-level `unique()` teaching in the
  touched source/help files.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No extractor `part = "unique"` rename or component-label migration.
- No source-specific/kernel latent-Psi fold.
- Broader post-arc `unique()` cleanup remains ongoing.
