# M3.3a nbinom2 Night Pilot

**Date**: 2026-05-19 evening MT
**Branch**: `codex/m3-3a-fit-health-pilot-2026-05-19`
**Roles**: Ada / Curie / Fisher / Grace

## Purpose

Use the new M3.3a diagnostic schema to ask whether the early
`nbinom2` trouble looks like pure optimizer failure, bootstrap refit
failure, or target-scale bias. This is a tiny pilot, not promotion
evidence.

## Commands

Schema smoke after rebasing on merged PR #206:

```sh
Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); invisible(parse(file="dev/precompute-m3-grid.R")); cat("parse ok\n")'
```

Family smoke cells:

```sh
Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=2 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-smoke --out-prefix=gaussian-res-sefalse-n2

Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=2 --init-strategy=single_trait_warmup --start-method=res --start-jitter=0.2 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-smoke --out-prefix=nbinom2-res-sefalse-n2

Rscript --vanilla dev/precompute-m3-grid.R --full --family=mixed --d=1 --n-reps=2 --start-method=res --start-jitter=0.1 --n-init=2 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=2 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-smoke --out-prefix=mixed-res-sefalse-n2
```

`nbinom2` start comparison:

```sh
Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=5 --se=false --targets=Sigma_unit_diag --n-boot=5 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-nb5 --out-prefix=nbinom2-default-n5

Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=5 --init-strategy=single_trait_warmup --se=false --targets=Sigma_unit_diag --n-boot=5 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-nb5 --out-prefix=nbinom2-warmup-n5

Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=5 --init-strategy=single_trait_warmup --start-method=res --start-jitter=0.2 --n-init=5 --init-jitter=0.05 --se=false --targets=Sigma_unit_diag --n-boot=5 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-nb5 --out-prefix=nbinom2-warmup-res-n5

Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=5 --init-strategy=single_trait_warmup --start-method=res --start-jitter=0.2 --n-init=5 --init-jitter=0.05 --optimizer=optim --optim-method=BFGS --se=false --targets=Sigma_unit_diag --n-boot=5 --n-cores-boot=1 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-nb5 --out-prefix=nbinom2-warmup-res-bfgs-n5
```

Multicore bootstrap smoke:

```sh
Rscript --vanilla dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 --n-reps=3 --init-strategy=single_trait_warmup --start-method=res --start-jitter=0.2 --n-init=5 --init-jitter=0.05 --optimizer=optim --optim-method=BFGS --se=false --targets=Sigma_unit_diag --n-boot=6 --n-cores-boot=2 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-3a-night-nb-multicore --out-prefix=nbinom2-warmup-res-bfgs-cores2-n3
```

## Results

The 2-replicate smoke confirmed that the schema records start method,
restart count, skipped-SE status, bootstrap failures, and bootstrap
core count. Gaussian and mixed-family completed both original fits.
The `nbinom2` smoke had one original fit failure and one bootstrap
refit failure.

| Config | Original fits | Bootstrap refits | Median gradient | Coverage | Miss below | Median estimate/truth |
|---|---:|---:|---:|---:|---:|---:|
| default | 4 / 5 completed | 4 / 20 failed | 8.25e-05 | 0.10 | 18 | 3.54 |
| single-trait warmup | 4 / 5 completed | 3 / 20 failed | 3.50e-05 | 0.10 | 18 | 3.54 |
| warmup + residual multistart | 5 / 5 completed | 5 / 25 failed | 2.25e-04 | 0.08 | 23 | 2.69 |
| warmup + residual multistart + BFGS | 5 / 5 completed | 3 / 25 failed | 1.17e-03 | 0.20 | 20 | 2.61 |
| warmup + residual multistart + BFGS, `n_cores_boot = 2` | 3 / 3 completed | 2 / 18 failed | 4.77e-03 | 0.33 | 10 | 2.21 |

Interpretation:

- Residual multistart removed original optimizer failures in this toy
  grid.
- BFGS lowered bootstrap refit failures in this toy grid but had
  larger gradients than `nlminb`.
- Coverage remains poor and mostly misses below the interval, with
  estimated `Sigma_unit_diag` often above truth.
- The problem is therefore not only "can the original model fit?" It
  also looks like target calibration / link-implicit residual
  allocation / bootstrap refit stability.

## Next Action

The next `nbinom2` lane should keep residual multistart and BFGS in
the candidate grid, but it must also vary dispersion, true variance,
and sample size. The pilot should classify failure separately as
original optimizer failure, bootstrap refit failure, Hessian / SE
failure, and target-scale bias.

Do not promote any `nbinom2` default-policy claim from this toy run.
