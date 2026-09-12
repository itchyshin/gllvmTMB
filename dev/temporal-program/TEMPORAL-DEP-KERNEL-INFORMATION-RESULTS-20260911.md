# Retained dependent temporal--kernel information-size results

## Execution

The approved six-cell Totoro diagnostic completed on 2026-09-11 from exact
source commit `ebfa86979f004ffada55e21b52eaa68d65d9c84c`. The launcher used
six single-thread workers and retained one RDS receipt for every frozen
`(n_series, seed)` cell. The six receipts are copied verbatim under
`dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/`.
Their remote originals remain at
`/home/snakagaw/gllvmtmb-temporal-information-ebfa86979f00/dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/`.

Every cell returned terminal success, optimizer convergence code zero, and an
accepted second BFGS pass. The largest retained outer gradient was
`3.986576e-04` for 80 series and `2.280248e-04` for 160 series.

## Results

| Series count | Median temporal covariance error | Median kernel-1 error | Median kernel-2 error | Median kernel-3 error | Median fitted phi |
|---:|---:|---:|---:|---:|---:|
| 80 | 0.063069 | 0.395123 | 0.361747 | 0.095945 | 0.586451 |
| 160 | 0.047812 | 0.198250 | 0.074060 | 0.129623 | 0.581881 |

Doubling the number of independently observed series reduced the median error
for the temporal covariance and the first two kernel components in this direct
DGP. The third kernel component did not improve monotonically. This supports
a limited-information explanation for the two failed 80-series components; it
does not identify a universal cause.

## Boundary

This is an information diagnostic, not a replacement recovery experiment. It
does not modify the frozen 80-series receipt, threshold, model, simulator,
parameter map, optimizer, or source-pair admission. It establishes no new
recovery, coverage, solver, release, or cross-platform claim. Any proposed
160-series recovery campaign needs its own frozen contract and compute
authorization.
