# CRAN07 v4 exact-aa production verdict

**Date:** 2026-08-09  
**Package identity:** 0.6.0  
**Source archive SHA-256:** `ca6c3feb474d9cbfb44cec3c08e380e8d5810bef8e226cb5b426a6ade9b5f630`  
**Execution host:** Totoro  
**Production attempts:** 44,800 / 44,800  
**Estimand rows:** 1,387,200  
**Frozen closeout:** `HOLD`

This is simulation evidence only. It does not authorize a package release,
version change, publication, or CRAN submission.

## Decision

The preregistered broad dependable-core claim was not earned. Only 28 of the
31 production-eligible cells entered production, every campaign contained at
least one failed admitted cell, and the observable terminal-status detector
identified only 19 of 80 catastrophic truth errors (sensitivity 0.2375;
specificity 0.9627236).

Four two-sample-size core pairs passed their implemented point-estimation
gates: Gaussian `indep()`, Gaussian `dep()`, Poisson-log rank-1
`latent(unique = TRUE)`, and Binomial(10)-logit rank-1
`latent(unique = TRUE)`. These are narrow tested-regime results, not a
package-wide dependable-core or diagnostic-protection claim. Gaussian
`latent(unique = TRUE)` and NB2-log `latent(unique = TRUE)` remain
characterization-only.

The frozen family-pair implementation checked the two core sample-size cells
and their RMSE components. The confirmation design also required the relevant
robustness cells for a broad family-pair claim. Independent adjudication
therefore keeps Poisson and binomial at narrow clean-data point-evidence status
rather than promoting them as broadly robust families.

## Frozen evidence

The five RDS receipts are preserved locally in the read-only directory
`/private/tmp/gllvmtmb-cran07-v4-exact-aa-evidence/` and on Totoro in
`/home/snakagaw/hsq_work/gllvmtmb-cran07-v4-20260808/exact-aa-evidence/`.
Both packets also contain the six exact source/authority envelope files and a
hash-qualified inventory. The Totoro directory and its files have modes 0555
and 0444, respectively.

| Receipt | SHA-256 |
|---|---|
| core summary | `f2965b81d575f43ba81009224ff4efbbe629877126c9012ab46b507e55ad40ec` |
| silent-failure summary | `2fdbeeccb30c6fc335d439a3471de27ac105b311960c5fb76b4c13d063565e94` |
| robustness summary | `01cd1bcec6300171a39cb44a25aa60ea7dbdc400d38778cab8a060229c52b641` |
| production closeout | `994ec3f0ec31184f5e26c31bbcdfa84c265ee634e5666e71c9eeccfd800d1cd0` |
| pilot global gate | `7584b2849c60e4716311dcb27bff35899b4d0cd6c6b0a0737231c0d2f9e19aba` |

Raw attempt shards and run logs remain on Totoro under
`/home/snakagaw/hsq_work/gllvmtmb-cran07-v4-20260808/`. They are not committed.

## Public boundary forced by this evidence

- Gaussian `indep()` and `dep()`: positive point-estimation evidence in the
  tested three-trait complete-data regimes at `n = 60` and `n = 240`.
- Poisson-log and Binomial(10)-logit rank-1 `latent(unique = TRUE)`: positive
  clean-data point-estimation evidence at `n = 100` and `n = 300`; do not
  generalize to family-wide robustness.
- Gaussian latent and NB2 latent: characterization-only.
- Diagnostics: display and triage only; the production detector did not earn a
  reliable catastrophic-error-detection claim.
- Intervals, raw-loading orientation, structured sources, slopes, mixed
  families, ordinal routes, and alternative integration engines: not certified
  by this campaign.

