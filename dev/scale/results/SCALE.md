# Scale-regime comparison: VA vs Laplace, n up to 5000, p up to 50

Design: family x n(500,1000,2500,5000) x p(27,50) x q=2 x seed(1:3).
Compute: Totoro. Results local (D-50).

Cells attempted: 168 rows, 48 cells.

## 0. What ran

| arm | rows | ERROR | TIMEOUT | usable Sigma |
|---|---:|---:|---:|---:|
| gllvmTMB GH-VA (H=15) | 48 | 0 | 24 | 24 |
| gllvmTMB JJ-VA | 24 | 0 | 12 | 12 |
| gllvm VA | 48 | 0 | 19 | 29 |
| gllvmTMB Laplace (Psi suppressed) | 48 | 0 | 0 | 48 |

## 1. Crossover: at what n does VA become faster than Laplace?

Median seconds by arm x n x p (pooled over family, seed):

| n | p | gtmb_gh | gtmb_jj | gllvm_va | gtmb_laplace | VA/Laplace (gh) |
|---:|---:|---:|---:|---:|---:|---:|
| 500 | 27 | 110.5 | 31.7 | 17.0 | 7.0 | 15.80 |
| 1000 | 27 | 413.2 | 199.5 | 72.9 | 13.3 | 31.02 |
| 2500 | 27 | 901.5 | 901.4 | 631.7 | 36.0 | 25.04 |
| 5000 | 27 | 901.7 | 901.6 | 900.7 | 78.8 | 11.44 |
| 500 | 50 | 163.8 | 39.9 | 26.9 | 16.6 | 9.87 |
| 1000 | 50 | 628.6 | 226.7 | 110.5 | 34.2 | 18.40 |
| 2500 | 50 | 901.5 | 901.5 | 900.8 | 87.0 | 10.36 |
| 5000 | 50 | 901.7 | 901.6 | 900.7 | 202.3 | 4.46 |

Ratio column is gtmb_gh seconds / gtmb_laplace seconds; <1 means our VA is faster.

## 2. Scaling exponents (log-log OLS slope of median seconds vs n, and vs p)

| arm | exponent vs n (p pooled) | exponent vs p (n pooled) |
|---|---:|---:|
| gllvmTMB GH-VA (H=15) | 0.83 | 0.34 |
| gllvmTMB JJ-VA | 1.39 | 0.08 |
| gllvm VA | 1.71 | 0.44 |
| gllvmTMB Laplace (Psi suppressed) | 1.01 | 1.36 |

## 3. Accuracy/reliability at scale (relative Frobenius error vs true Sigma)

| arm | n | median rel_frob | median attenuation |
|---|---:|---:|---:|
| gllvmTMB GH-VA (H=15) | 500 | 0.218 | 0.980 |
| gllvmTMB GH-VA (H=15) | 1000 | 0.157 | 1.009 |
| gllvmTMB GH-VA (H=15) | 2500 | NA | NA |
| gllvmTMB GH-VA (H=15) | 5000 | NA | NA |
| gllvmTMB JJ-VA | 500 | 0.324 | 0.859 |
| gllvmTMB JJ-VA | 1000 | 0.296 | 0.839 |
| gllvmTMB JJ-VA | 2500 | NA | NA |
| gllvmTMB JJ-VA | 5000 | NA | NA |
| gllvm VA | 500 | 0.207 | 0.951 |
| gllvm VA | 1000 | 0.170 | 0.939 |
| gllvm VA | 2500 | 0.247 | 0.799 |
| gllvm VA | 5000 | NA | NA |
| gllvmTMB Laplace (Psi suppressed) | 500 | 0.214 | 0.971 |
| gllvmTMB Laplace (Psi suppressed) | 1000 | 0.156 | 0.995 |
| gllvmTMB Laplace (Psi suppressed) | 2500 | 0.109 | 0.988 |
| gllvmTMB Laplace (Psi suppressed) | 5000 | 0.074 | 0.980 |

## 4. Raw status table

```
              
               conv0_pdHessTRUE converged failed_health_gate healthy TIMEOUT
  gllvm_va                    0        29                  0       0      19
  gtmb_gh                     0         0                 19       5      24
  gtmb_jj                     0         0                  7       5      12
  gtmb_laplace               48         0                  0       0       0
```
