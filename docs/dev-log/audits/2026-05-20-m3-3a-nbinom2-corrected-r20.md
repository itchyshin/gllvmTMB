# M3.3a nbinom2 Corrected Target Stress Pilot r20

**Date**: 2026-05-20 early morning MT
**Branch used for compute**:
`codex/m3-3a-nbinom2-target-audit-2026-05-19`
**Code commit used for compute**:
`e02227aac11f85921d1aeba4aaf287f07e3e71c2`
**Report branch**:
`codex/m3-3a-nbinom2-corrected-r20-audit-2026-05-20`
**Roles**: Ada / Curie / Fisher / Grace / Rose

## Purpose

Run one bounded stress pilot after the `Sigma_unit_diag` target-scale
fix from PR #211. The question is whether correcting the M3 target to
latent + unique covariance,

```text
diag(Lambda Lambda^T + Psi)
```

is sufficient to recover 0.94 bootstrap coverage for `nbinom2-d1`.

It is not. This artifact is evidence for the next calibration slice,
not validation promotion.

## Artifact

Saved artifact:

```text
/tmp/gllvmtmb-m3-3a-corrected-stress-r20/nbinom2-two-scenario-corrected-r20-b20.rds
```

Settings:

- family: `nbinom2`;
- latent rank: `d = 1`;
- traits: `5`;
- target: `Sigma_unit_diag`;
- interval method: bootstrap with `link_residual = "none"`;
- nominal level: `0.95`;
- bootstrap replicates: `n_boot = 20`;
- scenario replicates: `n_reps = 20`;
- bootstrap cores: `2`;
- initialisation: `single_trait_warmup`;
- start method: residual starts with `jitter.sd = 0.2`;
- optimizer: `optim` / `BFGS`;
- starts: `n_init = 5`, `init_jitter = 0.05`;
- standard errors: `se = FALSE`.

Scenarios:

| Scenario | Units | phi | lambda_scale | psi_scale |
|---|---:|---:|---:|---:|
| `baseline_phi1_n60_r20` | 60 | 1.0 | 1.0 | 1.0 |
| `lowphi_n120_r20` | 120 | 0.4 | 1.0 | 1.0 |

## Results

| Scenario | Original fits | Bootstrap failures | Coverage | Miss below | Miss above | Median estimate/truth | Status |
|---|---:|---:|---:|---:|---:|---:|---|
| `baseline_phi1_n60_r20` | 20 / 20 | 62 / 400 | 0.77 | 1 | 22 | 0.610 | `TARGET_FAIL` |
| `lowphi_n120_r20` | 20 / 20 | 16 / 400 | 0.58 | 1 | 41 | 0.574 | `TARGET_FAIL` |

Trait-level median summaries:

| Scenario | Trait | Median covered | Median estimate | Truth | Median estimate/truth | Median CI width |
|---|---:|---:|---:|---:|---:|---:|
| `baseline_phi1_n60_r20` | 1 | 1.0 | 1.244 | 1.580 | 0.658 | 1.678 |
| `baseline_phi1_n60_r20` | 2 | 1.0 | 0.875 | 1.519 | 0.483 | 2.095 |
| `baseline_phi1_n60_r20` | 3 | 1.0 | 0.759 | 1.641 | 0.470 | 1.744 |
| `baseline_phi1_n60_r20` | 4 | 1.0 | 1.437 | 1.991 | 0.606 | 3.189 |
| `baseline_phi1_n60_r20` | 5 | 1.0 | 1.392 | 2.092 | 0.812 | 2.326 |
| `lowphi_n120_r20` | 1 | 0.5 | 0.879 | 1.580 | 0.571 | 1.242 |
| `lowphi_n120_r20` | 2 | 1.0 | 0.940 | 1.519 | 0.677 | 1.733 |
| `lowphi_n120_r20` | 3 | 1.0 | 0.932 | 1.641 | 0.570 | 1.556 |
| `lowphi_n120_r20` | 4 | 0.0 | 0.758 | 1.991 | 0.444 | 1.769 |
| `lowphi_n120_r20` | 5 | 1.0 | 1.456 | 2.092 | 0.691 | 2.084 |

## Interpretation

PR #211 fixed the earlier residual-scale mismatch. The failure mode
changed accordingly:

- the r10 pre-fix artifact had truth mostly below the interval because
  estimates and CIs were on a larger response-scale target;
- the corrected r20 artifact now has truth mostly above the interval,
  with median estimates around 57-61% of latent + unique truth.

So the next problem is not another target-scale mismatch. The corrected
runner is now estimating too little unit-tier latent + unique variance
relative to the DGP in these `nbinom2-d1` settings, and percentile
bootstrap intervals do not compensate enough.

## What Is Missing

The current M3 grid rows store `truth_phi` but not fitted `phi` or the
implied fitted link residual. That blocks a clean separation of:

- under-estimated latent loadings;
- over- or under-estimated unique variance;
- dispersion calibration;
- bootstrap refit failures.

The next implementation slice should add fitted-dispersion and fitted
link-residual diagnostics to M3 rows before launching another larger
grid.

## Scope Status

- **IN**: the corrected `Sigma_unit_diag` path from PR #211 was used;
  original fits completed in both scenarios.
- **PARTIAL**: EXT-13, CI-08, and CI-10 remain partial. The corrected
  stress run still fails the 0.94 empirical coverage gate.
- **PLANNED**: add fitted `phi` / link-residual diagnostics to M3 row
  metadata, then rerun the same scenarios before broadening to the
  full 15-cell grid.
