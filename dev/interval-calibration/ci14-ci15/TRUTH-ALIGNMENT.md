# CI-14/15 truth and report alignment

This packet is a campaign contract, not calibration evidence.  It constructs no
data and performs no fit.  The pending 5,000-replicate campaigns remain subject
to a separately measured pre-run receipt and explicit approval.

| Route | Symbolic target | DGP contract | Fitted/report contract |
| --- | --- | --- | --- |
| CI-14 ordinary augmented latent | `psi_slope[t]` | nonzero diagonal `Psi_slope` | `slope_sd_ci()$estimate`, component `unique_psi` |
| CI-14 total marginal | `sqrt(diag(Lambda_slope Lambda_slope^T + Psi_slope))[t]` | same nonzero `Lambda_slope` and `Psi_slope` | `slope_sd_ci()$total_sd`, joint `sd_B_slope_total` ADREPORT |
| CI-15 phylogenetic Cholesky | `sqrt(diag(L_phy L_phy^T))[2,4]` | lower-triangular interleaved `(intercept_t1, slope_t1, intercept_t2, slope_t2)` factor | `slope_sd_ci()$estimate`, `sd_b` ADREPORT positions 2 and 4 |
| CI-15 ordinary loadings-only | `sqrt(diag(Lambda_slope Lambda_slope^T))[t]` | nonzero rank-2 `Lambda_slope`, exactly zero `Psi_slope` | `slope_sd_ci()$estimate`, `sd_rr_B_slope` ADREPORT |

The first CI-15 loadings-only slope route is deliberately protected from the
old misspecified fixture: any nonzero `Psi_slope` makes its DGP and
`unique = FALSE` fit target different quantities.  The packet validator rejects
that fixture before an outer attempt can be retained.

The packing statements are grounded in `R/slope-sd-ci.R` and its accompanying
tests: the phylogenetic path reads the C++ ADREPORTed `sd_b` rather than
reconstructing `theta_dep_chol` by hand, and the ordinary loadings-only path
reads `sd_rr_B_slope`.  No claim here recalibrates the public Wald intervals.
