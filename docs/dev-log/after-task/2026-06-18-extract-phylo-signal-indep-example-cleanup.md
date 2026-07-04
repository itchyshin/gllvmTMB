# After-task report: extract phylo signal example uses indep

Date: 2026-06-18
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This cleanup keeps the exported `extract_phylo_signal()` example aligned with
the ordinary `unique()` deprecation lane. The phylogenetic shared term remains
source-specific syntax, while the ordinary non-phylogenetic diagonal tier now
uses `indep(0 + trait | species)`.

## Files touched

- `R/extract-omega.R`
- `man/extract_phylo_signal.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Verification

- `parse("R/extract-omega.R"); devtools::document(quiet = TRUE)` passed.
- `devtools::test(filter = "extract-omega|phylo-signal|canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")`
  passed with expected INLA/heavy skips.
- `pkgdown::check_pkgdown()` passed.
- Focused source/Rd scan confirmed the example now uses
  `indep(0 + trait | species)`.
- `git diff --check` passed.

## Not claimed

- No `unique()` keyword removal.
- No source-specific/kernel latent-Psi fold.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
