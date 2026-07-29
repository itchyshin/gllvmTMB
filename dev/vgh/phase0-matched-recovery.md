# Phase 0 -- matched-data recovery: VGH vs va_r3 vs Laplace

Generated 2026-07-29.  T = 20 traits, q = d = 2, H = Q = 15, seeds = 12 per cell.
va_r3 ran with its production `n_starts = 4` health gate; VGH and Laplace are single-start.

Every arm in a cell is fitted on the SAME simulated dataset (same seed),
so all comparisons below are PAIRED.

`atten_F` = ||L_hat||_F/||L_true||_F.  `atten_tr` = trace(Sigma_hat)/trace(Sigma_true) = atten_F^2.
A value BELOW 1 means Sigma_B is UNDER-estimated (shrinkage); ABOVE 1 means INFLATED.

## Per-cell aggregates (median [IQR])

| family | n | arm | fits ok | rel. Frobenius | atten_F | atten_tr | median s | degenerate |
|---|---:|---|---:|---|---|---|---:|---:|
| binomial | 200 | vgh | 12/12 | 0.565 [0.478, 0.627] | 1.137 [1.039, 1.188] | 1.292 [1.080, 1.412] | 1.8 | 0 |
| binomial | 200 | va_r3_gh | 12/12 | 0.566 [0.479, 0.628] | 1.137 [1.040, 1.189] | 1.294 [1.081, 1.413] | 27.9 | 0 |
| binomial | 200 | va_r3_jj | 12/12 | 0.454 [0.398, 0.484] | 0.892 [0.873, 0.984] | 0.795 [0.763, 0.968] | 1.9 | 0 |
| binomial | 200 | laplace | 12/12 | 0.580 [0.525, 0.714] | 1.149 [1.066, 1.205] | 1.320 [1.136, 1.454] | 14.1 | 2 |
| binomial | 400 | vgh | 12/12 | 0.377 [0.293, 0.418] | 1.049 [1.011, 1.078] | 1.100 [1.022, 1.163] | 2.4 | 0 |
| binomial | 400 | va_r3_gh | 12/12 | 0.378 [0.293, 0.419] | 1.049 [1.011, 1.079] | 1.101 [1.022, 1.164] | 82.7 | 0 |
| binomial | 400 | va_r3_jj | 12/12 | 0.358 [0.320, 0.399] | 0.881 [0.854, 0.919] | 0.776 [0.729, 0.844] | 4.5 | 0 |
| binomial | 400 | laplace | 12/12 | 0.343 [0.277, 0.398] | 1.031 [0.973, 1.048] | 1.062 [0.948, 1.098] | 24.5 | 1 |
| binomial | 800 | vgh | 12/12 | 0.218 [0.192, 0.257] | 0.994 [0.971, 1.001] | 0.989 [0.943, 1.002] | 3.9 | 0 |
| binomial | 800 | va_r3_gh | 12/12 | 0.218 [0.192, 0.256] | 0.995 [0.972, 1.002] | 0.989 [0.944, 1.003] | 260.1 | 0 |
| binomial | 800 | va_r3_jj | 12/12 | 0.386 [0.326, 0.403] | 0.848 [0.822, 0.858] | 0.718 [0.675, 0.736] | 11.1 | 0 |
| binomial | 800 | laplace | 12/12 | 0.244 [0.195, 0.270] | 0.968 [0.936, 0.978] | 0.937 [0.875, 0.956] | 47.4 | 0 |
| poisson | 200 | vgh | 12/12 | 0.177 [0.156, 0.234] | 0.952 [0.931, 0.979] | 0.906 [0.867, 0.960] | 0.8 | 0 |
| poisson | 200 | va_r3_gh | 12/12 | 0.161 [0.134, 0.181] | 0.993 [0.976, 1.008] | 0.985 [0.953, 1.017] | 8.8 | 0 |
| poisson | 200 | laplace | 12/12 | 0.161 [0.134, 0.182] | 0.993 [0.977, 1.009] | 0.987 [0.955, 1.018] | 12.4 | 0 |
| poisson | 400 | vgh | 12/12 | 0.130 [0.117, 0.318] | 0.944 [0.850, 0.984] | 0.892 [0.722, 0.969] | 1.1 | 0 |
| poisson | 400 | va_r3_gh | 12/12 | 0.105 [0.085, 0.113] | 1.001 [0.988, 1.007] | 1.001 [0.975, 1.014] | 42.9 | 0 |
| poisson | 400 | laplace | 12/12 | 0.105 [0.085, 0.113] | 1.002 [0.988, 1.007] | 1.003 [0.976, 1.014] | 25.9 | 0 |
| poisson | 800 | vgh | 12/12 | 0.116 [0.093, 0.180] | 0.965 [0.926, 0.973] | 0.932 [0.858, 0.946] | 1.8 | 0 |
| poisson | 800 | va_r3_gh | 12/12 | 0.075 [0.063, 0.081] | 0.995 [0.983, 1.007] | 0.990 [0.966, 1.014] | 197.3 | 0 |
| poisson | 800 | laplace | 12/12 | 0.075 [0.064, 0.080] | 0.996 [0.983, 1.008] | 0.991 [0.967, 1.015] | 51.1 | 0 |

## Non-ok fits

None -- every arm returned an estimate in every cell.


## Paired comparisons (same seed, same data)

Per-seed difference `d = metric(VGH) - metric(va_r3_gh)`.  For rel. Frobenius,
d < 0 means VGH is CLOSER to the truth.  Sign test is exact binomial on sign(d).

| family | n | pairs | median d(rel.Frob) | 95% CI (Wilcoxon) | VGH better / worse | sign-test p |
|---|---:|---:|---:|---|---|---:|
| binomial | 200 | 12 | -0.0010 | [-0.0017, -0.0006] | 11 / 1 | 0.006348 |
| binomial | 400 | 12 | -0.0005 | [-0.0013, -0.0002] | 10 / 2 | 0.03857 |
| binomial | 800 | 12 | +0.0000 | [-0.0003, 0.0003] | 6 / 6 | 1 |
| poisson | 200 | 12 | +0.0085 | [0.0023, 0.2078] | 2 / 10 | 0.03857 |
| poisson | 400 | 12 | +0.0208 | [0.0035, 0.2720] | 3 / 9 | 0.146 |
| poisson | 800 | 12 | +0.0308 | [0.0075, 0.2531] | 1 / 11 | 0.006348 |

## The attenuation SIGN question

`docs/design/109-bound-tightness-vs-recovery.md` (sec. ~309-318, tagged AGENT-INFERRED)
argues the Gaussian-VA channel should make exact-GH **over-estimate** Sigma_B,
i.e. `atten_F > 1`.  Matched data, per family and n:

| family | n | arm | median atten_F | 95% CI (Wilcoxon) | # above 1 / total | sign-test p vs 1 |
|---|---:|---|---:|---|---|---:|
| binomial | 200 | vgh | 1.1366 | [1.0756, 1.1816] | 12 / 12 | 0.0004883 |
| binomial | 200 | va_r3_gh | 1.1374 | [1.0760, 1.1825] | 12 / 12 | 0.0004883 |
| binomial | 200 | va_r3_jj | 0.8917 | [0.8731, 0.9704] | 2 / 12 | 0.03857 |
| binomial | 200 | laplace | 1.1487 | [1.0728, 8.4737] | 12 / 12 | 0.0004883 |
| binomial | 400 | vgh | 1.0487 | [1.0137, 1.1043] | 10 / 12 | 0.03857 |
| binomial | 400 | va_r3_gh | 1.0493 | [1.0140, 1.1051] | 10 / 12 | 0.03857 |
| binomial | 400 | va_r3_jj | 0.8808 | [0.8541, 0.9149] | 0 / 12 | 0.0004883 |
| binomial | 400 | laplace | 1.0305 | [0.9801, 1.0758] | 7 / 12 | 0.7744 |
| binomial | 800 | vgh | 0.9943 | [0.9759, 1.0065] | 4 / 12 | 0.3877 |
| binomial | 800 | va_r3_gh | 0.9946 | [0.9763, 1.0070] | 4 / 12 | 0.3877 |
| binomial | 800 | va_r3_jj | 0.8475 | [0.8234, 0.8588] | 0 / 12 | 0.0004883 |
| binomial | 800 | laplace | 0.9680 | [0.9452, 0.9819] | 1 / 12 | 0.006348 |
| poisson | 200 | vgh | 0.9516 | [0.8583, 0.9786] | 2 / 12 | 0.03857 |
| poisson | 200 | va_r3_gh | 0.9926 | [0.9741, 1.0177] | 5 / 12 | 0.7744 |
| poisson | 200 | laplace | 0.9934 | [0.9745, 1.0181] | 5 / 12 | 0.7744 |
| poisson | 400 | vgh | 0.9444 | [0.8548, 0.9806] | 2 / 12 | 0.03857 |
| poisson | 400 | va_r3_gh | 1.0005 | [0.9817, 1.0068] | 6 / 12 | 1 |
| poisson | 400 | laplace | 1.0016 | [0.9823, 1.0073] | 6 / 12 | 1 |
| poisson | 800 | vgh | 0.9655 | [0.8629, 0.9803] | 1 / 12 | 0.006348 |
| poisson | 800 | va_r3_gh | 0.9948 | [0.9835, 1.0058] | 5 / 12 | 0.7744 |
| poisson | 800 | laplace | 0.9957 | [0.9841, 1.0063] | 6 / 12 | 1 |
