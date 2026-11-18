# Gamma under-coverage -- resolved by measurement: it heals with domain growth

Pure analysis of existing campaign rows (no new fits). The twice-flagged
gamma Wald under-coverage decomposes cleanly:

| cell | bias | emp SD / Wald SE | sd(z) | coverage |
| --- | --- | --- | --- | --- |
| effort E=16, 360 cells (n_pd 136) | <= 0.007 | 1.14-1.17 | 1.14-1.21 | 0.875-0.904 |
| domain s=2.5, 2,250 cells (n_pd 111) | <= 0.002 | 0.99-1.06 | 1.00-1.07 | 0.919-0.955 |

Diagnosis: gamma is essentially UNBIASED everywhere; the failure at the small
domain is SE mis-calibration alone -- plug-in Laplace SEs understate the
variance by ~15% when the shared field is estimated from ~20 effective
patches, and the deficit disappears at 2,250 cells (~125 patches), where
coverage is nominal.

Consequence: the two-arm law extends to inference -- interval calibration for
source-bias coefficients is also bought with cells, not records. For the
empirical designs (thousands of cells) plug-in Wald intervals for gamma are
expected to be nominal; no methodological correction is required at
scale. At small designs, report the ~15% SE deficit rather than pretending
calibration.
