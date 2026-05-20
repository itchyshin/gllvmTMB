# M3.3a nbinom2 Stress Smoke

**Date**: 2026-05-19 evening MT
**Branch**: `codex/m3-3a-nbinom2-stress-2026-05-19`
**Roles**: Ada / Curie / Fisher / Grace / Rose

## Purpose

Follow the 2026-05-19 night pilot by making the `nbinom2-d1`
stress grid able to vary sample size, dispersion, latent variance,
and unique variance. This is a tiny stress smoke, not validation
evidence or a promotion run.

## Dev-Pipeline Controls Added

The M3 dev grid now accepts:

- `n_units` / CLI `--n-units`;
- `n_traits` / CLI `--n-traits`;
- `lambda_scale` / CLI `--lambda-scale`;
- `psi_scale` / CLI `--psi-scale`;
- fixed `phi` / CLI `--phi`;
- sampled `phi` distribution controls `phi_shape`, `phi_rate` /
  CLI `--phi-shape`, `--phi-rate`.

Each target row now records `n_units`, `n_traits`, `lambda_scale`,
`psi_scale`, and `truth_phi`. `m3_summarise()` also preserves a
`scenario` column when present, so repeated `rep = 1, 2, ...` labels
from multiple scenario blocks do not collapse into one summary row.

## Commands

Parser check:

```sh
Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); invisible(parse(file="dev/precompute-m3-grid.R")); cat("parse ok\n")'
```

CLI scenario-control smoke:

```sh
Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=1 --n-units=20 --n-traits=3 --phi=0.4 --lambda-scale=0.5 --psi-scale=1.5 --init-strategy=single_trait_warmup --start-method=res --start-jitter=0.2 --n-init=2 --init-jitter=0.05 --optimizer=optim --optim-method=BFGS --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-stress-smoke --out-prefix=nbinom2-phi04-lam05-psi15-n20-r1
```

Four-scenario stress smoke was run through `m3_run_grid()` directly,
with `n_reps = 2`, `n_boot = 4`, `ci_level = 0.80`,
`init_strategy = "single_trait_warmup"`, residual starts,
`n_init = 5`, BFGS, and `se = FALSE`.

Saved artifact:

```text
/tmp/gllvmtmb-m3-3a-stress-grid/nbinom2-four-scenario-smoke.rds
```

## Stress-Smoke Results

All four scenario blocks completed the original fits. The failure
signal in this tiny grid is bootstrap refit failure plus one-sided
target misses below the interval, not original optimizer failure.

| Scenario | Original fits | Bootstrap failures | Coverage | Miss below | Median estimate/truth | Status |
|---|---:|---:|---:|---:|---:|---|
| `baseline_phi1_n60` | 2 / 2 | 4 / 8 | 0.10 | 9 | 2.16 | `COMPUTE_FAIL` |
| `lowphi_n60` | 2 / 2 | 3 / 8 | 0.00 | 10 | 6.60 | `COMPUTE_FAIL` |
| `lowphi_n120` | 2 / 2 | 1 / 8 | 0.00 | 10 | 6.01 | `TARGET_FAIL` |
| `lowphi_lowlatent_highunique_n60` | 2 / 2 | 3 / 8 | 0.00 | 10 | 8.79 | `COMPUTE_FAIL` |

## Focused Follow-Up

A second local stress smoke used `n_reps = 5`, `n_boot = 6`,
`ci_level = 0.80`, and the same start/optimizer settings for two
scenarios:

| Scenario | Original fits | Bootstrap failures | Coverage | Miss below | Median estimate/truth | Status |
|---|---:|---:|---:|---:|---:|---|
| `baseline_phi1_n60_r5` | 5 / 5 | 4 / 30 | 0.12 | 22 | 3.29 | `TARGET_FAIL` |
| `lowphi_n120_r5` | 5 / 5 | 0 / 30 | 0.00 | 25 | 9.77 | `TARGET_FAIL` |

Saved artifact:

```text
/tmp/gllvmtmb-m3-3a-stress-grid/nbinom2-two-scenario-r5.rds
```

## Interpretation

Increasing from 60 to 120 units reduced bootstrap failures in this
tiny smoke, but it did not fix target coverage or the one-sided miss
pattern. Lower dispersion (`phi = 0.4`) inflated the estimate/truth
ratio, and the lower-latent / higher-unique scenario made the target
bias worse. The focused follow-up made the separation sharper:
`lowphi_n120_r5` had zero bootstrap failures but still had zero
coverage and all misses below the interval. That points toward target
calibration / link-implicit residual allocation, not only bootstrap
refit stability.

This supports the next larger pilot design:

- keep original optimizer failure separate from bootstrap refit
  failure;
- vary `phi`, `lambda_scale`, `psi_scale`, and `n_units` explicitly;
- treat link-implicit residual variance as part of the target-scale
  audit, not as an optimizer-only issue;
- do not promote `nbinom2` uncertainty claims from this smoke.

## Next Action

If the post-merge main CI from PR #208 passes, open this branch as a
small dev-pipeline PR. A later compute lane can then run a proper
`nbinom2-d1` pilot with at least `n_reps = 20` and `n_boot = 20`
before deciding whether the issue is mostly bootstrap refit stability
or target calibration.
