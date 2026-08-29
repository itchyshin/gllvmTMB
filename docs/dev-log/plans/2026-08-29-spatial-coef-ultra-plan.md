# Spatial response-column coefficient Ultra Plan

This durable plan is the repository-facing copy of
`LOOP/spatial-coef-ultra-plan.md`. It admits the first public projected-SPDE
coefficient model as `spatial_coef(formula, mesh, rho = 1)`, using the released
`spatial_slope()` engine with R-only changes. It requires exact no-intercept
endpoint identity, long/wide equivalence, intercept-aware SPDE design,
`Sigma_field` extraction, bounded recovery, complete documentation, independent
review, three-OS CI, protected merge, exact-main verification, and live-site
proof.

Interior or estimated spatial `rho` remains a separate future model because it
needs an IID coefficient field and joint rho-range identifiability evidence.
No current `*_slope()` helper is deprecated or warned. The mathematical
crosswalk is `LOOP/spatial-coef-alignment.md`; executable acceptance gates are
`.unlazy/spatial-column-coef/GATES.md`.
