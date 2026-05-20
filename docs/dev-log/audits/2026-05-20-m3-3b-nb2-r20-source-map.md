# M3.3b NB2 r20 Source-Map Audit

Date: 2026-05-20

Scope: local point-only evidence for PR #221. This audit supports issue
#217 and #218 but does not close either issue. Rows with
`ci_method = "none"` and `n_boot = 0` are source-map diagnostics, not
coverage or promotion evidence.

## Commands

```sh
Rscript --vanilla dev/precompute-m3-grid.R \
  --nb2-stress-map \
  --n-reps=10 \
  --out-dir=/tmp/gllvmtmb-m3-3b-stress-r10 \
  --out-prefix=m3-nb2-stress-r10

Rscript --vanilla dev/precompute-m3-grid.R \
  --nb2-stress-map \
  --n-reps=20 \
  --out-dir=/tmp/gllvmtmb-m3-3b-stress-r20 \
  --out-prefix=m3-nb2-stress-r20
```

Control r10 evidence used the same surface register with only the
Gaussian and Poisson control rows selected from
`m3_nb2_stress_surfaces(include_controls = TRUE)`.

## r20 Summary

| Surface | fit_phi_mode | Fits | Median estimate/truth | Median phi/truth | Median link-residual/truth | Status |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `nbinom2-d1-baseline-phi1-n60` | estimated | 20/20 | 0.563 | 0.546 | 2.647 | `POINT_ONLY` |
| `nbinom2-d1-baseline-phi1-n60` | known | 20/20 | 0.825 | 1.000 | 1.205 | `POINT_ONLY` |
| `nbinom2-d1-lowphi-n120` | estimated | 20/20 | 0.631 | 0.783 | 8.630 | `POINT_ONLY` |
| `nbinom2-d1-lowphi-n120` | known | 20/20 | 0.790 | 1.000 | 5.332 | `POINT_ONLY` |
| `nbinom2-d1-weakvar-phi1-n60` | estimated | 20/20 | 0.452 | 0.536 | 3.005 | `POINT_ONLY` |
| `nbinom2-d1-weakvar-phi1-n60` | known | 20/20 | 0.780 | 1.000 | 1.297 | `POINT_ONLY` |

All NB2 rows had `n_failed = 0`, `n_ci_missing = 100`,
`n_boot_attempted = 0`, and `n_boot_failed = 0`. The CIs are missing by
design because this was a point-only run.

## Control Contrast

The r10 control rows completed 10/10 fits each:

| Surface | Family | Median estimate/truth | Median link-residual/truth |
| --- | --- | ---: | ---: |
| `gaussian-d1-baseline-n60` | Gaussian | 1.150 | 0.000 |
| `poisson-d1-baseline-n60` | Poisson | 0.933 | 0.191 |

The control contrast makes the NB2 pattern look family-specific rather
than a universal covariance-engine failure.

## Sidecar Reviews

Carver's read-only source-map audit found no obvious target mismatch,
no `phi` inverse bug, and no link-residual leakage into the target
estimate. The leading explanation is NB2 finite-sample / unit-tier
variance identifiability plus possible start or local-basin behavior.

Godel's Florence/Pat review marked the report layer `REVISE`. The first
rendered figure should be an NB2 source-map / admission dashboard, not a
coverage plot. It must show `POINT_ONLY`, missing intervals by design,
fit-phi mode, denominator counts, and failure ledgers directly.

## Decision

Do not admit any NB2 surface to r50 yet. The next slice should probe
NB2 starts/local basins and update the rendered diagnostic dashboard so
point-only rows show `NOT_EVALUATED` for coverage gates rather than
failed coverage.
