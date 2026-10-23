# Plan versus actual — spatial response-column coefficients

**Plan:** `docs/dev-log/plans/2026-08-29-spatial-coef-ultra-plan.md`
**Branch:** `codex/spatial-column-coef`

| Planned slice | Actual result | Status |
|---|---|---|
| Freeze math/API | Bounded Gaussian long/wide `spatial_coef()` contract frozen at fixed `rho = 1`; spatial-plus-IID mixtures deferred | DONE |
| TDD oracles | Added parser, exact slope-equivalence, long/wide, extraction, edge, and routine recovery tests | DONE |
| Projected-SPDE engine | Reused the released response-column SPDE route with a literal coefficient intercept and full/diagonal coefficient maps; no C++ change | DONE |
| Retained recovery | Added a nine-cell campaign spanning ordinary, correlation, range, and variance regimes | DONE |
| Public API/docs | Exported helper and extractor fields; regenerated Rd/NAMESPACE/pkgdown/NEWS and reconciled Designs 01/130/131/133 plus FG-20 | DONE |
| Articles | Updated and rendered the API grid plus the spatial scope boundary/reference beside the existing C3/C4 worked example in `where-does-the-tree-go` | DONE |
| Local verification | Focused gates, retained recovery, affected article builds, pkgdown, and the full 18,383-pass suite are green | DONE |
| Independent review | Gauss/Noether, Curie, Rose/Boole/Pat, and Grace returned terminal PASS after attributable repairs | DONE |
| Protected landing | Frozen package check, exact-head CI, normal merge, exact-main/site verification, lease release, and iJSDM receipt | PENDING |

The implementation stayed inside the approved first public boundary. It does
not claim spatial `rho < 1`, estimated spatial rho, non-Gaussian families,
intervals, simultaneous sources, latent coefficient covariance, or prediction
at new response-column locations. Every current `*_slope()` helper remains
warning-free and non-deprecated.
