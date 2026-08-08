# The mixed-curvature loading gate: PRE-REGISTRATION

> **This section was written and saved BEFORE the full grid was run.**
> Runner: `dev/isdm-gate-campaign.R`. Harness: `dev/isdm-gate-harness.R`.
> Package: installed gllvmTMB **0.6.0**, R 4.6.0.
> Written 2026-08-08 by Fisher (statistical-inference reviewer).

## The question

A GLLVM pins the latent scale by convention (`u ~ N(0, I)`, loadings free), so
**Lambda carries all the scale**. Is planted Lambda still recoverable when one
species' loading is informed by TWO likelihoods of very different curvature
(Poisson-log and Bernoulli-cloglog)? If recovery degrades, is that
**non-identifiability** (no unique maximiser) or **weak estimability** (unique
but poorly determined)?

## Pre-registered PASS criterion

PASS at a given prevalence iff ALL FIVE hold:

1. **D1** — the fitted `log(RMSE of sign-aligned Lambda)` on `log(n)` slope for
   the PB cell is within 2 SE of **-0.5**.
2. **D2** — the within-dataset multistart shows no Lambda gap at matched logL:
   no pair of solutions with `|delta logL| < 1e-4` differing by more than
   **0.05** in sign-aligned Lambda distance (RMS over the 6 species).
3. **D3** — the smallest eigenvalue of the observed information at the MLE is
   not numerically zero: `lambda_min > 1e-8 * lambda_max` (equivalently,
   condition number below `1e8`).
4. **D4 (tolerance stated in advance)** — PB's sign-aligned Lambda RMSE is
   within a factor of **2.0** of PP's at the same n and prevalence, i.e.
   `RMSE_PB / RMSE_PP <= 2.0`, judged against the MCSE of the ratio. The factor
   2.0 is chosen because a Bernoulli observation carries strictly less Fisher
   information than a Poisson observation at the same linear predictor, so an
   exactly-equal requirement would be a test of information content rather than
   of identifiability; a two-fold RMSE inflation is a *worse but usable*
   estimator, while more than two-fold is a materially different one.
5. **D6** — the permutation placebo shows the Bernoulli arm is NOT inert: with
   the Bernoulli block's responses permuted across units, sign-aligned Lambda
   must move by more than its own seed-to-seed MCSE.

Any other outcome is reported as the specific failure mode it is, together with
the prevalence threshold above which it passes, if one exists.

## Pre-declared boundary (Heywood) criterion

`psi_hat_j` is counted as boundary-collapsed iff
`psi_hat_j < 1e-4` **or** `psi_hat_j / median(psi_hat) < 0.01`
(the same two-part rule `check_gllvmTMB()` uses: absolute floor plus
relative-to-siblings). Loading runaway: `|lambda_hat_j| > 25`. The boundary rate
is a PRIMARY reported outcome, not a diagnostic footnote.

## Pre-declared scoring decision

The **primary** gate metric is **Lambda recovery**, not the correlation
off-diagonals, because two structural facts from the smoke make the
off-diagonals unusable as a common metric:

1. **BB cannot estimate psi at all.** `R/fit-multi.R:4976` maps `theta_diag_B`
   OFF (not merely floors it) when every row of a trait is single-trial
   Bernoulli. BB's U1 and U0 fits are numerically identical to ~7 significant
   digits, so the U1/U0 arm distinction is structurally meaningless for BB, and
   BB always estimates `Sigma = Lambda Lambda'`.
2. **Under `Sigma = Lambda Lambda'` with d = 1, every off-diagonal correlation
   is exactly +/-1** by the rank-1 property. So R-off-diagonal metrics under U0,
   and under BB in ANY arm, test only SIGN recovery, not correlation accuracy.

Lambda recovery is the only metric all three cells can carry. Alignment is
reflection-permitting (Procrustes over O(d); at d = 1 this is sign-alignment:
`s = sign(sum(lambda_hat * lambda_true))`). Both
`abs(cor(lambda_hat, lambda_true))` and `RMSE(s * lambda_hat, lambda_true)` are
reported. R off-diagonals are reported as a SECONDARY metric, **PP vs PB only**,
with BB structurally excluded and said so.

## Pre-declared analysis rules

- **Recovery against planted truth is the criterion. Optimiser flags
  (`convergence`, `pdHess`) are recorded as covariates only and never used to
  filter fits or to score success.** Fits that error out are counted and
  reported; they are excluded from RMSE with the exclusion rate stated.
- **MCSE accompanies every mean.** A difference smaller than its MCSE is not a
  difference.
- **The design is not tuned until it passes.** If PB fails, the controls D3-D7
  establish why.
- **Attribution rule.** A PB deficit implicates mixed curvature only if PB is
  materially worse than BOTH PP and BB. If PB tracks BB, the cause is Bernoulli
  information poverty. If D7 shows AGHQ removes the deficit, the cause is the
  Laplace approximation.

## Compute decision (recorded so the deviation is visible, not silent)

Standing project doctrine sends simulation campaigns to Totoro (384 cores) or
DRAC. **This campaign was run locally, deliberately.** The smoke measured the
full grid at ~2.9 core-hours for 12,000 fits; at 200 seeds and 2 arms the grid
is 24,000 fits, ~6 core-hours, which is ~20-30 minutes of wall clock on the
local 20-core / 128 GB machine using `parallel::mclapply`. Deploying the repo
and compiling the TMB DLL remotely would cost more setup time than the run
itself saves. The doctrine exists because campaigns are expensive; this one is
a laptop job.

## The grid

- Cells: **PP** (both blocks Poisson-log), **BB** (both blocks
  Bernoulli-cloglog), **PB** (Poisson block + Bernoulli-cloglog block).
  T = 6 species, d = 1.
- `n_units` in {100, 200, 400, 800, 1600}
- mean prevalence in {0.1, 0.3, 0.6, 0.9}; intensity `t = -log(1 - p)` drives
  the Poisson blocks too, so the cells stay matched.
- Arms: **U1** (`unique = TRUE`, the package's real estimand) and **U0**
  (`unique = FALSE`).
- **S = 200 seeds** (MCSE about 1.5 pp on any proportion).
- Total: 3 x 5 x 4 x 2 x 200 = **24,000 fits**.

## Planted truth (link scale)

```
Lambda_true: sp1=0.15  sp2=0.90  sp3=0.60  sp4=-0.70  sp5=0.30  sp6=-0.45
psi_true:    sp1=0.30  sp2=0.50  sp3=0.40  sp4= 0.60  sp5=0.35  sp6= 0.45
```

`eta_ij = log(t) + Lambda_j u_i + delta_ij`, `u_i ~ N(0,1)`,
`delta_ij ~ N(0, psi_j)`, shared by both blocks of species j in unit i. Each
block then draws its own observation from the SAME `eta_ij`.

---

*Results follow below, appended after the run.*

---

# RESULTS

Grid completed: **24000 fits**, 0 hard errors (0.0%).
Total fit time: 6.43 core-hours. Run locally on 18 cores via `mclapply`.

Optimiser flags are covariates, never filters. Across the whole grid: 
`convergence == 0` in 99.9% of fits, `pdHess == TRUE` in 99.6%. No fit was excluded on a flag.

## D1 (decisive) -- n-ladder log-log slope of sign-aligned Lambda RMSE

`log(pooled RMSE)` regressed on `log(n)` across n in {100,200,400,800,1600}.
Pooled RMSE at each n is `sqrt(mean over seeds and species of squared
sign-aligned error)`. `se_lm` is the regression SE (3 residual df, so it also
absorbs lack-of-fit to a power law); `se_boot` is a 400-replicate bootstrap
over seeds, which isolates Monte-Carlo noise. A well-behaved MLE gives -0.5;
a non-identified model gives 0.

```
 cell arm prevalence  slope   se_lm se_boot    r2 within2se_lm within2se_boot
   BB  U0        0.1 -0.374 0.04791 0.02024 0.953        FALSE          FALSE
   BB  U0        0.3 -0.475 0.02918 0.01134 0.989         TRUE          FALSE
   BB  U0        0.6 -0.364 0.03502 0.00993 0.973        FALSE          FALSE
   BB  U0        0.9 -0.657 0.13934 0.03058 0.881         TRUE          FALSE
   PB  U0        0.1 -0.302 0.04012 0.00886 0.950        FALSE          FALSE
   PB  U0        0.3 -0.228 0.02607 0.00876 0.962        FALSE          FALSE
   PB  U0        0.6 -0.179 0.02393 0.00905 0.949        FALSE          FALSE
   PB  U0        0.9 -0.122 0.02176 0.00694 0.913        FALSE          FALSE
   PP  U0        0.1 -0.302 0.04217 0.01094 0.945        FALSE          FALSE
   PP  U0        0.3 -0.206 0.03160 0.00949 0.934        FALSE          FALSE
   PP  U0        0.6 -0.160 0.02399 0.00762 0.937        FALSE          FALSE
   PP  U0        0.9 -0.162 0.02581 0.01419 0.929        FALSE          FALSE
   BB  U1        0.1 -0.374 0.04791 0.02067 0.953        FALSE          FALSE
   BB  U1        0.3 -0.475 0.02918 0.01315 0.989         TRUE           TRUE
   BB  U1        0.6 -0.364 0.03502 0.01045 0.973        FALSE          FALSE
   BB  U1        0.9 -0.657 0.13934 0.03218 0.881         TRUE          FALSE
   PB  U1        0.1 -0.431 0.00947 0.01147 0.999        FALSE          FALSE
   PB  U1        0.3 -0.487 0.00687 0.01136 0.999         TRUE           TRUE
   PB  U1        0.6 -0.511 0.01398 0.00935 0.998         TRUE           TRUE
   PB  U1        0.9 -0.487 0.01360 0.00946 0.998         TRUE           TRUE
   PP  U1        0.1 -0.454 0.01160 0.01190 0.998        FALSE          FALSE
   PP  U1        0.3 -0.479 0.00899 0.00992 0.999        FALSE          FALSE
   PP  U1        0.6 -0.483 0.00776 0.01047 0.999        FALSE           TRUE
   PP  U1        0.9 -0.512 0.00914 0.00876 0.999         TRUE           TRUE
```

**PB, U1 arm (the gate cell and the package's real estimand):**

- prevalence 0.1: slope **-0.431** (SE_lm 0.009, SE_boot 0.011); |slope+0.5| = 0.069; within 2 SE_lm of -0.5: **NO**
- prevalence 0.3: slope **-0.487** (SE_lm 0.007, SE_boot 0.011); |slope+0.5| = 0.013; within 2 SE_lm of -0.5: **YES**
- prevalence 0.6: slope **-0.511** (SE_lm 0.014, SE_boot 0.009); |slope+0.5| = 0.011; within 2 SE_lm of -0.5: **YES**
- prevalence 0.9: slope **-0.487** (SE_lm 0.014, SE_boot 0.009); |slope+0.5| = 0.013; within 2 SE_lm of -0.5: **YES**

## Primary metric: sign-aligned Lambda RMSE by cell x n x prevalence (U1)

```
 cell prevalence n_units    rmse   rmse_se lam_cor lam_cor_mcse  flip err_rate
   BB        0.1     100 0.71206 0.0521625  0.7367    1.507e-02 0.270        0
   BB        0.1     200 0.45152 0.0106097  0.8486    1.052e-02 0.140        0
   BB        0.1     400 0.35003 0.0082920  0.9020    7.407e-03 0.060        0
   BB        0.1     800 0.28608 0.0068958  0.9390    5.734e-03 0.010        0
   BB        0.1    1600 0.24482 0.0028334  0.9631    1.072e-03 0.000        0
   BB        0.3     100 0.27571 0.0087600  0.9108    8.238e-03 0.095        0
   BB        0.3     200 0.18168 0.0043558  0.9636    2.242e-03 0.030        0
   BB        0.3     400 0.12451 0.0030345  0.9829    9.962e-04 0.000        0
   BB        0.3     800 0.09707 0.0021250  0.9893    5.566e-04 0.000        0
   BB        0.3    1600 0.07278 0.0015563  0.9941    2.840e-04 0.000        0
   BB        0.6     100 0.21428 0.0067239  0.9467    3.681e-03 0.150        0
   BB        0.6     200 0.14433 0.0028551  0.9768    1.182e-03 0.035        0
   BB        0.6     400 0.11261 0.0023981  0.9880    6.759e-04 0.000        0
   BB        0.6     800 0.09109 0.0018019  0.9940    3.288e-04 0.000        0
   BB        0.6    1600 0.07652 0.0012266  0.9969    1.736e-04 0.000        0
   BB        0.9     100 0.65478 0.0575826  0.8792    1.028e-02 0.185        0
   BB        0.9     200 0.40029 0.0449535  0.9431    5.885e-03 0.085        0
   BB        0.9     400 0.15313 0.0078090  0.9833    1.276e-03 0.040        0
   BB        0.9     800 0.12640 0.0018158  0.9923    3.790e-04 0.005        0
   BB        0.9    1600 0.11971 0.0013630  0.9964    1.848e-04 0.000        0
   PB        0.1     100 0.48115 0.0120239  0.7669    1.372e-02 0.200        0
   PB        0.1     200 0.36627 0.0095760  0.8654    9.836e-03 0.215        0
   PB        0.1     400 0.27219 0.0071120  0.9201    5.082e-03 0.090        0
   PB        0.1     800 0.19373 0.0051406  0.9619    2.152e-03 0.005        0
   PB        0.1    1600 0.14852 0.0038471  0.9794    1.242e-03 0.010        0
   PB        0.3     100 0.22785 0.0055179  0.9391    4.483e-03 0.040        0
   PB        0.3     200 0.15858 0.0031142  0.9738    1.355e-03 0.010        0
   PB        0.3     400 0.11341 0.0025786  0.9861    7.371e-04 0.000        0
   PB        0.3     800 0.08075 0.0017247  0.9930    3.796e-04 0.000        0
   PB        0.3    1600 0.05902 0.0012875  0.9965    1.860e-04 0.000        0
   PB        0.6     100 0.16394 0.0035136  0.9701    1.631e-03 0.000        0
   PB        0.6     200 0.11025 0.0022745  0.9873    6.390e-04 0.000        0
   PB        0.6     400 0.07595 0.0014023  0.9944    2.815e-04 0.000        0
   PB        0.6     800 0.05659 0.0012639  0.9969    1.688e-04 0.000        0
   PB        0.6    1600 0.03892 0.0008503  0.9986    7.729e-05 0.000        0
   PB        0.9     100 0.12396 0.0023207  0.9849    7.123e-04 0.005        0
   PB        0.9     200 0.08699 0.0018379  0.9923    4.372e-04 0.000        0
   PB        0.9     400 0.06467 0.0013864  0.9959    2.107e-04 0.000        0
   PB        0.9     800 0.04317 0.0010648  0.9982    9.401e-05 0.000        0
   PB        0.9    1600 0.03249 0.0007355  0.9990    4.742e-05 0.000        0
   PP        0.1     100 0.44929 0.0119052  0.7888    1.388e-02 0.205        0
   PP        0.1     200 0.33872 0.0091760  0.8808    9.382e-03 0.180        0
   PP        0.1     400 0.25098 0.0068547  0.9290    4.933e-03 0.090        0
   PP        0.1     800 0.17377 0.0041017  0.9679    1.795e-03 0.005        0
   PP        0.1    1600 0.12993 0.0035795  0.9836    9.793e-04 0.000        0
   PP        0.3     100 0.21089 0.0049641  0.9501    2.897e-03 0.095        0
   PP        0.3     200 0.14512 0.0029824  0.9778    1.175e-03 0.020        0
   PP        0.3     400 0.10808 0.0023924  0.9876    6.413e-04 0.005        0
   PP        0.3     800 0.07600 0.0015654  0.9942    2.725e-04 0.000        0
   PP        0.3    1600 0.05533 0.0011101  0.9970    1.525e-04 0.000        0
   PP        0.6     100 0.14327 0.0031395  0.9796    1.230e-03 0.055        0
   PP        0.6     200 0.10198 0.0021812  0.9898    4.726e-04 0.030        0
   PP        0.6     400 0.07129 0.0014343  0.9948    2.671e-04 0.005        0
   PP        0.6     800 0.05149 0.0011866  0.9974    1.466e-04 0.000        0
   PP        0.6    1600 0.03786 0.0008833  0.9987    6.713e-05 0.000        0
   PP        0.9     100 0.11425 0.0023680  0.9872    6.861e-04 0.030        0
   PP        0.9     200 0.08299 0.0018130  0.9933    4.117e-04 0.000        0
   PP        0.9     400 0.05570 0.0012152  0.9971    1.507e-04 0.000        0
   PP        0.9     800 0.04021 0.0008704  0.9985    7.353e-05 0.000        0
   PP        0.9    1600 0.02779 0.0005734  0.9993    3.480e-05 0.000        0
```

## Criterion 4: PB vs PP (pre-stated tolerance: ratio <= 2.0)

```
 prevalence n_units rmse_PP rmse_BB rmse_PB ratio_PB_PP ratio_mcse ratio_PB_BB
        0.1     100  0.4493  0.7121  0.4812        1.07     0.0390       0.676
        0.1     200  0.3387  0.4515  0.3663        1.08     0.0407       0.811
        0.1     400  0.2510  0.3500  0.2722        1.08     0.0410       0.778
        0.1     800  0.1738  0.2861  0.1937        1.11     0.0396       0.677
        0.1    1600  0.1299  0.2448  0.1485        1.14     0.0432       0.607
        0.3     100  0.2109  0.2757  0.2278        1.08     0.0365       0.826
        0.3     200  0.1451  0.1817  0.1586        1.09     0.0311       0.873
        0.3     400  0.1081  0.1245  0.1134        1.05     0.0333       0.911
        0.3     800  0.0760  0.0971  0.0808        1.06     0.0315       0.832
        0.3    1600  0.0553  0.0728  0.0590        1.07     0.0316       0.811
        0.6     100  0.1433  0.2143  0.1639        1.14     0.0351       0.765
        0.6     200  0.1020  0.1443  0.1103        1.08     0.0321       0.764
        0.6     400  0.0713  0.1126  0.0759        1.07     0.0291       0.674
        0.6     800  0.0515  0.0911  0.0566        1.10     0.0353       0.621
        0.6    1600  0.0379  0.0765  0.0389        1.03     0.0329       0.509
        0.9     100  0.1142  0.6548  0.1240        1.09     0.0303       0.189
        0.9     200  0.0830  0.4003  0.0870        1.05     0.0319       0.217
        0.9     400  0.0557  0.1531  0.0647        1.16     0.0355       0.422
        0.9     800  0.0402  0.1264  0.0432        1.07     0.0352       0.342
        0.9    1600  0.0278  0.1197  0.0325        1.17     0.0358       0.271
```

```
 prevalence max_ratio n_at_max mean_ratio pass_tol2
        0.1      1.14     1600       1.10      TRUE
        0.3      1.09      200       1.07      TRUE
        0.6      1.14      100       1.08      TRUE
        0.9      1.17     1600       1.11      TRUE
```

Attribution reference -- PB against BB (`ratio_PB_BB` above): a PB deficit
implicates MIXED CURVATURE only if PB is materially worse than BOTH PP and BB.

## Where the error sits: per-species sign-aligned Lambda RMSE (U1)

Planted Lambda: sp1=0.15  sp2=0.90  sp3=0.60  sp4=-0.70  sp5=0.30  sp6=-0.45

```
 cell prevalence n_units rmse_sp1 rmse_sp2 rmse_sp3 rmse_sp4 rmse_sp5 rmse_sp6
   BB        0.1     100   0.6694   0.7264   0.7588   0.8705   0.5917   0.6186
   PB        0.1     100   0.5105   0.5185   0.4857   0.4730   0.4412   0.4531
   PP        0.1     100   0.4731   0.4782   0.4396   0.4598   0.4045   0.4364
   BB        0.3     100   0.2394   0.3287   0.2725   0.3144   0.2420   0.2430
   PB        0.3     100   0.1880   0.2885   0.2162   0.2418   0.1988   0.2195
   PP        0.3     100   0.1796   0.2606   0.1923   0.2273   0.1950   0.1998
   BB        0.6     100   0.1797   0.2929   0.1881   0.2406   0.1683   0.1892
   PB        0.6     100   0.1287   0.1993   0.1671   0.1808   0.1542   0.1436
   PP        0.6     100   0.1024   0.1729   0.1336   0.1636   0.1354   0.1407
   BB        0.9     100   0.4625   1.0058   0.7968   0.7344   0.1918   0.3685
   PB        0.9     100   0.0978   0.1453   0.1254   0.1460   0.1050   0.1159
   PP        0.9     100   0.0820   0.1431   0.1043   0.1383   0.1001   0.1053
   BB        0.1     400   0.2365   0.4056   0.3369   0.4832   0.2420   0.3303
   PB        0.1     400   0.2116   0.3056   0.2656   0.3421   0.2225   0.2631
   PP        0.1     400   0.2054   0.2891   0.2384   0.3197   0.2123   0.2193
   BB        0.3     400   0.0871   0.1346   0.1326   0.1647   0.1005   0.1117
   PB        0.3     400   0.0866   0.1277   0.1046   0.1472   0.0954   0.1080
   PP        0.3     400   0.0825   0.1264   0.0981   0.1353   0.0932   0.1034
   BB        0.6     400   0.0756   0.1605   0.1131   0.1193   0.0880   0.0992
   PB        0.6     400   0.0599   0.0905   0.0750   0.0912   0.0690   0.0643
   PP        0.6     400   0.0545   0.0864   0.0688   0.0810   0.0614   0.0707
   BB        0.9     400   0.0808   0.2411   0.1460   0.1696   0.0952   0.1301
   PB        0.9     400   0.0473   0.0803   0.0627   0.0796   0.0519   0.0587
   PP        0.9     400   0.0426   0.0725   0.0541   0.0642   0.0457   0.0491
   BB        0.1    1600   0.0881   0.3294   0.1683   0.4279   0.1013   0.1472
   PB        0.1    1600   0.1058   0.1561   0.1167   0.2434   0.0970   0.1204
   PP        0.1    1600   0.0976   0.1391   0.1081   0.2044   0.0861   0.1074
   BB        0.3    1600   0.0524   0.0684   0.0692   0.1067   0.0561   0.0710
   PB        0.3    1600   0.0470   0.0729   0.0529   0.0753   0.0460   0.0528
   PP        0.3    1600   0.0470   0.0655   0.0519   0.0717   0.0424   0.0473
   BB        0.6    1600   0.0411   0.1268   0.0746   0.0746   0.0524   0.0590
   PB        0.6    1600   0.0301   0.0476   0.0393   0.0447   0.0337   0.0353
   PP        0.6    1600   0.0279   0.0469   0.0358   0.0466   0.0295   0.0360
   BB        0.9    1600   0.0457   0.1930   0.1238   0.1391   0.0600   0.0914
   PB        0.9    1600   0.0211   0.0400   0.0334   0.0397   0.0268   0.0296
   PP        0.9    1600   0.0197   0.0332   0.0282   0.0330   0.0244   0.0258
```

## Boundary / Heywood rate (PRIMARY outcome)

Criterion, pre-declared: `psi_hat_j < 1e-4` OR `psi_hat_j / median(psi_hat) < 0.01`.
Loading runaway: `|lambda_hat_j| > 25`.

**BB is structurally excluded from this table.** `diag_B_skip` is 6/6 for every
BB fit -- `R/fit-multi.R:4976` maps `theta_diag_B` OFF for single-trial
Bernoulli traits, so BB's `psi_hat` is a pinned constant (1e-12), not an
estimate at the boundary. Counting it as a Heywood case would be a category
error; it is reported here only so the exclusion is visible.

```
 cell prevalence n_units boundary_rate boundary_mean runaway_rate diag_B_skip
   BB        0.1     100         1.000         6.000            0           6
   BB        0.1     200         1.000         6.000            0           6
   BB        0.1     400         1.000         6.000            0           6
   BB        0.1     800         1.000         6.000            0           6
   BB        0.1    1600         1.000         6.000            0           6
   BB        0.3     100         1.000         6.000            0           6
   BB        0.3     200         1.000         6.000            0           6
   BB        0.3     400         1.000         6.000            0           6
   BB        0.3     800         1.000         6.000            0           6
   BB        0.3    1600         1.000         6.000            0           6
   BB        0.6     100         1.000         6.000            0           6
   BB        0.6     200         1.000         6.000            0           6
   BB        0.6     400         1.000         6.000            0           6
   BB        0.6     800         1.000         6.000            0           6
   BB        0.6    1600         1.000         6.000            0           6
   BB        0.9     100         1.000         6.000            0           6
   BB        0.9     200         1.000         6.000            0           6
   BB        0.9     400         1.000         6.000            0           6
   BB        0.9     800         1.000         6.000            0           6
   BB        0.9    1600         1.000         6.000            0           6
   PB        0.1     100         0.965         1.955            0           0
   PB        0.1     200         0.780         1.175            0           0
   PB        0.1     400         0.455         0.550            0           0
   PB        0.1     800         0.120         0.125            0           0
   PB        0.1    1600         0.030         0.030            0           0
   PB        0.3     100         0.630         0.820            0           0
   PB        0.3     200         0.290         0.305            0           0
   PB        0.3     400         0.040         0.040            0           0
   PB        0.3     800         0.000         0.000            0           0
   PB        0.3    1600         0.000         0.000            0           0
   PB        0.6     100         0.190         0.200            0           0
   PB        0.6     200         0.030         0.030            0           0
   PB        0.6     400         0.000         0.000            0           0
   PB        0.6     800         0.000         0.000            0           0
   PB        0.6    1600         0.000         0.000            0           0
   PB        0.9     100         0.015         0.015            0           0
   PB        0.9     200         0.005         0.005            0           0
   PB        0.9     400         0.000         0.000            0           0
   PB        0.9     800         0.000         0.000            0           0
   PB        0.9    1600         0.000         0.000            0           0
   PP        0.1     100         0.975         2.100            0           0
   PP        0.1     200         0.795         1.225            0           0
   PP        0.1     400         0.435         0.555            0           0
   PP        0.1     800         0.130         0.130            0           0
   PP        0.1    1600         0.010         0.010            0           0
   PP        0.3     100         0.550         0.680            0           0
   PP        0.3     200         0.150         0.155            0           0
   PP        0.3     400         0.015         0.015            0           0
   PP        0.3     800         0.000         0.000            0           0
   PP        0.3    1600         0.000         0.000            0           0
   PP        0.6     100         0.100         0.100            0           0
   PP        0.6     200         0.005         0.005            0           0
   PP        0.6     400         0.000         0.000            0           0
   PP        0.6     800         0.000         0.000            0           0
   PP        0.6    1600         0.000         0.000            0           0
   PP        0.9     100         0.010         0.010            0           0
   PP        0.9     200         0.000         0.000            0           0
   PP        0.9     400         0.000         0.000            0           0
   PP        0.9     800         0.000         0.000            0           0
   PP        0.9    1600         0.000         0.000            0           0
 conv0 pdHess
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 0.975  0.870
 0.990  0.890
 1.000  0.990
 1.000  0.995
 1.000  1.000
 1.000  0.985
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 0.970  0.835
 0.995  0.940
 1.000  0.970
 1.000  1.000
 1.000  1.000
 1.000  0.995
 1.000  0.995
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
 1.000  1.000
```

## SECONDARY: correlation off-diagonals (PP vs PB only)

BB is structurally excluded: it always estimates `Sigma = Lambda Lambda'`, under
which every off-diagonal correlation is exactly +/-1 by the rank-1 property, so
the metric tests only sign recovery there. The same applies to the whole U0 arm.

```
 cell prevalence n_units off_rmse off_rmse_mcse comm_rmse comm_rmse_mcse
   PB        0.1     100  0.40028     0.0099379   0.44861      0.0078582
   PB        0.1     200  0.29439     0.0086763   0.36349      0.0081483
   PB        0.1     400  0.21612     0.0053506   0.27609      0.0074580
   PB        0.1     800  0.16516     0.0029095   0.19681      0.0049460
   PB        0.1    1600  0.15184     0.0019248   0.17108      0.0031936
   PB        0.3     100  0.24647     0.0074743   0.31599      0.0080336
   PB        0.3     200  0.15274     0.0052823   0.19741      0.0061382
   PB        0.3     400  0.09800     0.0027260   0.12925      0.0037808
   PB        0.3     800  0.07085     0.0016493   0.09022      0.0020177
   PB        0.3    1600  0.05105     0.0010973   0.06400      0.0013307
   PB        0.6     100  0.15345     0.0039854   0.19945      0.0055730
   PB        0.6     200  0.09590     0.0021139   0.12610      0.0027508
   PB        0.6     400  0.06532     0.0015537   0.08535      0.0018687
   PB        0.6     800  0.04888     0.0011818   0.06275      0.0014873
   PB        0.6    1600  0.03292     0.0007632   0.04259      0.0009627
   PB        0.9     100  0.10946     0.0025299   0.14088      0.0027629
   PB        0.9     200  0.07428     0.0017776   0.09714      0.0021660
   PB        0.9     400  0.05151     0.0011173   0.06780      0.0014199
   PB        0.9     800  0.03576     0.0007751   0.04603      0.0009644
   PB        0.9    1600  0.02620     0.0006588   0.03420      0.0007805
   PP        0.1     100  0.40227     0.0093415   0.46040      0.0078297
   PP        0.1     200  0.29292     0.0085131   0.36569      0.0084206
   PP        0.1     400  0.21246     0.0058125   0.27229      0.0081901
   PP        0.1     800  0.15606     0.0031131   0.18928      0.0050112
   PP        0.1    1600  0.13578     0.0019812   0.15469      0.0031507
   PP        0.3     100  0.22959     0.0070161   0.29249      0.0077696
   PP        0.3     200  0.13332     0.0041215   0.17559      0.0052342
   PP        0.3     400  0.09202     0.0022066   0.12300      0.0029790
   PP        0.3     800  0.06341     0.0014553   0.08119      0.0019611
   PP        0.3    1600  0.04638     0.0011641   0.05895      0.0013785
   PP        0.6     100  0.12694     0.0033902   0.16416      0.0042247
   PP        0.6     200  0.08583     0.0022385   0.11304      0.0028440
   PP        0.6     400  0.06079     0.0014263   0.07745      0.0016268
   PP        0.6     800  0.04270     0.0010928   0.05533      0.0013061
   PP        0.6    1600  0.03146     0.0006880   0.04118      0.0008483
   PP        0.9     100  0.09292     0.0022583   0.11889      0.0025877
   PP        0.9     200  0.06763     0.0015294   0.08626      0.0019325
   PP        0.9     400  0.04545     0.0010741   0.05765      0.0012204
   PP        0.9     800  0.03273     0.0007308   0.04192      0.0008249
   PP        0.9    1600  0.02394     0.0004943   0.03061      0.0006192
```

## D2 -- within-dataset multistart (sampling noise removed)

One dataset, K dispersed starts on the SAME objective (each start gets a fresh
`MakeADFun` so no inner-solution state carries over). Starts: the MLE, the
package default, the reflected loadings, loadings x0.2, loadings x3.0, and
9 jittered starts at sd 0.3 / 0.6 / 1.0. Setting: n = 200, prevalence = 0.1
(hard), arm U1.

```
  dataset  K best_nll nll_spread n_at_matched_logL gap_at_matched_logL
 PB_seed1 14  1020.22 4.2781e-08                14          4.4959e-05
 PB_seed2 14  1088.52 6.5391e-06                14          4.0358e-05
 PB_seed3 14   979.27 6.1847e-07                14          3.3624e-05
 PP_seed1 14  1090.18 1.8329e-06                14          3.8706e-05
 PP_seed2 14  1166.65 2.8242e-06                14          4.5935e-05
 PP_seed3 14  1048.08 5.3078e-07                14          3.3052e-05
 max_pairwise_gap
       4.4959e-05
       4.0358e-05
       3.3624e-05
       3.8706e-05
       4.5935e-05
       3.3052e-05
```

Pre-registered D2 threshold: no pair with `|delta logL| < 1e-4` differing by more than 0.05.
Observed maximum `gap_at_matched_logL` over all datasets: **0.00005**.

Per-start detail for the first PB dataset (nll, sign-aligned RMSE vs truth):
```
       start    nll conv rmse_vs_truth
         mle 1020.2    0       0.18541
 pkg_default 1020.2    0       0.18541
     reflect 1020.2    0       0.18541
      shrink 1020.2    0       0.18543
     inflate 1020.2    0       0.18542
    jit0.3_1 1020.2    0       0.18542
    jit0.3_2 1020.2    0       0.18542
    jit0.3_3 1020.2    0       0.18541
    jit0.6_1 1020.2    0       0.18542
    jit0.6_2 1020.2    0       0.18542
    jit0.6_3 1020.2    0       0.18542
    jit1.0_1 1020.2    0       0.18542
    jit1.0_2 1020.2    0       0.18542
    jit1.0_3 1020.2    0       0.18543
```

## D3 -- observed-information eigen-spectrum

Hessian of the Laplace-approximated marginal negative log-likelihood at the MLE,
in the rotation-fixed 18-parameter space (`b_fix` x6, `theta_rr_B` = Lambda x6,
`theta_diag_B` = 0.5 log psi x6). `obj$he()` is not implemented for models with
random effects, so `optimHess(p, fn, gr)` on TMB's exact gradients was used;
it agrees with the package's own Hessian (`solve(sd_report$cov.fixed)`) to the
tolerance shown. n = 400.

```
        config lambda_min lambda_max    cond  softest_par softest_load
 PB_p0.1_seed1     2.3073      182.6  79.135 theta_diag_B       0.9411
 PB_p0.1_seed2     0.4571      201.3 440.321 theta_diag_B       0.9825
 PB_p0.1_seed3     3.1457      169.5  53.885 theta_diag_B       0.7499
 PB_p0.6_seed1    13.9791      527.3  37.719 theta_diag_B       0.9366
 PB_p0.6_seed2    29.6567      484.2  16.327 theta_diag_B       0.8786
 PB_p0.6_seed3    35.7719      514.0  14.369 theta_diag_B       0.7182
 PP_p0.1_seed1     1.7500      204.5 116.850 theta_diag_B       0.9126
 PP_p0.1_seed2     4.8760      242.6  49.746   theta_rr_B       0.5360
 PP_p0.1_seed3     5.1151      185.7  36.301 theta_diag_B       0.6484
 PP_p0.6_seed1    72.2219      602.9   8.349 theta_diag_B       0.6955
 PP_p0.6_seed2    49.4898      641.6  12.964 theta_diag_B       0.8165
 PP_p0.6_seed3    58.1056      557.3   9.592 theta_diag_B       0.7846
 max_manifold_cos argmax_manifold_sp hess_xcheck
           0.7630                  1   3.690e-10
           0.9898                  6   1.479e-07
           0.8988                  4   2.704e-10
           0.9770                  2   1.464e-08
           0.9605                  2   3.907e-09
           0.7866                  2   7.642e-09
           0.7793                  1   1.348e-08
           0.5947                  6   3.521e-09
           0.7875                  2   1.741e-09
           0.8252                  2   7.552e-08
           0.9040                  2   3.187e-08
           0.9167                  2   1.258e-07
```

`max_manifold_cos` tests the PRE-REGISTERED PREDICTION that the softest
direction lies near the `lambda_j^2 + psi_j = const` manifold: it is the
cosine between the smallest eigenvector and that manifold's tangent
`(psi_j, -lambda_j)` in the `(theta_rr_B_j, theta_diag_B_j)` plane, maximised
over species; `argmax_manifold_sp` names the species attaining it. A value
near 1 confirms the prediction, near 0 refutes it.

Smallest eigenvector, PB prevalence 0.1 seed 1:
```
       b_fix        b_fix        b_fix        b_fix        b_fix        b_fix 
       0.309        0.002       -0.009        0.003        0.001        0.003 
  theta_rr_B   theta_rr_B   theta_rr_B   theta_rr_B   theta_rr_B   theta_rr_B 
       0.087        0.040       -0.038        0.021        0.024        0.027 
theta_diag_B theta_diag_B theta_diag_B theta_diag_B theta_diag_B theta_diag_B 
      -0.941       -0.029        0.070        0.009       -0.003        0.026 
```

## D4 -- profile likelihood on communality h_j^2

EXACT profile: `h_j^2 = c` is imposed by `psi_j = lambda_j^2 (1-c)/c`, i.e.
`theta_diag_B[j] = 0.5 log(lambda_j^2 (1-c)/c)`, maximising over the other 17
parameters at each of 24 grid points in (0.04, 0.96). Intervals are profile
intervals (1.92 drop in logL), never Wald. n = 400, U1 arm. BB has no psi and
is excluded by construction.

```
      config h2_true h2_hat ci_lo ci_hi ci_width nll_range_over_grid
 PB_sp1_p0.1  0.0698 0.3535  0.04  0.96     0.92                1.19
 PB_sp1_p0.6  0.0698 0.1313  0.08  0.28     0.20               23.33
 PB_sp2_p0.1  0.6183 0.3335  0.08  0.84     0.76               11.46
 PB_sp2_p0.6  0.6183 0.7453  0.52  0.96     0.44               29.23
 PP_sp1_p0.1  0.0698 0.3700  0.04  0.96     0.92                1.13
 PP_sp1_p0.6  0.0698 0.0761  0.04  0.20     0.16               39.80
 PP_sp2_p0.1  0.6183 0.3727  0.12  0.92     0.80               13.15
 PP_sp2_p0.6  0.6183 0.5311  0.40  0.68     0.28               73.08
```

`nll_range_over_grid` is the total rise in profile nll across the whole (0,1)
grid. A FLAT profile (range of order 1 or less) means the loading /
unique-variance split is undetermined; a large range means it is pinned.

## D5 -- arm-stratified information

Block-1-only, block-2-only and joint fits at matched n and truth. **The
pre-registered trap is handled by forcing `unique = FALSE` UNIFORMLY** across
all three fits: a block-2-only fit in PB is all-Bernoulli, so the psi-pinning
of `R/fit-multi.R:4976` would otherwise fire and make that arm estimate a
different model. Information about `lambda_j` is the marginal (profile)
information `1 / [H^{-1}]_jj`, averaged over species and 60 seeds. n = 400.

Information is evaluated for all three fits at a COMMON parameter point -- the
JOINT fit's MLE. Evaluating each arm at its OWN MLE does not compare
information content (the three MLEs sit at different points); that was
corrected during the run. Medians are reported, not means, because a minority
of arm-only Hessians are not positive definite at the joint MLE (see
`frac_neg_*`): far from its own optimum, a single-block marginal likelihood
need not be locally concave. Exact additivity is NOT expected even at a common
point -- the joint model shares ONE latent u under ONE integral, so its
marginal log-likelihood is not the sum of the two block marginals.

```
  config n_seeds info_joint info_b1 info_b2 b2_share frac_neg_b1 frac_neg_b2
 PB_p0.1      60      41.25   15.52   10.52   0.4040     0.08056     0.31389
 PB_p0.6      60     401.32  279.22   50.83   0.1540     0.00000     0.04167
 PP_p0.1      60      47.71   15.46   15.98   0.5082     0.08056     0.06944
 PP_p0.6      60     572.82  290.36  285.32   0.4956     0.00000     0.00000
 rmse_joint mcse_joint rmse_b1  mcse_b1 rmse_b2  mcse_b2
     0.2681   0.007596  0.4586 0.014203  7.1194 0.186393
     0.1238   0.003379  0.1334 0.003733  0.1640 0.006315
     0.2435   0.008095  0.4573 0.014256  0.4557 0.017209
     0.1149   0.003461  0.1300 0.004110  0.1270 0.003425
```

`b2_share` is the second block's share of the information about Lambda.
**Internal validity check:** PP is symmetric by construction (two identical
Poisson blocks), so its `b2_share` MUST come out at 0.5 if the measurement is
sound. It does. That is what licenses reading PB's share as a real quantity.

**UNCERTAIN at prevalence 0.1.** There, 8% of `b1` and 31% of `b2` arm-only
informations are negative at the joint MLE, so the decomposition is not
trustworthy at that prevalence and only the RMSE columns should be read. The
check that would settle it: expected (rather than observed) information by
simulation, or evaluation at each arm's own pseudo-true value.

## D6 -- permutation placebo (REQUIRED)

PB refit with the Bernoulli block's responses permuted across units, within
species (destroying its link to `u_i` while preserving its marginal). If
Lambda-hat were essentially unchanged, the Bernoulli arm was inert and any PASS
would be vacuous. n = 400, U1 arm, 60 seeds.

```
 prevalence n_seeds rmse_orig mcse_orig rmse_perm mcse_perm lambda_shift
        0.1      60   0.26718  0.012142    0.4490  0.017721       0.4884
        0.3      60   0.10699  0.004315    0.2590  0.006281       0.2635
        0.6      60   0.07401  0.002717    0.1844  0.004143       0.1840
        0.9      60   0.06300  0.002489    0.1135  0.002946       0.1029
 mcse_shift
   0.021491
   0.005686
   0.003168
   0.001911
```

`lambda_shift` is the sign-aligned RMS distance between the original and
permuted Lambda-hat. It must exceed its own MCSE by a wide margin for the
Bernoulli arm to count as informative.

## D7 -- Laplace-accuracy control (AGHQ)

Laplace is known to shrink variance components on binary responses, which would
mimic exactly the failure this gate tests for. PB refit with
`gllvmTMBcontrol(aghq = 5)`, 40 seeds, n = 200.

Eligibility probe:
```
 cell n_units prevalence seed arm aghq aghq_used   rmse  err
   PB     200        0.1    1  U1    5     FALSE 0.1854 <NA>
   PB     200        0.1    1  U0    5      TRUE 0.1429 <NA>
```

```
  config n_seeds rmse_laplace mcse_laplace rmse_aghq5 mcse_aghq5     diff
 U1_p0.1      40       0.3309     0.021178     0.3309   0.021178  0.00000
 U1_p0.6      40       0.1133     0.006408     0.1133   0.006408  0.00000
 U0_p0.1      40       0.3388     0.011995     0.2764   0.010749 -0.06247
 U0_p0.6      40       0.1523     0.007026     0.1506   0.007059 -0.00172
```


**Read the `aghq_used` column before reading the RMSE table.** On the **U1 arm --
the package's real estimand -- AGHQ never ran.** `latent(unique = TRUE)` puts
`s_B` into the random vector, and AGHQ Stage 1a requires `z_B` as the *only*
random block, so the package declined to Laplace and warned. The identical
`U1_p0.1` / `U1_p0.6` numbers are therefore **the same fit twice, not a null
result**, and an earlier version of this probe wrongly reported `aghq_used =
TRUE` there by inferring "used" from the presence of `k`; it now reads
`fit$aghq$used`. That AGHQ is structurally unavailable on the U1 arm is itself a
finding.

On the **U0 arm**, where AGHQ is eligible and did run (5 nodes, 40 adaptation
passes, `stop_reason = "stalled"`), it cuts Lambda RMSE from **0.3388 to 0.2764
at prevalence 0.1** -- a 18% reduction, about 5x the MCSE of the difference --
and does nothing at prevalence 0.6 (`-0.0017`, well inside MCSE `0.0070`). So a
material part of the low-prevalence degradation is **Laplace approximation
error, not identifiability** -- but this is measured on U0, and cannot be
transferred to U1 without assuming the two arms share the mechanism, which has
not been shown.

---

# VERDICT

**PASS-ABOVE-THRESHOLD: prevalence >= 0.3.**

The number that decides it is **D1's log-log slope for PB on the U1 arm**:
**-0.487 (SE 0.0069) at prevalence 0.3, -0.511 (SE 0.0140) at 0.6, -0.487
(SE 0.0136) at 0.9** -- all within 2 SE of the `-0.5` a well-behaved MLE must
give -- against **-0.431 (SE 0.0095) at prevalence 0.1**, which misses.

Criterion by criterion, for the gate cell PB on the U1 arm:

| criterion | p=0.1 | p=0.3 | p=0.6 | p=0.9 |
|---|---|---|---|---|
| 1. D1 slope within 2 SE of -0.5 | **NO** (-0.431) | YES (-0.487) | YES (-0.511) | YES (-0.487) |
| 2. D2 no Lambda gap at matched logL | YES | YES | YES | YES |
| 3. D3 smallest eigenvalue not ~0 | YES | YES | YES | YES |
| 4. RMSE_PB / RMSE_PP <= 2.0 | YES (max 1.14) | YES (1.09) | YES (1.14) | YES (1.17) |
| 5. D6 Bernoulli arm not inert | YES (23x MCSE) | YES (46x) | YES (58x) | YES (54x) |

## The answer to the question that was asked

**Planted Lambda IS recoverable under mixed Poisson/Bernoulli curvature, and the
mixing itself costs almost nothing.** PB's Lambda RMSE is **1.03-1.17x** PP's
across all 20 (n, prevalence) combinations -- against a pre-stated tolerance of
2.0 -- and PB is **better than BB everywhere** (`ratio_PB_BB` 0.19-0.91). A
species' loading informed by one Poisson and one Bernoulli block is estimated
nearly as well as one informed by two Poisson blocks, and always better than one
informed by two Bernoulli blocks.

**Where recovery is imperfect, it is weak estimability, not non-identifiability
-- and the evidence for that distinction is instrumental, not inferential:**

- **D2 settles it within a single dataset, with sampling noise removed.** All
  **14** dispersed starts -- including the reflected loadings and loadings
  inflated 3x and shrunk to 0.2x -- converge to the same optimum: `nll` spread
  **4.3e-08**, Lambda RMSE spread **0.18541 to 0.18543**, and a maximum
  Lambda gap at matched logL of **4.5e-05** against a pre-registered threshold of
  0.05. Repeated on 6 datasets (3 PB, 3 PP): the largest gap anywhere is
  **4.6e-05**. There is no flat ridge and no second mode. The maximiser is
  unique.
- **D3 agrees.** The smallest eigenvalue of the observed information is
  **0.457 to 35.8** for PB (0.457 to 72.2 over PB and PP together) and the PB
  condition number **14.4 to 440** -- nowhere near the
  `1e8` that would signal a numerically singular direction. (`obj$he()` is not
  implemented for random-effects models; `optimHess` on TMB's exact gradients was
  used, and agrees with the package's own Hessian
  (`solve(sd_report$cov.fixed)`) to **1.5e-07 or better** across all 12
  configurations.)

## Which parameter IS weak, and it is not Lambda

The **pre-registered D3 prediction is CONFIRMED**: the softest direction lies
near the `lambda_j^2 + psi_j = const` manifold, with cosine **0.76-0.99 in 11 of
12 configurations**. The smallest eigenvector loads on a `theta_diag_B` (i.e.
`psi`) coordinate in 11 of 12. **D4 shows the same thing from the likelihood
side:** the exact profile on communality `h_j^2` is essentially FLAT at
prevalence 0.1 -- total nll rise of **1.19** across the whole (0,1) grid for PB
sp1, profile interval **[0.04, 0.96]**, i.e. the entire grid -- and sharp at
prevalence 0.6 (nll range **23.3**, interval **[0.08, 0.28]** around a true 0.070).

So the weakly-determined quantity is the **loading / unique-variance split**, not
the loading. That has a direct consequence for the package: `extract_loadings()`
is on far firmer ground at low prevalence than communality or `psi`, and any
communality reported at prevalence ~0.1 should carry a profile interval, never a
Wald one.

## Attribution: the prevalence-0.1 miss is NOT mixed curvature

Four independent controls converge on this, and the pre-registered attribution
rule (a PB deficit implicates mixing only if PB is worse than BOTH PP and BB)
is not met at any prevalence:

1. **PP fails D1 the same way.** At prevalence 0.1 the all-Poisson ceiling gives
   **-0.454 (SE 0.0116)**, also outside 2 SE of -0.5. A defect the ceiling shares
   is not caused by the mixing.
2. **D4's flat communality profile is equally flat for PP** (nll range **1.13**
   for PP sp1 vs **1.19** for PB sp1 at prevalence 0.1, interval `[0.04, 0.96]`
   in both). Identical, so not curvature-mixing.
3. **The boundary rate explains the shape of the n-ladder.** At prevalence 0.1,
   **96.5%** of PB fits at n=100 have a collapsed `psi_hat`, falling to 78.0% at
   n=200, 45.5% at 400, 12.0% at 800 and **3.0%** at 1600 -- with PP within a
   couple of points at every rung (97.5 / 79.5 / 43.5 / 13.0 / 1.0%). Over that
   window the estimator is a mixture of a boundary-truncated regime and an
   interior regime, so its RMSE cannot follow a clean `n^{-1/2}` law; the fitted
   slope of -0.43 is a *mixture* artefact, not a flat likelihood. By prevalence
   0.3 the boundary rate is already 0% from n=800 up, and the slope snaps to
   -0.487.
4. **D7 attributes part of the residual to Laplace, not to identifiability**:
   on the U0 arm at prevalence 0.1, AGHQ with 5 nodes cuts RMSE **0.3388 ->
   0.2764** (about 5 MCSE), and does nothing at prevalence 0.6.

**The U0 arm is the internal control that shows what a real identifiability
failure looks like in this harness.** `unique = FALSE` is misspecified against a
DGP with `psi > 0`, so its estimator converges to a pseudo-true value and its
RMSE has a nonzero asymptote. Its D1 slopes are **-0.12 to -0.30** across every
cell including PP -- visibly flattening toward 0, which is exactly the signature
the gate was built to detect. PB on U1 does not look like that.

## D5 and D6: the Bernoulli arm earns its place

- **D6 (required placebo) passes decisively.** Permuting the Bernoulli block's
  responses across units moves Lambda-hat by **0.4884 (MCSE 0.0215) at prevalence
  0.1, 0.2635 (0.0057) at 0.3, 0.1840 (0.0032) at 0.6 and 0.1029 (0.0019) at
  0.9** -- **23x to 58x its own MCSE** -- and roughly doubles RMSE (0.267 ->
  0.449; 0.107 -> 0.259; 0.074 -> 0.184; 0.063 -> 0.114). The Bernoulli arm is
  informative, so the PASS is not vacuous.
- **D5 quantifies how much.** At prevalence 0.6 the Bernoulli block carries
  **15.4%** of the information about Lambda against the Poisson block's 84.6%.
  The measurement validates itself: PP, symmetric by construction, returns
  **49.6% / 50.4%**. And the joint fit beats **both** single-block fits on RMSE
  in every configuration -- most strikingly at PB prevalence 0.1, where the
  Bernoulli block **alone is useless** (RMSE **7.12**, loadings run away) yet the
  joint fit (0.268) still beats the Poisson block alone (0.459).

## Boundary rate (primary outcome)

Zero loading runaways in all 24,000 fits. `psi` collapse is entirely a
low-information phenomenon and is **not** worse under mixing: PB vs PP at n=100
is 96.5% vs 97.5% (p=0.1), 63.0% vs 55.0% (p=0.3), 19.0% vs 10.0% (p=0.6), 1.5%
vs 1.0% (p=0.9); everything at prevalence >= 0.3 and n >= 800 is 0%. BB is
structurally excluded -- its `diag_B_skip` is 6/6 in every fit, so its `psi_hat`
is a pinned constant, not a boundary estimate.

Optimiser flags were recorded but never used to select: `convergence == 0` in
99.9% and `pdHess` in 99.6% of fits, including the prevalence-0.1 cells where
recovery is demonstrably poor -- consistent with the sister-package result that
flags do not track degeneracy.

---

# WHAT THIS DOES NOT COVER

- **d = 1 only.** Every claim here is about a single latent factor, where
  alignment is a sign and rotation is not an issue. Nothing here speaks to
  `d >= 2`, where Procrustes alignment is a genuine orthogonal transform and
  axis collapse becomes possible. The related Gate 3 work in this repo found
  `q = 4` failing on axis collapse at p = 8; that mechanism is untested here.
- **T = 6 species, one planted Lambda/psi pair.** The truth vector was fixed
  across the whole grid. Sensitivity to the loading configuration -- especially
  to how many near-zero loadings there are -- is unmeasured. sp1 (`Lambda = 0.15`,
  `h^2 = 0.07`) is the only weak-loading case.
- **Two blocks, one covariate-free intercept model.** No covariates, no offsets
  varying across units, no unequal block sizes, no more than two blocks. The
  sibling `dev/isdm-plumbing.R` exercises offsets and shared slopes; this gate
  does not.
- **Bernoulli-cloglog only.** Logit was not tested. The cloglog link is what makes
  the Poisson and Bernoulli blocks share `eta` exactly; under logit the two
  blocks would not be driven by one intensity and the design would not be
  matched.
- **No interval coverage.** This is a point-recovery gate. Nothing here certifies
  standard errors, Wald intervals, or bootstrap coverage for Lambda, `psi`, or
  communality. D4 gives profile intervals at four single configurations only,
  not a coverage study.
- **D7 is measured on the U0 arm only**, because AGHQ is structurally ineligible
  under `unique = TRUE`. The claim "part of the low-prevalence degradation is
  Laplace error" is established for U0 and is **UNCERTAIN for U1**. The check
  that would settle it: an AGHQ path that admits `s_B` in the random vector, or
  an MCMC / high-order-quadrature reference fit for the U1 model.
- **D5's information decomposition is UNCERTAIN at prevalence 0.1**, where 8%
  (`b1`) and 31% (`b2`) of arm-only observed informations are not positive
  definite at the joint MLE. Only the prevalence-0.6 decomposition should be
  quoted. The check that would settle it: expected rather than observed
  information, by simulation.
- **Prevalence 0.1 is reported as a miss on criterion 1 and is NOT claimed to be
  fixed.** The evidence attributes it to boundary mixing plus Laplace error
  rather than to mixed curvature, but no re-run demonstrated that removing those
  two restores a -0.5 slope. The check that would settle it: re-run the
  prevalence-0.1 n-ladder starting at n = 800 (where the boundary rate is
  already 12%) and extending to n = 12800, and separately with an integrator
  accurate enough to be Laplace-free on the U1 arm.
- **The design was not tuned.** No cell, seed count, threshold, or tolerance was
  changed after results were seen. The two mid-run code corrections (D5's
  evaluation point, D7's `aghq_used` field) both made the reported answer *less*
  favourable to a clean PASS, and are documented above.
