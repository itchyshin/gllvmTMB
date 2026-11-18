# Plan versus actual — public response-column coefficients

**Plan:** `docs/dev-log/plans/2026-08-27-phylo-coef-public-ultra-plan.md`
**Branch:** `codex/phylo-coef-public`

| Planned slice | Actual result | Status |
|---|---|---|
| Freeze math/API | Bounded Gaussian long/wide `column_coef()` and `phylo_coef()` contract frozen; other sources deferred | DONE |
| TDD oracles | Added parser, source, spectral, gradient, extraction, recovery, slope-equivalence, and long/wide tests | DONE |
| Estimated-rho engine | Added AD-safe standardized-source spectral precision/log determinant and reports | DONE |
| Public API/docs | Exported helpers and extractor; regenerated Rd/NAMESPACE/pkgdown/NEWS | DONE |
| Articles | Repaired and rendered `where-does-the-tree-go` plus API grid; left unrelated phylogenetic article unchanged | DONE |
| Local verification | Focused gates, slope regressions, article builds, pkgdown, and installed-package check passed | DONE |
| Independent review | Gauss/Noether, Grace, Rose/Pat terminal PASS after repairs | DONE |
| Protected landing | One push; routine and manual three-OS exact-head CI green; PR #1220 merged normally at `badb45147`; exact-main run `33139404505` green; terminal lease release follows this closeout | DONE |

The implementation stayed inside the approved boundary. No animal, kernel, or
spatial coefficient helper was admitted; no non-Gaussian or interval claim was
made; no current `*_slope()` helper was warned or deprecated. The only material
addition beyond the first fixed-rho plan was the already-approved estimated-rho
and public/article completion slice.
