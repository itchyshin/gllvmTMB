# After-task report: two-Psi diagnostic examples use indep

Date: 2026-06-18
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This small cleanup keeps the `unique()` deprecation lane moving after the
coevolution stop point. The exported two-Psi diagnostic examples now use
`indep(0 + trait | species)` for the ordinary non-phylogenetic diagonal tier,
while `phylo_unique(species)` remains in place because source-specific
latent-Psi folding has not landed.

## Files touched

- `R/extract-two-psi-cross-check.R`
- `man/compare_dep_vs_two_psi.Rd`
- `man/compare_indep_vs_two_psi.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Verification

- `parse("R/extract-two-psi-cross-check.R"); devtools::document(quiet = TRUE)`
  passed.
- `devtools::test(filter = "two-psi|phylo-q-decomposition|canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")`
  passed with expected INLA/heavy skips.
- `pkgdown::check_pkgdown()` passed.
- Focused stale scan for `phylo_unique(species) + unique(0 + trait | species)`
  in the source and regenerated Rd returned no hits.
- `git diff --check` passed.

## Not claimed

- No `unique()` keyword removal.
- No source-specific `phylo_unique()` fold.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
