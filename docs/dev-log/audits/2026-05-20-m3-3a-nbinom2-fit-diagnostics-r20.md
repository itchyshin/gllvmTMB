# M3.3a nbinom2 fitted-diagnostics r20 audit

**Branch**: `codex/m3-3a-nbinom2-fit-diagnostics-2026-05-20`

## Purpose

Run the corrected two-scenario `nbinom2` r20/b20 stress grid again
after adding fitted `phi_nbinom2` and fitted link-residual diagnostics
to `dev/m3-grid.R`.

This is not a promotion run. EXT-13 / CI-08 / CI-10 remain `partial`.
The goal is to explain the one-sided `Sigma_unit_diag` misses before
spending on a larger grid.

## Artifact

```text
/tmp/gllvmtmb-m3-3a-fit-diagnostics-r20/nbinom2-two-scenario-fit-diagnostics-r20-b20.rds
```

Artifact metadata:

- branch: `codex/m3-3a-nbinom2-fit-diagnostics-2026-05-20`;
- target: `Sigma_unit_diag`;
- target scale: `link_residual = "none"` (`diag(Lambda Lambda^T + Psi)`);
- family: `nbinom2`;
- rank: `d = 1`;
- scenario replicates: `n_reps = 20`;
- bootstrap replicates: `n_boot = 20`;
- bootstrap cores: `2`;
- CI level: `0.95`;
- initialization: `single_trait_warmup`, residual starts
  `jitter.sd = 0.2`, `optim`/BFGS, `n_init = 5`,
  `init_jitter = 0.05`, `se = FALSE`.

## Scenario Results

| Scenario | Original fits | Bootstrap failures | Coverage | Miss below | Miss above | Median estimate/truth | Median fitted phi/truth | Median fitted link residual | Median link residual/truth | Status |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `baseline_phi1_n60_r20_diag` | 20 / 20 | 70 / 400 | 0.76 | 0 | 24 | 0.546 | 0.691 | 2.895 | 2.038 | `TARGET_FAIL` |
| `lowphi_n120_r20_diag` | 20 / 20 | 12 / 400 | 0.54 | 2 | 44 | 0.520 | 0.799 | 10.909 | 7.487 | `TARGET_FAIL` |

Trait-level medians:

| Scenario | Trait | Median covered | Median estimate/truth | Median fitted phi/truth | Median fitted link residual | Median link residual/truth | Median CI width |
|---|---:|---:|---:|---:|---:|---:|---:|
| `baseline_phi1_n60_r20_diag` | 1 | 1.0 | 0.752 | 0.703 | 2.839 | 1.948 | 2.339 |
| `baseline_phi1_n60_r20_diag` | 2 | 1.0 | 0.600 | 0.840 | 2.143 | 2.208 | 2.558 |
| `baseline_phi1_n60_r20_diag` | 3 | 1.0 | 0.597 | 0.858 | 2.068 | 1.500 | 2.098 |
| `baseline_phi1_n60_r20_diag` | 4 | 0.0 | 0.361 | 0.546 | 4.259 | 3.153 | 1.189 |
| `baseline_phi1_n60_r20_diag` | 5 | 1.0 | 0.608 | 0.717 | 2.735 | 1.399 | 2.222 |
| `lowphi_n120_r20_diag` | 1 | 0.5 | 0.570 | 0.786 | 11.248 | 6.571 | 1.823 |
| `lowphi_n120_r20_diag` | 2 | 1.0 | 0.526 | 0.824 | 10.310 | 7.457 | 1.273 |
| `lowphi_n120_r20_diag` | 3 | 1.0 | 0.553 | 0.783 | 11.324 | 6.804 | 2.048 |
| `lowphi_n120_r20_diag` | 4 | 0.0 | 0.364 | 0.887 | 9.015 | 8.002 | 1.590 |
| `lowphi_n120_r20_diag` | 5 | 1.0 | 0.592 | 0.760 | 11.949 | 8.282 | 1.989 |

## Interpretation

The fitted-diagnostic columns confirm that the corrected target is still
failing for two different reasons that should not be conflated:

1. The fitted latent+unique unit-tier diagonal remains low. Median
   `estimate / truth` is 0.55 for the baseline and 0.52 for the
   low-phi scenario, so the primary M3 target is still biased downward.
2. The fitted NB2 dispersion is also below truth on median
   (`phi_hat / phi_true` about 0.69 and 0.80), which inflates the
   theoretical link-residual increment. That increment is not part of
   the corrected M3 target, but it explains why response-scale
   summaries and latent+unique target summaries diverge strongly in
   this regime.

The next modeling slice should diagnose the `nbinom2` latent+unique
variance underestimation directly. A useful next split is a factorial
r10 pilot over fixed known `phi` versus estimated `phi` and over weaker
latent/unique variance scales. That separates dispersion calibration
from latent+unique variance recovery before another r50/r200 grid.
