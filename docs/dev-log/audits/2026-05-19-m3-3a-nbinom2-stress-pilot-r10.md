# M3.3a nbinom2 Stress Pilot r10

**Date**: 2026-05-19 late evening MT
**Branch**: `codex/m3-3a-nbinom2-stress-pilot-r10-2026-05-19`
**Roles**: Ada / Curie / Fisher / Grace / Rose

## Purpose

Use the newly merged scenario controls from PR #209 to run a slightly
larger `nbinom2-d1` stress pilot. The goal is to distinguish original
fit failure, bootstrap refit failure, and target-scale bias before any
larger M3.3a rerun.

This is still not validation-debt promotion evidence. The pilot uses
`n_reps = 10`, `n_boot = 10`, and only two scenarios.

## Settings

Shared settings:

- family: `nbinom2`;
- latent rank: `d = 1`;
- traits: `5`;
- target: `Sigma_unit_diag`;
- interval method: bootstrap;
- nominal level: `0.95`;
- bootstrap cores: `2`;
- initialisation: `single_trait_warmup`;
- start method: residual starts with `jitter.sd = 0.2`;
- optimizer: `optim` / `BFGS`;
- starts: `n_init = 5`, `init_jitter = 0.05`;
- standard errors: `se = FALSE`.

Scenarios:

| Scenario | Units | phi | lambda_scale | psi_scale |
|---|---:|---:|---:|---:|
| `baseline_phi1_n60_r10` | 60 | 1.0 | 1.0 | 1.0 |
| `lowphi_n120_r10` | 120 | 0.4 | 1.0 | 1.0 |

Saved artifact:

```text
/tmp/gllvmtmb-m3-3a-stress-pilot-r10/nbinom2-two-scenario-r10-b10.rds
```

## Results

| Scenario | Original fits | Bootstrap failures | Coverage | Miss below | Miss above | Median estimate/truth | Median gradient | Status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `baseline_phi1_n60_r10` | 10 / 10 | 14 / 100 | 0.32 | 34 | 0 | 2.48 | 5.53e-04 | `TARGET_FAIL` |
| `lowphi_n120_r10` | 10 / 10 | 3 / 100 | 0.00 | 50 | 0 | 8.09 | 4.16e-04 | `TARGET_FAIL` |

## Interpretation

The pilot separates the failure modes more clearly than the r2/r5
smokes:

- original optimizer failure was not the dominant issue in these two
  settings because both scenarios completed 10/10 original fits;
- bootstrap refit failure remained visible in the baseline scenario
  but dropped to 3% in the low-dispersion 120-unit scenario;
- low-dispersion 120-unit coverage was still 0.00 even with mostly
  successful bootstrap refits;
- every uncovered row missed below the interval, meaning the estimated
  `Sigma_unit_diag` remained above truth relative to the bootstrap
  interval.

This points to target calibration / link-implicit residual allocation
as the next primary diagnostic, not just a start-value or bootstrap
refit stability problem.

## Next Action

Do not scale the full 15-cell grid yet. The next M3.3a step should
inspect the `nbinom2` `Sigma_unit_diag` target construction directly:
compare latent+unique truth, fitted `extract_Sigma(level = "unit")`,
and the link-implicit residual variance augmentation trait by trait.
Only after that audit should a larger `n_reps >= 20`, `n_boot >= 20`
stress run be scheduled.
