# M3.3b NB2 Stress-Report Smoke Audit

Date: 2026-05-20  
Branch: `codex/m3-3b-nb2-stress-report-2026-05-20`  
Artifact directory:
`/tmp/gllvmtmb-m3-3b-stress-smoke/`

## Purpose

Verify that the new M3.3b stress-map scaffold can run the first
Design 50 point-only surfaces and write a dev-facing diagnostic report
without turning point estimates into coverage evidence.

This smoke covers rolling slices 4, 6, 9, 12, and 13 at scaffold
level:

- slice 4: NB2 point-only stress design;
- slice 6: estimated-phi source-map fields;
- slice 9: diagnostic report v0;
- slice 12: Poisson control-surface path;
- slice 13: Gaussian control-family contrast path.

It does not close the r20/r50, bootstrap, Florence-rendered-figure, or
validation-debt status slices.

## Command

```sh
Rscript --vanilla dev/precompute-m3-grid.R \
  --nb2-stress-map \
  --include-controls \
  --n-reps=1 \
  --out-dir=/tmp/gllvmtmb-m3-3b-stress-smoke \
  --out-prefix=m3-nb2-stress-smoke
```

Mode defaults were stress-map defaults:

- `init_strategy = "single_trait_warmup"`;
- `start_method = "res"` with `jitter.sd = 0.2`;
- `optimizer = "optim"` with `method = "BFGS"`;
- `n_init = 3`;
- `se = FALSE`;
- `target = "Sigma_unit_diag"`;
- `ci_method = "none"`;
- `n_boot = 0`.

## Surfaces

| Surface | Family | Fit phi mode | Purpose |
|---|---|---|---|
| `nbinom2-d1-baseline-phi1-n60` | NB2 | estimated + known | Baseline dispersion/covariance source map. |
| `nbinom2-d1-lowphi-n120` | NB2 | estimated + known | Low-dispersion stress with more units. |
| `nbinom2-d1-weakvar-phi1-n60` | NB2 | estimated + known | Lower latent loading scale and higher unique scale. |
| `gaussian-d1-baseline-n60` | Gaussian | estimated | Low-noise covariance-geometry control. |
| `poisson-d1-baseline-n60` | Poisson | estimated | Count-family control without NB2 dispersion. |

## Result

The smoke completed 8 one-replicate surfaces in about 64 seconds and
wrote:

- `m3-nb2-stress-smoke-grid.rds`;
- `m3-nb2-stress-smoke-summary.rds`;
- `m3-nb2-stress-smoke-diagnostic-report.md`.

All surfaces were labelled `POINT_ONLY`. `coverage` stayed `NA`, not
zero, and `ci_method` stayed `none` for the point-estimate scaffold.
This is the required behavior: these rows diagnose point estimates,
fitted NB2 dispersion, link-residual increments, and control-family
contrast, but they cannot move CI-08 or CI-10.

## Smoke Summary

| Surface | Fit phi mode | Completed | Median estimate/truth | Median phi/truth | Median link residual/truth | Status |
|---|---|---:|---:|---:|---:|---|
| `gaussian-d1-baseline-n60` | estimated | 1/1 | 1.233 | NA | 0.000 | `POINT_ONLY` |
| `nbinom2-d1-baseline-phi1-n60` | estimated | 1/1 | 0.554 | 0.411 | 3.453 | `POINT_ONLY` |
| `nbinom2-d1-baseline-phi1-n60` | known | 1/1 | 0.913 | 1.000 | 0.889 | `POINT_ONLY` |
| `nbinom2-d1-lowphi-n120` | estimated | 1/1 | 0.768 | 0.560 | 9.946 | `POINT_ONLY` |
| `nbinom2-d1-lowphi-n120` | known | 1/1 | 0.809 | 1.000 | 3.931 | `POINT_ONLY` |
| `nbinom2-d1-weakvar-phi1-n60` | estimated | 1/1 | 0.319 | 0.495 | 2.948 | `POINT_ONLY` |
| `nbinom2-d1-weakvar-phi1-n60` | known | 1/1 | 0.603 | 1.000 | 0.966 | `POINT_ONLY` |
| `poisson-d1-baseline-n60` | estimated | 1/1 | 0.853 | NA | 0.245 | `POINT_ONLY` |

Single-replicate numbers are not evidence for promotion. They verify
the scaffold and identify the first r10/r20 grid shape.

## Florence Preflight

Verdict: `REVISE`

Main reason: the report is a Markdown table report, not yet a rendered
scientific figure.

What works: the report exposes surface identity, target, method,
fit-phi mode, estimate/truth ratios, fitted phi/truth, link-residual
ratios, failure counts, and the `POINT_ONLY` status.

Blocking issues: no visual admission forest, no trait-level plot, no
failure-ledger panel, and no rendered figure export exist yet.

Minimal patch: use the report data to build the first small ggplot
diagnostic panels before any r50/r200 surface admission.

Verification: Florence should review a rendered figure against
Design 46 and Design 50 before the next broad M3 run.

## Next Action

Run the r10/r20 NB2 stress map without controls first, then use the
same report scaffold to decide whether the first r50 surface is
admissible. Keep #217 and #218 open until that report exists.
