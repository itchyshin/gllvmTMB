# #847 tau pilot tail rescore

This is a diagnostic rescore of the retained 12,000-fit campaign. It does
**not** validate an adaptive penalty: fresh paired refits are required.
The scale source is fixed to unpenalised multi-start AGHQ (`arm = aghq`),
never plain Laplace.

| n | sigma_lambda | N | runaway | tau median | tau p95 | tau p99 | tau max | ratio median | cap 4 nonrun clipped | cap 5 | cap 6 | cap 8 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 1 | 400 | 0.403 | 1.758 | 3.642 | 13.839 | 19.153 | 1.768 | 0.000 | 0.000 | 0.000 | 0.000 |
| 400 | 1 | 400 | 0.107 | 1.225 | 2.411 | 3.292 | 13.870 | 1.217 | 0.000 | 0.000 | 0.000 | 0.000 |
| 1600 | 1 | 400 | 0.010 | 1.040 | 1.505 | 1.647 | 2.012 | 1.055 | 0.000 | 0.000 | 0.000 | 0.000 |
| 100 | 3 | 400 | 0.110 | 3.546 | 10.773 | 20.967 | 56.197 | 1.188 | 0.272 | 0.067 | 0.011 | 0.000 |
| 400 | 3 | 400 | 0.010 | 3.208 | 5.031 | 7.596 | 19.294 | 1.061 | 0.189 | 0.043 | 0.010 | 0.003 |
| 1600 | 3 | 400 | 0.007 | 2.903 | 4.177 | 5.400 | 15.721 | 0.994 | 0.060 | 0.005 | 0.003 | 0.000 |

## Decision boundary

The pilot tail is unsafe without a cap: across all 2,400 reference fits,
`tau_est` p99 is 13.452 and the maximum is 56.197.
Cap 4 is excluded before fresh fitting because it clips more than 5% of
truth-classified non-runaway sigma_lambda = 3 pilots in the stored data.
Caps 5, 6, and 8 proceed as candidates, with uncapped retained only as an
unsafe control. Selection requires fresh paired penalised refits and a
disjoint-seed confirmation; this file chooses no cap.
