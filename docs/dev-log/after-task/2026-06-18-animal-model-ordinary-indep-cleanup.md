# After-task report: animal-model ordinary indep cleanup

Date: 2026-06-18 21:37 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Update the `animal-model` article so the ordinary non-genetic diagonal tier uses
`indep()` rather than deprecated ordinary `unique()` syntax.

## Files touched

- `vignettes/articles/animal-model.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- Replaced ordinary `unique(0 + trait | id)` with
  `indep(0 + trait | id)` in two worked animal-model fits.
- Reworded the nearby interpretation from "trait-level residual covariance" to
  "trait-level diagonal covariance".
- Left `animal_unique()` intact as the source-specific explicit genetic Psi
  compatibility term.

## Definition-of-done accounting

1. Implementation: article wording/code cleanup only; no parser or model
   behavior changed and nothing was merged to `main`.
2. Simulation recovery: not applicable.
3. Documentation: article source updated and rendered directly.
4. Runnable example: the article code now uses the preferred ordinary
   `indep()` spelling for the non-genetic diagonal tier.
5. Check-log: `docs/dev-log/check-log.md` has the 21:37 MDT entry with exact
   commands and outcomes.
6. Review pass: article-tier guidance applied; no likelihood, parser, or
   formula semantics changed.

## Validation

- `vignettes/articles/animal-model.Rmd` rendered directly.
- Focused animal / keyword-grid / deprecation tests passed with expected heavy,
  INLA, and `nadiv` skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no ordinary `unique(0 + trait | id)` article
  examples.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No source-specific/kernel latent-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` cleanup remains ongoing.
