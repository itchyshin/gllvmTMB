# Temporal dep-kernel 160-series qualification: retained result

## Scope

This is the disjoint 160-series qualification specified in
`TEMPORAL-DEP-KERNEL-160-QUALIFICATION-CONTRACT.md`. It uses the frozen direct
Gaussian DGP, nine new seeds, the existing two-pass BFGS fit, and the existing
acceptance thresholds. It neither replaces the failed 80-series receipt nor
establishes general recovery, interval coverage, a solver improvement, or
release readiness.

## Execution

- Execution commit: `20a583f77f59312e8d3908c3bbacf0b2f4a1123b`
- Target: Totoro, nine workers, one BLAS/OpenMP thread per worker.
- Pre-run: seed `2609340`, phi `.6`; terminal success, two accepted passes,
  outer gradient `8.16e-10`, elapsed `34.249` seconds.
- Campaign: phi `-.4`, `0`, `.6` by seeds `2609341:2609343`.
- Retained receipts: `results/qualification-160-20260912/`.

## Frozen verdict

Every campaign cell has terminal `success`, optimiser convergence `0`, and two
accepted passes. The frozen strict gate also requires outer gradient at most
`1e-3`; Hessian status is retained and was `error` for every cell.

| phi | Strict cells | Mean abs(phi error) | Median temporal error | Kernel 1 median rel. error | Kernel 2 | Kernel 3 | Mean fixed-effect error | Verdict |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| -.4 | 3/3 | .0129 | .0404 | .1287 | .0623 | .1590 | .2433 | pass |
| 0 | 0/3 | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | fail: gradients `.00376`, `.00231`, `.00144` |
| .6 | 2/3 | .0185 | .0536 | .2832 | .0935 | .4878 | .2086 | fail: one gradient `.00113`; kernel 3 above `.35` |

The qualification is therefore **failed**. All nine receipts, including the
cells that meet the strict gate, are retained. No seed was replaced and no
threshold, DGP, optimiser setting, or parameterisation was changed.
