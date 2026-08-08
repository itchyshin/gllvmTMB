# ISDM Design-108-style mixed-curvature gate: SMOKE findings

Harness: `dev/isdm-gate-harness.R`. Smoke runner: `dev/isdm-gate-smoke.R`.
Package: gllvmTMB **0.6.0** (installed, `library(gllvmTMB)`). R 4.6.0.
This is a SMOKE test only -- NOT the full grid.

## Planted truth

```
Lambda_true: sp1=0.150, sp2=0.900, sp3=0.600, sp4=-0.700, sp5=0.300, sp6=-0.450 
psi_true:    sp1=0.300, sp2=0.500, sp3=0.400, sp4=0.600, sp5=0.350, sp6=0.450 
```

## Design

T = 6 species, d = 1 latent factor. Each (cell, species) contributes
two rows (block1, block2) sharing the same latent score u_i and the
same loading lambda_j. Cells: PP (both blocks Poisson-log), BB (both
blocks Bernoulli-cloglog), PB (block1 Poisson-log, block2
Bernoulli-cloglog -- the gate cell). Two arms: U1 (`latent(unique =
TRUE)`, Sigma = Lambda Lambda' + diag(psi), the package's real
estimand) and U0 (`unique = FALSE`, Sigma = Lambda Lambda' only, all
three cells strictly comparable).

## Smoke results (n=200, prevalence=0.3, seed=1)

```
  cell n_units prevalence seed arm elapsed_sec fit_error convergence pdHess
1   PB     200        0.3    1  U1   1.1506250      <NA>           0   TRUE
2   PB     200        0.3    1  U0   0.1985881      <NA>           0   TRUE
3   PP     200        0.3    1  U1   0.2733531      <NA>           0   TRUE
4   BB     200        0.3    1  U1   0.2289190      <NA>           0   TRUE
5   PP     200        0.3    1  U0   0.1219711      <NA>           0   TRUE
6   BB     200        0.3    1  U0   0.2054191      <NA>           0   TRUE
7   PB    1600        0.3    1  U1   3.0928349      <NA>           0   TRUE
  diag_B_skip off_diag_rmse off_diag_cor diag_rmse lambda_cor  comm_rmse
1           0    0.17648337    0.8629441 0.1293597  0.9630066 0.19029610
2           0    0.91616625    0.3926914 0.3409688  0.9713654         NA
3           0    0.15482154    0.9210016 0.1883078  0.9707564 0.15992275
4           6    0.69398392    0.9244728 0.5226725  0.9558059 0.67074548
5           0    0.69398393    0.9244728 0.4441167  0.9524754         NA
6           0    0.69398393    0.9244728 0.5226725  0.9558059         NA
7           0    0.07043898    0.9790547 0.1237093  0.9904567 0.06976763
   comm_cor n_heywood_psi n_heywood_loading
1 0.8429038             1                 0
2        NA            NA                 0
3 0.8204777             0                 0
4 0.7003401             6                 0
5        NA            NA                 0
6        NA            NA                 0
7 0.9362398             0                 0
```

## Guard-inspection past the fit (PB, U1, n=200, seed=1)

```
convergence: 0  pdHess: TRUE 
diag_B_skip (per-species pin flag): 0,0,0,0,0,0 
Lambda_hat:
             LV1
sp1  0.221217364
sp2  1.155975956
sp3  0.562786348
sp4 -0.636534173
sp5 -0.003447171
sp6 -0.528541760
any NA in Lambda_hat: FALSE 
psi_hat: 0.3738, 5.305e-07, 0.6514, 0.67, 0.5731, 0.5417 
any NA in psi_hat: FALSE 
```

## BB psi-pinning check (arm=U1, n=200, seed=1)

```
diag_B_skip (1 = psi pinned to 1e-6): 1,1,1,1,1,1 
psi_hat: 1e-12, 1e-12, 1e-12, 1e-12, 1e-12, 1e-12 
```

## Timings

```
  pb_u1_n200       1.185 s
  pb_u0_n200       0.201 s
  pp_u1_n200       0.274 s
  bb_u1_n200       0.230 s
  pp_u0_n200       0.123 s
  bb_u0_n200       0.207 s
  pb_u1_n1600      3.094 s

n-scaling exponent (PB, n=200 -> n=1600): k = 0.461 (t ~ n^k)
```

## Full-grid projection

```
Full grid: 12000 fits (3 cells x 5 n x 4 prevalences x 100 seeds x 2 arms)
Projected total core-hours:   2.86
Estimated wall-clock at 120 cores: 0.02 hours (1.4 minutes)
Estimated wall-clock at 384 cores: 0.01 hours (0.4 minutes)
```

The n-scaling exponent (k = 0.461) is extrapolated from a SINGLE pair of
points (n=200, n=1600, one seed each) as instructed -- treat it as a rough
sizing number, not a calibrated scaling law. Per-cell base times also come
from single fits, not repeated seeds.

## Two findings surfaced during smoke, not in the original spec

**1. The BB psi-pinning trap does not just push psi toward its floor -- it
maps `theta_diag_B` (and the matching `s_B` row) OFF entirely.** Verified
directly: BB arm=U1's `Sigma`/`R` are numerically identical (to ~7 significant
digits, i.e. optimizer-path noise only) to BB arm=U0's. This means **the
U1-vs-U0 arm distinction is not just "not strictly comparable" for BB, it is
literally the SAME fitted model** -- U1 collapses onto U0 for this cell type.
The two BB rows in the full-grid results table will always agree up to
optimizer noise; running both arms for BB is not wasted compute (it is a
useful invariant check) but it will never show a U1-vs-U0 contrast for BB.

**2. Under arm U0 (`unique = FALSE`, i.e. Sigma = Lambda Lambda' with d = 1),
the correlation matrix R is ALWAYS exactly +-1 in every off-diagonal cell,
regardless of fit quality.** This is a mathematical property of a rank-1
covariance matrix (R_ij = sign(lambda_i) x sign(lambda_j)), not a harness
defect -- confirmed by direct inspection of `Sig$R` for PP/BB/PB, all-+-1.
Consequently, **`off_diag_rmse` / `off_diag_cor` under U0 measure ONLY sign
(topology) recovery of Lambda, not correlation-magnitude accuracy** -- the
metric is coarse/binary in that arm. For U0, `lambda_cor` and `diag_rmse` are
the informative recovery metrics; `off_diag_rmse`/`off_diag_cor` remain useful
under U0 only as a sign-agreement check (illustrated in the smoke: PB/U0's
off_diag_rmse of 0.916, worse than PP/BB/U0's 0.694, is fully explained by
sp5's estimated loading flipping sign, -0.022 vs planted +0.30 -- a small
loading close to zero under the harder mixed-family cell). This caveat should
be carried into the full-grid report so the U0 arm's off-diagonal numbers are
not misread as continuous correlation-recovery error.
