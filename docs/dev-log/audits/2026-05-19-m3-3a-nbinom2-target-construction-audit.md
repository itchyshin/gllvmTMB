# M3.3a nbinom2 Target-Construction Audit

**Date**: 2026-05-19 late evening MT
**Branch**: `codex/m3-3a-nbinom2-target-audit-2026-05-19`
**Roles**: Ada / Curie / Fisher / Grace / Rose

## Purpose

Diagnose why the `nbinom2-d1` stress pilot had mostly successful
original fits and bootstrap refits but poor `Sigma_unit_diag`
coverage, especially in the low-dispersion 120-unit scenario.

This audit does not promote CI-08, CI-10, or EXT-13. It fixes the
target construction used by the M3 runner and records the remaining
calibration risk before the next stress run.

## Source Finding

The M3 truth target for `Sigma_unit_diag` is

```text
truth$diag_Sigma = diag(Lambda Lambda^T + Psi)
```

This is the fitted latent + unique unit-tier covariance target.

Before this lane, `dev/m3-grid.R` compared that truth to
`extract_Sigma(fit, level = "unit")`, whose default
`link_residual = "auto"` adds the family/link implicit residual
variance to non-Gaussian trait diagonals. The bootstrap path used
`bootstrap_Sigma()` with the same implicit default through
`.extract_summaries()`. Thus both the point estimate and bootstrap
intervals were on a larger marginal latent response-variance scale
than the DGP truth used for coverage.

The corrected M3 target path calls:

```r
extract_Sigma(fit, level = "unit", link_residual = "none")
bootstrap_Sigma(fit, level = "unit", what = "Sigma",
                link_residual = "none")
```

`link_residual = "none"` is now exposed directly on
`bootstrap_Sigma()` so extractor-level bootstrap summaries can choose
the same scale convention as `extract_Sigma()`.

## Artifact Re-read

The prior r10 artifact was re-read without rerunning the simulation:

```text
/tmp/gllvmtmb-m3-3a-stress-pilot-r10/nbinom2-two-scenario-r10-b10.rds
```

For a fixed `nbinom2` dispersion `phi`, the log-link delta residual
added by `link_residual = "auto"` is `trigamma(phi)`. Recomputing the
coverage check against `truth + trigamma(phi)` gives:

| Scenario | Original coverage | Coverage against truth + residual | Original miss below | New miss below | New miss above | Median estimate / original truth | Median estimate / truth + residual | Residual added |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `baseline_phi1_n60_r10` | 0.32 | 0.70 | 34 | 13 | 2 | 2.477 | 1.240 | 1.645 |
| `lowphi_n120_r10` | 0.00 | 0.58 | 50 | 21 | 0 | 8.089 | 1.534 | 7.275 |

This confirms that the target-scale mismatch explains a large part of
the coverage failure. It does not explain all of it, particularly for
low dispersion.

## Remaining Calibration Signal

The low-dispersion scenario still has only 0.58 coverage even after
moving the truth to the `link_residual = "auto"` scale. That means the
next run should not be treated as a solved validation problem. The
remaining signal is consistent with dispersion-estimation calibration:
several fits estimate smaller `phi` than the DGP, which inflates the
implied log-link residual variance and keeps estimates above either
truth scale.

## Implementation Change

- `bootstrap_Sigma()` now accepts
  `link_residual = c("auto", "none")`.
- The argument is appended after `keep_draws`, preserving old
  positional calls where the sixth argument was `seed`.
- `bootstrap_Sigma()` forwards the convention to original point
  estimates and each bootstrap refit summary.
- `extract_communality(ci = TRUE, method = "bootstrap")` and
  `extract_correlations(method = "bootstrap")` now forward their
  caller's `link_residual` convention to `bootstrap_Sigma()`.
- `dev/m3-grid.R` uses `link_residual = "none"` for
  `Sigma_unit_diag`, matching the DGP truth.
- Roxygen, Rd, NEWS, and design docs record the scale convention and
  the still-partial validation status.

## Verification

Targeted tests pass after the change:

```text
devtools::test(filter = "bootstrap-Sigma")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 39 ]

devtools::test(filter = "m1-8-bootstrap-mixed-family")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 31 ]
```

A direct M3 smoke using `devtools::load_all(".")`, `n_reps = 1`, and
`n_boot = 3` returned finite `Sigma_unit_diag` estimates and bootstrap
intervals for all five traits with `n_boot_failed = 0`.

## Scope Status

- **IN**: MIX-08 remains covered for mixed-family bootstrap refits;
  MIX-09 remains covered for the `link_residual = "auto"` residual
  convention.
- **PARTIAL**: EXT-13, CI-08, and CI-10 remain partial for
  non-Gaussian bootstrap inference. The corrected target path must be
  rerun through M3.3a stress evidence before promotion.
- **PLANNED**: a larger corrected `nbinom2` stress run should compare
  latent + unique covariance coverage and dispersion-calibration
  diagnostics before any full 15-cell production grid.

## Next Action

Rerun the bounded two-scenario `nbinom2` stress grid with the corrected
`Sigma_unit_diag` target before scaling up. Recommended first pass:
`n_reps = 20`, `n_boot = 20`, the same baseline and low-dispersion
scenarios, and explicit summaries for fitted `phi`, link residual, and
latent + unique covariance ratios.
